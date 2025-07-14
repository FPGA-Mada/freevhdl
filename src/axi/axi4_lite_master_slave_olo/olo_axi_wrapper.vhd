library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.math_utils.all;

entity olo_axi_wrapper is
    generic (
        AxiAddrWidth_g            : positive := 32;
        AxiDataWidth_g            : positive := 32;
        ReadTimeoutClks_g         : positive := 100;
        AxiMaxBeats_g             : positive := 16;
        AxiMaxOpenTransactions_g  : positive := 4;
        UserTransactionSizeBits_g : positive := 24;
        DataFifoDepth_g           : positive := 1024;
        ImplRead_g                : boolean  := true;
        ImplWrite_g               : boolean  := true;
        RamBehavior_g             : string   := "RBW"
    );
    port (
        Clk : in std_logic;
        Rst : in std_logic;

        -- AXI4-Lite Slave Interface (external)
        S_AxiLite_AWAddr  : in  std_logic_vector(AxiAddrWidth_g-1 downto 0);
        S_AxiLite_AWValid : in  std_logic;
        S_AxiLite_AWReady : out std_logic;
        S_AxiLite_WData   : in  std_logic_vector(AxiDataWidth_g-1 downto 0);
        S_AxiLite_WStrb   : in  std_logic_vector((AxiDataWidth_g/8)-1 downto 0);
        S_AxiLite_WValid  : in  std_logic;
        S_AxiLite_WReady  : out std_logic;
        S_AxiLite_BResp   : out std_logic_vector(1 downto 0);
        S_AxiLite_BValid  : out std_logic;
        S_AxiLite_BReady  : in  std_logic;
        S_AxiLite_ARAddr  : in  std_logic_vector(AxiAddrWidth_g-1 downto 0);
        S_AxiLite_ARValid : in  std_logic;
        S_AxiLite_ARReady : out std_logic;
        S_AxiLite_RData   : out std_logic_vector(AxiDataWidth_g-1 downto 0);
        S_AxiLite_RResp   : out std_logic_vector(1 downto 0);
        S_AxiLite_RValid  : out std_logic;
        S_AxiLite_RReady  : in  std_logic;

        -- AXI4 Master Interface (external)
        M_Axi_AWAddr  : out std_logic_vector(AxiAddrWidth_g-1 downto 0);
        M_Axi_AWLen   : out std_logic_vector(7 downto 0);
        M_Axi_AWSize  : out std_logic_vector(2 downto 0);
        M_Axi_AWBurst : out std_logic_vector(1 downto 0);
        M_Axi_AWLock  : out std_logic;
        M_Axi_AWCache : out std_logic_vector(3 downto 0);
        M_Axi_AWProt  : out std_logic_vector(2 downto 0);
        M_Axi_AWValid : out std_logic;
        M_Axi_AWReady : in  std_logic;

        M_Axi_WData   : out std_logic_vector(AxiDataWidth_g-1 downto 0);
        M_Axi_WStrb   : out std_logic_vector((AxiDataWidth_g/8)-1 downto 0);
        M_Axi_WLast   : out std_logic;
        M_Axi_WValid  : out std_logic;
        M_Axi_WReady  : in  std_logic;

        M_Axi_BResp   : in  std_logic_vector(1 downto 0);
        M_Axi_BValid  : in  std_logic;
        M_Axi_BReady  : out std_logic;

        M_Axi_ARAddr  : out std_logic_vector(AxiAddrWidth_g-1 downto 0);
        M_Axi_ARLen   : out std_logic_vector(7 downto 0);
        M_Axi_ARSize  : out std_logic_vector(2 downto 0);
        M_Axi_ARBurst : out std_logic_vector(1 downto 0);
        M_Axi_ARLock  : out std_logic;
        M_Axi_ARCache : out std_logic_vector(3 downto 0);
        M_Axi_ARProt  : out std_logic_vector(2 downto 0);
        M_Axi_ARValid : out std_logic;
        M_Axi_ARReady : in  std_logic;

        M_Axi_RData   : in  std_logic_vector(AxiDataWidth_g-1 downto 0);
        M_Axi_RResp   : in  std_logic_vector(1 downto 0);
        M_Axi_RLast   : in  std_logic;
        M_Axi_RValid  : in  std_logic;
        M_Axi_RReady  : out std_logic
    );
