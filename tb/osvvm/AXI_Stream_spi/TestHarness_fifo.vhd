-- #########################################################################
--  File Name:         TestHarness_fifo.vhd
--  Design Unit Name:  TestHarness_fifo
--  Description:       Top-level testbench for AxiStreamTransmitter/Receiver SPI
-- #########################################################################

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.numeric_std_unsigned.all;

library osvvm;
  context osvvm.OsvvmContext;

library osvvm_AXI4;
  context osvvm_AXI4.AxiStreamContext;

entity TestHarness_fifo is
end entity TestHarness_fifo;

architecture TestHarness of TestHarness_fifo is

  constant tperiod_Clk : time := 10 ns;
  constant tpd         : time := 2 ns;

  signal Clk    : std_logic := '1';
  signal nReset : std_logic;
  constant DATA_WIDTH : integer := 8;

  constant AXI_DATA_WIDTH  : integer := 8;
  constant AXI_BYTE_WIDTH  : integer := AXI_DATA_WIDTH/8;
  constant TID_MAX_WIDTH   : integer := 8;
  constant TDEST_MAX_WIDTH : integer := 4;
  constant TUSER_MAX_WIDTH : integer := 5;
  constant PARITY          : string  := "EVEN";

  constant INIT_ID   : std_logic_vector(TID_MAX_WIDTH-1 downto 0)   := (others => '0');
  constant INIT_DEST : std_logic_vector(TDEST_MAX_WIDTH-1 downto 0) := (others => '0');
  constant INIT_USER : std_logic_vector(TUSER_MAX_WIDTH-1 downto 0) := (others => '0');

  signal TxTValid, TxTValid1 : std_logic;
  signal TxTReady, TxTReady1 : std_logic;

  signal TxTID,   TxTID1     : std_logic_vector(TID_MAX_WIDTH-1 downto 0);
  signal TxTDest, TxTDest1   : std_logic_vector(TDEST_MAX_WIDTH-1 downto 0);
  signal TxTUser, TxTUser1   : std_logic_vector(TUSER_MAX_WIDTH-1 downto 0);
  signal TxTData, TxTData1   : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
  signal TxTStrb, TxTStrb1   : std_logic_vector(AXI_BYTE_WIDTH-1 downto 0);
  signal TxTKeep, TxTKeep1   : std_logic_vector(AXI_BYTE_WIDTH-1 downto 0);
  signal TxTLast, TxTLast1   : std_logic;
  
  signal cmd_inst  : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal cmd_addr  : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal cmd_data  : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal cmd_valid : std_logic;
  signal cmd_ready : std_logic;

  constant AXI_PARAM_WIDTH : integer := TID_MAX_WIDTH + TDEST_MAX_WIDTH + TUSER_MAX_WIDTH + 1;

  signal StreamRxRec, StreamRxRec1 : StreamRecType(
      DataToModel    (AXI_DATA_WIDTH-1  downto 0),
      DataFromModel  (AXI_DATA_WIDTH-1  downto 0),
      ParamToModel   (AXI_PARAM_WIDTH-1 downto 0),
      ParamFromModel (AXI_PARAM_WIDTH-1 downto 0)
    );

  component TestCtrl is
    generic (
      ID_LEN   : integer;
      DEST_LEN : integer;
      USER_LEN : integer;
	  DATA_WIDTH : integer
    );
    port (
      nReset      : inout std_logic;
	  Clk         : in std_logic;
      StreamRxRec : inout StreamRecType;
      StreamRxRec1: inout StreamRecType;
      cmd_inst    : out std_logic_vector(DATA_WIDTH-1 downto 0);
      cmd_addr    : out std_logic_vector(DATA_WIDTH-1 downto 0);
      cmd_data    : out std_logic_vector(DATA_WIDTH-1 downto 0);
      cmd_valid   : out std_logic;
      cmd_ready   : in  std_logic
    );
  end component;

begin

  -- DUT instance 
  DUT : entity work.spi_top
    generic map (
      CPOL       => false,
      DATA_WIDTH => 8,
      FREQ_SYS   => 100_000_000,
      FREQ_SPI   => 1_000_000
    )
    port map (
      clk          => Clk,
      rst          => not nReset,
      cmd_instr    => cmd_inst,
      cmd_addr     => cmd_addr,
      cmd_data     => cmd_data,
      cmd_valid    => cmd_valid,
      cmd_ready    => cmd_ready,
      master_valid => TxTValid,
      master_data  => TxTData,
      master_ready => TxTReady,
      slave_valid  => TxTValid1,
      slave_data   => TxTData1,
      slave_ready  => TxTReady1
    );

  -- Create Clock
  Osvvm.ClockResetPkg.CreateClock(
    Clk    => Clk,
    Period => tperiod_Clk
  );

  -- Create Reset
  Osvvm.ClockResetPkg.CreateReset(
    Reset       => nReset,
    ResetActive => '0',
    Clk         => Clk,
    Period      => 7 * tperiod_Clk,
    tpd         => tpd
  );

  -- AXI Stream Receivers
  Receiver_1 : AxiStreamReceiver
    generic map (
      tperiod_Clk    => tperiod_Clk,
      INIT_ID        => INIT_ID,
      INIT_DEST      => INIT_DEST,
      INIT_USER      => INIT_USER,
      INIT_LAST      => 0,
      tpd_Clk_TReady => tpd
    )
    port map (
      Clk      => Clk,
      nReset   => nReset,
      TValid   => TxTValid,
      TReady   => TxTReady,
      TID      => TxTID,
      TDest    => TxTDest,
      TUser    => TxTUser,
      TData    => TxTData,
      TStrb    => TxTStrb,
      TKeep    => TxTKeep,
      TLast    => TxTLast,
      TransRec => StreamRxRec
    );

  Receiver_2 : AxiStreamReceiver
    generic map (
      tperiod_Clk    => tperiod_Clk,
      INIT_ID        => INIT_ID,
      INIT_DEST      => INIT_DEST,
      INIT_USER      => INIT_USER,
      INIT_LAST      => 0,
      tpd_Clk_TReady => tpd
    )
    port map (
      Clk      => Clk,
      nReset   => nReset,
      TValid   => TxTValid1,
      TReady   => TxTReady1,
      TID      => TxTID1,
      TDest    => TxTDest1,
      TUser    => TxTUser1,
      TData    => TxTData1,
      TStrb    => TxTStrb1,
      TKeep    => TxTKeep1,
      TLast    => TxTLast1,
      TransRec => StreamRxRec1
    );

  -- Test Control block
  TestCtrl_1 : TestCtrl
    generic map (
      ID_LEN   => TxTID'length,
      DEST_LEN => TxTDest'length,
      USER_LEN => TxTUser'length,
	  DATA_WIDTH => DATA_WIDTH
    )
    port map (
      nReset       => nReset,
	  Clk          => Clk,
      StreamRxRec  => StreamRxRec,
      StreamRxRec1 => StreamRxRec1,
      cmd_inst     => cmd_inst,
      cmd_addr     => cmd_addr,
      cmd_data     => cmd_data,
      cmd_valid    => cmd_valid,
      cmd_ready    => cmd_ready
    );

end architecture TestHarness;
