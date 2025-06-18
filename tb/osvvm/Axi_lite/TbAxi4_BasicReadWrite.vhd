architecture BasicReadWrite of TestCtrl is
  signal TestDone : integer_barrier := 1 ;

begin
  ------------------------------------------------------------
  -- ControlProc
  ------------------------------------------------------------
  ControlProc : process
  begin
    -- Initialization of test
    SetTestName("TbAxi4_BasicReadWrite");
    TranscriptOpen;
    SetTranscriptMirror(TRUE);
    SetLogEnable(PASSED, FALSE);    -- Enable PASSED logs
    SetLogEnable(INFO, FALSE);      -- Enable INFO logs

    -- Wait for Design Reset
    wait until nReset = '1';
    ClearAlerts;
    LOG("Start of Transactions");

    -- Wait for test to finish
    WaitForBarrier(TestDone, 5 ms);
    AlertIf(now >= 35 ms, "Test finished due to timeout");
    AlertIf(GetAffirmCount < 1, "Test is not Self-Checking");

    wait for 1 us;

    EndOfTestReports(ReportAll => TRUE);
    TranscriptClose;
    std.env.stop;
    wait;
  end process ControlProc;

  ------------------------------------------------------------
  -- ManagerProc
  ------------------------------------------------------------
  ManagerProc : process
    variable Data : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
    variable data_send : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
    variable expect_data : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
    variable valu : std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);
  begin
    -- Initialization
    wait until nReset = '1';
    WaitForClock(ManagerRec, 2);

    -- Write loop
    for int_value in 0 to 511 loop
      valu := std_logic_vector(to_unsigned(int_value, AXI_ADDR_WIDTH));
      data_send := std_logic_vector(to_unsigned(int_value, AXI_DATA_WIDTH));
      Write(ManagerRec, valu*4, data_send);
      wait for 10 ns; -- Wait for 10 ns between values
    end loop;

    -- Read loop
    for int_value in 0 to 511 loop
      valu := std_logic_vector(to_unsigned(int_value, AXI_ADDR_WIDTH));
      expect_data := std_logic_vector(to_unsigned(int_value, AXI_DATA_WIDTH));
      Read(ManagerRec, valu*4, Data);
      AffirmIfEqual(Data, expect_data, "Manager Read Data: ");
      wait for 10 ns; -- Wait for 10 ns between values
    end loop;

    WaitForClock(ManagerRec, 2);
    WaitForBarrier(TestDone);
    wait;
  end process ManagerProc;
end BasicReadWrite;


Configuration TbAxi4_BasicReadWrite of TbAxi4 is
  for TestHarness
    for TestCtrl_1 : TestCtrl
      use entity work.TestCtrl(BasicReadWrite) ; 
    end for ; 
  end for ; 
end TbAxi4_BasicReadWrite ; 

