library ieee ;
use ieee.std_logic_1164.all ;
use ieee.numeric_std.all ;
use ieee.numeric_std_unsigned.all ;

library osvvm ;
context osvvm.OsvvmContext ;

library osvvm_Axi4 ;
context osvvm_Axi4.Axi4LiteContext ;
context osvvm_AXI4.AxiStreamContext ;

entity TbAxi4 is
end entity TbAxi4 ;

architecture TestHarness of TbAxi4 is

  constant AXI_ADDR_WIDTH : integer := 24 ;
  constant AXI_DATA_WIDTH : integer := 32 ;
  constant AXi_DATA_WIDTH_STREAM : integer := 64;
  constant AXI_STRB_WIDTH : integer := AXI_DATA_WIDTH/8 ;
  

  constant tperiod_Clk : time := 10 ns ;
  constant tpd         : time := 2 ns ;

  signal Clk         : std_logic ;
  signal nReset      : std_logic ;
  

  signal ManagerRec, SubordinateRec  : AddressBusRecType(
          Address(AXI_ADDR_WIDTH-1 downto 0),
          DataToModel(AXI_DATA_WIDTH-1 downto 0),
          DataFromModel(AXI_DATA_WIDTH-1 downto 0)
        ) ;

  signal AxiBus, AxiBus_Slave : Axi4LiteRecType(
    WriteAddress( Addr (AXI_ADDR_WIDTH-1 downto 0) ),
    WriteData   ( Data (AXI_DATA_WIDTH-1 downto 0),   Strb(AXI_STRB_WIDTH-1 downto 0) ),
    ReadAddress ( Addr (AXI_ADDR_WIDTH-1 downto 0) ),
    ReadData    ( Data (AXI_DATA_WIDTH-1 downto 0) )
  ) ;


  signal ARCache_01, AWCache_01 : std_logic_vector(3 downto 0);

  signal M_Axi_AwLen    : std_logic_vector(7 downto 0) := (others => '0');
  signal M_Axi_AwSize   : std_logic_vector(2 downto 0) := (others => '0');
  signal M_Axi_AwBurst  : std_logic_vector(1 downto 0) := (others => '0');
  signal M_Axi_AwLock   : std_logic := '0';
  signal M_Axi_WLast    : std_logic := '1';
  signal M_Axi_ArLen    : std_logic_vector(7 downto 0) := (others => '0');
  signal M_Axi_ArSize   : std_logic_vector(2 downto 0) := (others => '0');
  signal M_Axi_ArBurst  : std_logic_vector(1 downto 0) := (others => '0');
  signal M_Axi_ArLock   : std_logic := '0';

  component TestCtrl is
    port (
      Clk            : in std_logic;
      nReset         : in std_logic;
      StreamRxRec    : inout StreamRecType;
      ManagerRec     : inout AddressBusRecType;
      SubordinateRec : inout AddressBusRecType
    );
  end component;