end entity;

architecture rtl of olo_axi_wrapper is
    constant width_mem : natural := 200;
    -- Register bus between slave and master
    signal Rb_Addr     : std_logic_vector(AxiAddrWidth_g-1 downto 0);
    signal Rb_Wr       : std_logic;
    signal Rb_ByteEna  : std_logic_vector((AxiDataWidth_g/8)-1 downto 0);
    signal Rb_WrData   : std_logic_vector(AxiDataWidth_g-1 downto 0);
    signal Rb_Rd       : std_logic;
    signal Rb_RdData   : std_logic_vector(AxiDataWidth_g-1 downto 0);
    signal Rb_RdValid  : std_logic;

    -- Command interface to AXI Master
    signal CmdWr_Addr   : std_logic_vector(AxiAddrWidth_g-1 downto 0);
    signal CmdWr_Size   : std_logic_vector(UserTransactionSizeBits_g-1 downto 0);
    signal CmdWr_LowLat : std_logic;
    signal CmdWr_Valid  : std_logic;
    signal CmdWr_Ready  : std_logic;

    signal CmdRd_Addr   : std_logic_vector(AxiAddrWidth_g-1 downto 0);
    signal CmdRd_Size   : std_logic_vector(UserTransactionSizeBits_g-1 downto 0);
    signal CmdRd_LowLat : std_logic;
    signal CmdRd_Valid  : std_logic;
    signal CmdRd_Ready  : std_logic;

    signal Wr_Data      : std_logic_vector(AxiDataWidth_g-1 downto 0);
    signal Wr_Be        : std_logic_vector((AxiDataWidth_g/8)-1 downto 0);
    signal Wr_Valid     : std_logic;
    signal Wr_Ready     : std_logic;

    signal Rd_Data      : std_logic_vector(AxiDataWidth_g-1 downto 0);
    signal Rd_Last      : std_logic;
    signal Rd_Valid     : std_logic;
    signal Rd_Ready     : std_logic := '1';

    signal Wr_Done, Wr_Error : std_logic;
    signal Rd_Done, Rd_Error : std_logic;
    
    
    signal Rd_Addr_PL: std_logic_vector (AxiAddrWidth_g -1 downto 0):= (others => '0');
    signal Rd_Data_PL : std_logic_vector (AxiDataWidth_g -1 downto 0) := (others => '0');
    signal Rd_En_PL : std_logic := '0';
    signal Rd_Valid_PL : std_logic := '0';    
    signal Wr_Counter : integer range 0 to 40 := 0;
    signal read_counter : integer range 0 to 40 := 0;


    signal cmd_sent         : boolean := false; 
    signal data_index       : integer range 0 to 9 := 0;
    signal write_done       : boolean := false;
    signal Wr_Addr          : std_logic_vector (CmdWr_Addr'range);
   type t_wr_state is (WR_IDLE, WR_PREPARE, WR_WAIT_FIFO, WR_WAIT_READY, WR_SEND_CMD, WR_WAIT_DONE);
   signal wr_state : t_wr_state := WR_IDLE;


begin

  
   -----------------------------
   -- AXI MASTER write MASTER
   -----------------------------
 process (Clk)
begin
  if rising_edge(Clk) then
    if Rst = '1' then
      Wr_Counter   <= 0;
      Wr_Valid     <= '0';
      CmdWr_Valid  <= '0';
      Wr_Data      <= (others => '0');
      Wr_Be        <= (others => '1');
      CmdWr_LowLat <= '0';
      wr_state     <= WR_IDLE;
    else
      case wr_state is
        when WR_IDLE =>
          if Wr_Counter < 10 then
            Wr_Addr  <= std_logic_vector(to_unsigned(Wr_Counter * 4, Wr_Addr'length));
            Wr_Data  <= std_logic_vector(to_unsigned(Wr_Counter * 4, Wr_Data'length));
            wr_state <= WR_WAIT_FIFO;
          end if;

        when WR_WAIT_FIFO =>
          if Wr_Ready = '1' then
            Wr_Valid <= '1';
            wr_state <= WR_WAIT_READY;
          end if;

        when WR_WAIT_READY =>
          if Wr_Valid = '1' and Wr_Ready = '1' then
            Wr_Valid <= '0';  -- Deassert after handshake
            wr_state <= WR_SEND_CMD;
          end if;

        when WR_SEND_CMD =>
          if CmdWr_Ready = '1' then
            CmdWr_Addr   <= Wr_Addr;
            CmdWr_Size   <= std_logic_vector(to_unsigned(1, CmdWr_Size'length));
            CmdWr_LowLat <= '0';
            CmdWr_Valid  <= '1';
            wr_state     <= WR_WAIT_DONE;
          end if;

        when WR_WAIT_DONE =>
          CmdWr_Valid <= '0';
          if Wr_Done = '1' or Wr_Error = '1' then
            Wr_Counter <= Wr_Counter + 1;
            wr_state   <= WR_IDLE;
          end if;

        when others =>
          wr_state <= WR_IDLE;
      end case;
    end if;
  end if;
end process;



	
-----------------------------
-- AXI MASTER READ MASTER
-----------------------------
read_proc: process(clk)
begin
    if rising_edge(clk) then
        if rst = '1' then
            CmdRd_Addr   <= (others => '0');
            CmdRd_Size   <= std_logic_vector(to_unsigned(1, CmdRd_Size'length));
            CmdRd_LowLat <= '1';
            CmdRd_Valid  <= '0';
            Rd_Ready     <= '1';
            read_counter <= 0;
        else
            CmdRd_Valid <= '0'; -- default deassert
            Rd_Ready    <= '1'; -- always ready to consume data

            if CmdRd_Ready = '1' and read_counter < 40 then
                CmdRd_Addr   <= std_logic_vector(to_unsigned(read_counter, CmdRd_Addr'length));
                CmdRd_Size   <= std_logic_vector(to_unsigned(1, CmdRd_Size'length));  -- 1 beat
                CmdRd_LowLat <= '1';  -- fast mode
                CmdRd_Valid  <= '1';

                read_counter <= read_counter + 4;
            end if;
        end if;
    end if;
end process;



    -----------------------------
    -- RAM Interface
    -----------------------------
  ram_int : entity work.ram_sdp 
  generic map (
    Depth_g =>width_mem , 
    Width_g => AxiDataWidth_g,
    add_Width_g => AxiAddrWidth_g
  )
  port map(
    Clk      => clk,
    rst      => rst,
    --*** interface connected to AXI user interface
    Wr_Addr  => Rb_Addr,
    Byte_En  => Rb_ByteEna,
    Wr_Data  => Rb_WrData,
    Wr_Ena   => Rb_Wr,
    Rd_Ena   => Rb_Rd,
    Rd_Addr  => Rb_Addr,
    Rd_Data  => Rb_RdData,
    Rb_valid => Rb_RdValid,
    
    -- interface going to the PL
    Rd_Data_PL  => open,
    Rd_Addr_PL => open,
    Rd_En_PL   => open,
    Rd_Valid_PL => open
    
  );

    -----------------------------
    -- AXI-Lite Slave Instance
    -----------------------------
    axi_lite_slave_inst : entity work.olo_axi_lite_slave
        generic map (
            AxiAddrWidth_g    => AxiAddrWidth_g,
            AxiDataWidth_g    => AxiDataWidth_g,
            ReadTimeoutClks_g => ReadTimeoutClks_g
        )
        port map (
            Clk               => Clk,
            Rst               => Rst,
            S_AxiLite_ArAddr  => S_AxiLite_ARAddr,
            S_AxiLite_ArValid => S_AxiLite_ARValid,
            S_AxiLite_ArReady => S_AxiLite_ARReady,
            S_AxiLite_AwAddr  => S_AxiLite_AWAddr,
            S_AxiLite_AwValid => S_AxiLite_AWValid,
            S_AxiLite_AwReady => S_AxiLite_AWReady,
            S_AxiLite_WData   => S_AxiLite_WData,
            S_AxiLite_WStrb   => S_AxiLite_WStrb,
            S_AxiLite_WValid  => S_AxiLite_WValid,
            S_AxiLite_WReady  => S_AxiLite_WReady,
            S_AxiLite_BResp   => S_AxiLite_BResp,
            S_AxiLite_BValid  => S_AxiLite_BValid,
            S_AxiLite_BReady  => S_AxiLite_BReady,
            S_AxiLite_RData   => S_AxiLite_RData,
            S_AxiLite_RResp   => S_AxiLite_RResp,
            S_AxiLite_RValid  => S_AxiLite_RValid,
            S_AxiLite_RReady  => S_AxiLite_RReady,
            Rb_Addr           => Rb_Addr,
            Rb_Wr             => Rb_Wr,
            Rb_ByteEna        => Rb_ByteEna,
            Rb_WrData         => Rb_WrData,
            Rb_Rd             => Rb_Rd,
            Rb_RdData         => Rb_RdData,
            Rb_RdValid        => Rb_RdValid
        );

    -----------------------------
    -- AXI Master Instance
    -----------------------------
    axi_master_inst : entity work.olo_axi_master_simple
        generic map (
            AxiAddrWidth_g            => AxiAddrWidth_g,
            AxiDataWidth_g            => AxiDataWidth_g,
            AxiMaxBeats_g             => AxiMaxBeats_g,
            AxiMaxOpenTransactions_g  => AxiMaxOpenTransactions_g,
            UserTransactionSizeBits_g => UserTransactionSizeBits_g,
            DataFifoDepth_g           => DataFifoDepth_g,
            ImplRead_g                => ImplRead_g,
            ImplWrite_g               => ImplWrite_g,
            RamBehavior_g             => RamBehavior_g
        )
        port map (
            Clk             => Clk,
            Rst             => Rst,
            CmdWr_Addr      => CmdWr_Addr,
            CmdWr_Size      => CmdWr_Size,
            CmdWr_LowLat    => CmdWr_LowLat,
            CmdWr_Valid     => CmdWr_Valid,
            CmdWr_Ready     => CmdWr_Ready,
            CmdRd_Addr      => CmdRd_Addr,
            CmdRd_Size      => CmdRd_Size,
            CmdRd_LowLat    => CmdRd_LowLat,
            CmdRd_Valid     => CmdRd_Valid,
            CmdRd_Ready     => CmdRd_Ready,
            Wr_Data         => Wr_Data,
            Wr_Be           => Wr_Be,
            Wr_Valid        => Wr_Valid,
            Wr_Ready        => Wr_Ready,
            Rd_Data         => Rd_Data,
            Rd_Last         => Rd_Last,
            Rd_Valid        => Rd_Valid,
            Rd_Ready        => Rd_Ready,
            Wr_Done         => Wr_Done,
            Wr_Error        => Wr_Error,
            Rd_Done         => Rd_Done,
            Rd_Error        => Rd_Error,
            M_Axi_AwAddr    => M_Axi_AWAddr,
            M_Axi_AwLen     => M_Axi_AWLen,
            M_Axi_AwSize    => M_Axi_AWSize,
            M_Axi_AwBurst   => M_Axi_AWBurst,
            M_Axi_AwLock    => M_Axi_AWLock,
            M_Axi_AwCache   => M_Axi_AWCache,
            M_Axi_AwProt    => M_Axi_AWProt,
            M_Axi_AwValid   => M_Axi_AWValid,
            M_Axi_AwReady   => M_Axi_AWReady,
            M_Axi_WData     => M_Axi_WData,
            M_Axi_WStrb     => M_Axi_WStrb,
            M_Axi_WLast     => M_Axi_WLast,
            M_Axi_WValid    => M_Axi_WValid,
            M_Axi_WReady    => M_Axi_WReady,
            M_Axi_BResp     => M_Axi_BResp,
            M_Axi_BValid    => M_Axi_BValid,
            M_Axi_BReady    => M_Axi_BReady,
            M_Axi_ArAddr    => M_Axi_ARAddr,
            M_Axi_ArLen     => M_Axi_ARLen,
            M_Axi_ArSize    => M_Axi_ARSize,
            M_Axi_ArBurst   => M_Axi_ARBurst,
            M_Axi_ArLock    => M_Axi_ARLock,
            M_Axi_ArCache   => M_Axi_ARCache,
            M_Axi_ArProt    => M_Axi_ARProt,
            M_Axi_ArValid   => M_Axi_ARValid,
            M_Axi_ArReady   => M_Axi_ARReady,
            M_Axi_RData     => M_Axi_RData,
            M_Axi_RResp     => M_Axi_RResp,
            M_Axi_RLast     => M_Axi_RLast,
            M_Axi_RValid    => M_Axi_RValid,
            M_Axi_RReady    => M_Axi_RReady
        );

end architecture;
