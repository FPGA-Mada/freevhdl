architecture BasicReadWrite of TestCtrl is
  signal TestDone : integer_barrier := 1 ;
  signal Req_1 : AlertLogIDType;

begin
  ------------------------------------------------------------
  -- ControlProc
  ------------------------------------------------------------
  ControlProc : process
  begin
    -- Initialization of test
    SetTestName("normal_operation");
    TranscriptOpen;
    SetTranscriptMirror(TRUE);
    SetLogEnable(PASSED, FALSE);    -- Enable PASSED logs
    SetLogEnable(INFO, FALSE);      -- Enable INFO logs
	
	Req_1 <= GetReqID("PR-0001", PassedGoal => 1, ParentID => REQUIREMENT_ALERTLOG_ID);
 
    -- Wait for Design Reset
    wait until nReset = '1';
    ClearAlerts;
    LOG("Start of Transactions");

    -- Wait for test to finish
    WaitForBarrier(TestDone, 5 ms);
    AlertIf(now >= 5 ms, "Test finished due to timeout");
    AlertIf(GetAffirmCount < 30, "Test is not Self-Checking");
	
	AffirmIf(Req_1, GetAlertCount = 0, GetTestName & "REQUIREMENT Req_1 FAILED!!!!!") ;

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
	variable en_compl, en : std_logic;
	variable addr_native, addr_compl : std_logic_vector (14 downto 0);
  begin
    -- Initialization
    wait until nReset = '1';
    WaitForClock(ManagerRec, 2);
    for int_value in 0 to 100 loop
        valu := std_logic_vector(to_unsigned(int_value, AXI_ADDR_WIDTH));
        data_send := std_logic_vector(to_unsigned(int_value, AXI_DATA_WIDTH));
        Write(ManagerRec, valu * 4, data_send);
        wait for 10 ns;
    end loop;
    for int_value in 0 to 100 loop
      valu := std_logic_vector(to_unsigned(int_value, AXI_ADDR_WIDTH));
      expect_data := std_logic_vector(to_unsigned(int_value, AXI_DATA_WIDTH));
      Read(ManagerRec, valu * 4, Data);
      AffirmIfEqual(Data, expect_data, "Manager Read Data: ");
      WaitForClock(ManagerRec, 2);
    end loop;

    WaitForClock(ManagerRec, 2);
    WaitForBarrier(TestDone);
    wait;
  end process ManagerProc;

   ------------------------------------------------------------
     -- Axi Subordinate
   ------------------------------------------------------------
   SubordinateProc : process
   variable Addr        : std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);
   variable RData       : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
   variable Addr_w        : std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);
   variable RData_w       : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
   begin
   -- Wait for Reset deassertion
   wait until nReset = '1';
   WaitForClock(SubordinateRec, 2);  -- Wait for a couple of clocks
   
   -- Loop through 32 addresses (assuming 4-byte aligned)
   for i in 0 to 9 loop
  	 Addr := std_logic_vector(to_unsigned(i * 4, AXI_ADDR_WIDTH));
  	 RData := std_logic_vector(to_unsigned(1, AXI_DATA_WIDTH));  
  	 -- Send read response to the DUT
  	 SendRead(SubordinateRec, Addr, RData);
	 GetWrite(SubordinateRec, Addr_w, RData_w) ;
         AffirmIfEqual(Addr_w,  std_logic_vector(to_unsigned(i * 4, AXI_ADDR_WIDTH)), "Subordinate Write Addr: ") ;
         AffirmIfEqual(RData_w,  std_logic_vector(to_unsigned(i * 4, AXI_ADDR_WIDTH)), "Subordinate Write Data: ") ;
  	 -- Optional: delay between responses
  	 wait for 10 ns;
   end loop;
   
   wait;  -- Process ends
   end process SubordinateProc;

 
    
   end BasicReadWrite;

Configuration normal_operation of TbAxi4 is
  for TestHarness
    for TestCtrl_1 : TestCtrl
      use entity work.TestCtrl(BasicReadWrite) ; 
    end for ; 
  end for ; 
end normal_operation ; 