begin

  -- Clock
  Osvvm.ClockResetPkg.CreateClock (
    Clk    => Clk,
    Period => tperiod_Clk
  );

  -- Reset
  Osvvm.ClockResetPkg.CreateReset (
    Reset       => nReset,
    ResetActive => '0',
    Clk         => Clk,
    Period      => 7 * tperiod_Clk,
    tpd         => tpd
  );

  Manager_1 : Axi4LiteManager
    port map (
      Clk      => Clk,
      nReset   => nReset,
      AxiBus   => AxiBus,
      TransRec => ManagerRec
    );

  AXI4Lite_Subordinate : entity OSVVM_AXI4.Axi4LiteSubordinate
    generic map (
      tperiod_Clk => tperiod_Clk
    )
    port map (
      Clk       => Clk,
      nReset    => nReset,
      TransRec  => SubordinateRec,
      AxiBus    => AxiBus_Slave
    );


  TestCtrl_1 : TestCtrl
    port map (
      Clk            => Clk,
      nReset         => nReset,
      ManagerRec     => ManagerRec,
      SubordinateRec => SubordinateRec
    );

    olo_inst : entity work.olo_axi_wrapper
    generic map (
        AxiAddrWidth_g            => AXI_ADDR_WIDTH,
        AxiDataWidth_g            => 32,
        ReadTimeoutClks_g         => 100,
        AxiMaxBeats_g             => 256,
        AxiMaxOpenTransactions_g  => 8,
        UserTransactionSizeBits_g => 21,
        DataFifoDepth_g           => 1024,
        ImplRead_g                => true,
        ImplWrite_g               => true,
        RamBehavior_g             => "RBW"
    )
    port map (
        Clk => Clk,
        Rst => not nReset,

        -- AXI4-Lite Slave Interface
        S_AxiLite_AWAddr  => AxiBus.WriteAddress.Addr,
        S_AxiLite_AWValid => AxiBus.WriteAddress.Valid,
        S_AxiLite_AWReady => AxiBus.WriteAddress.Ready,

        S_AxiLite_WData   => AxiBus.WriteData.Data,
        S_AxiLite_WStrb   => AxiBus.WriteData.Strb,
        S_AxiLite_WValid  => AxiBus.WriteData.Valid,
        S_AxiLite_WReady  => AxiBus.WriteData.Ready,

        S_AxiLite_BResp   => AxiBus.WriteResponse.Resp,
        S_AxiLite_BValid  => AxiBus.WriteResponse.Valid,
        S_AxiLite_BReady  => AxiBus.WriteResponse.Ready,

        S_AxiLite_ARAddr  => AxiBus.ReadAddress.Addr,
        S_AxiLite_ARValid => AxiBus.ReadAddress.Valid,
        S_AxiLite_ARReady => AxiBus.ReadAddress.Ready,

        S_AxiLite_RData   => AxiBus.ReadData.Data,
        S_AxiLite_RResp   => AxiBus.ReadData.Resp,
        S_AxiLite_RValid  => AxiBus.ReadData.Valid,
        S_AxiLite_RReady  => AxiBus.ReadData.Ready,

        -- AXI4 Master Interface
        M_Axi_AWAddr  => AxiBus_Slave.WriteAddress.Addr,
        M_Axi_AWLen   => M_Axi_AwLen,
        M_Axi_AWSize  => M_Axi_AwSize,
        M_Axi_AWBurst => M_Axi_AwBurst,
        M_Axi_AWLock  => M_Axi_AwLock,
        M_Axi_AWCache => AWCache_01,
        M_Axi_AWProt  => AxiBus_Slave.WriteAddress.Prot,
        M_Axi_AWValid => AxiBus_Slave.WriteAddress.Valid,
        M_Axi_AWReady => AxiBus_Slave.WriteAddress.Ready,

        M_Axi_WData   => AxiBus_Slave.WriteData.Data,
        M_Axi_WStrb   => AxiBus_Slave.WriteData.Strb,
        M_Axi_WLast   => M_Axi_WLast,
        M_Axi_WValid  => AxiBus_Slave.WriteData.Valid,
        M_Axi_WReady  => AxiBus_Slave.WriteData.Ready,

        M_Axi_BResp   => AxiBus_Slave.WriteResponse.Resp,
        M_Axi_BValid  => AxiBus_Slave.WriteResponse.Valid,
        M_Axi_BReady  => AxiBus_Slave.WriteResponse.Ready,

        M_Axi_ARAddr  => AxiBus_Slave.ReadAddress.Addr,
        M_Axi_ARLen   => M_Axi_ArLen,
        M_Axi_ARSize  => M_Axi_ArSize,
        M_Axi_ARBurst => M_Axi_ArBurst,
        M_Axi_ARLock  => M_Axi_ArLock,
        M_Axi_ARCache => ARCache_01,
        M_Axi_ARProt  => AxiBus_Slave.ReadAddress.Prot,
        M_Axi_ARValid => AxiBus_Slave.ReadAddress.Valid,
        M_Axi_ARReady => AxiBus_Slave.ReadAddress.Ready,

        M_Axi_RData   => AxiBus_Slave.ReadData.Data,
        M_Axi_RResp   => AxiBus_Slave.ReadData.Resp,
        M_Axi_RLast   => '1',
        M_Axi_RValid  => AxiBus_Slave.ReadData.Valid,
        M_Axi_RReady  => AxiBus_Slave.ReadData.Ready
    );


end architecture TestHarness;
