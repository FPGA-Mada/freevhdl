library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.math_utils.all;

entity olo_axi_lite_slave_wrapper is
    generic (
        AxiAddrWidth_g      : positive := 8;
        AxiDataWidth_g      : positive := 32;
        ReadTimeoutClks_g   : positive := 100
    );
    port (
        -- Clock and Reset
        Clk               : in  std_logic;
        Rst               : in  std_logic;

        -- AXI-Lite Interface
        -- AR channel
        S_AxiLite_ArAddr  : in  std_logic_vector(AxiAddrWidth_g - 1 downto 0);
        S_AxiLite_ArValid : in  std_logic;
        S_AxiLite_ArReady : out std_logic;

        -- AW channel
        S_AxiLite_AwAddr  : in  std_logic_vector(AxiAddrWidth_g - 1 downto 0);
        S_AxiLite_AwValid : in  std_logic;
        S_AxiLite_AwReady : out std_logic;

        -- W channel
        S_AxiLite_WData   : in  std_logic_vector(AxiDataWidth_g - 1 downto 0);
        S_AxiLite_WStrb   : in  std_logic_vector((AxiDataWidth_g / 8) - 1 downto 0);
        S_AxiLite_WValid  : in  std_logic;
        S_AxiLite_WReady  : out std_logic;

        -- B channel
        S_AxiLite_BResp   : out std_logic_vector(1 downto 0);
        S_AxiLite_BValid  : out std_logic;
        S_AxiLite_BReady  : in  std_logic;

        -- R channel
        S_AxiLite_RData   : out std_logic_vector(AxiDataWidth_g - 1 downto 0);
        S_AxiLite_RResp   : out std_logic_vector(1 downto 0);
        S_AxiLite_RValid  : out std_logic;
        S_AxiLite_RReady  : in  std_logic
    );
end entity;

architecture rtl of olo_axi_lite_slave_wrapper is

    -- Register Bus signals
    signal Rb_Addr    : std_logic_vector(AxiAddrWidth_g - 1 downto 0);
    signal Rb_Wr      : std_logic;
    signal Rb_ByteEna : std_logic_vector((AxiDataWidth_g / 8) - 1 downto 0);
    signal Rb_WrData  : std_logic_vector(AxiDataWidth_g - 1 downto 0);
    signal Rb_Rd      : std_logic;
    signal Rb_RdData  : std_logic_vector(AxiDataWidth_g - 1 downto 0);
    signal Rb_RdValid : std_logic;

    -- Memory
    constant MemDepth_c : integer := pow2(AxiAddrWidth_g-2);
	signal Rb_Rd_d1 : std_logic := '0';



begin

    -- AXI-Lite Slave Instantiation
    u_axi_lite_slave : entity work.olo_axi_lite_slave
        generic map (
            AxiAddrWidth_g     => AxiAddrWidth_g,
            AxiDataWidth_g     => AxiDataWidth_g,
            ReadTimeoutClks_g  => ReadTimeoutClks_g
        )
        port map (
            Clk               => Clk,
            Rst               => Rst,
            S_AxiLite_ArAddr  => S_AxiLite_ArAddr,
            S_AxiLite_ArValid => S_AxiLite_ArValid,
            S_AxiLite_ArReady => S_AxiLite_ArReady,
            S_AxiLite_AwAddr  => S_AxiLite_AwAddr,
            S_AxiLite_AwValid => S_AxiLite_AwValid,
            S_AxiLite_AwReady => S_AxiLite_AwReady,
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
		
        -- RAM Instantiations 
        ram_inst: entity work.olo_base_ram_sdp
        generic map (
            Depth_g         => MemDepth_c,
            Width_g         => AxiDataWidth_g,
            IsAsync_g       => false,
            RdLatency_g     => 1,
            RamStyle_g      => "auto",
            RamBehavior_g   => "RBW",
            UseByteEnable_g => false,
            InitString_g    => "",
            InitFormat_g    => "NONE"
        )
        port map (
            Clk         => clk,
            Wr_Addr     => Rb_Addr (Rb_Addr'high downto 2),
            Wr_Ena      => Rb_Wr,
            Wr_Be       => Rb_ByteEna,
            Wr_Data     => Rb_WrData,
            Rd_Clk      => clk,
            Rd_Addr     =>  Rb_Addr (Rb_Addr'high downto 2),
            Rd_Ena      =>  Rb_Rd,
            Rd_Data     => Rb_RdData,
			Rd_Valid    => Rb_RdValid
        );
	  
end architecture;
