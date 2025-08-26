architecture AxiSendGet2 of TestCtrl is
    signal TestDone : integer_barrier := 1;
begin

    ------------------------------------------------------------
    -- ControlProc
    --   Set up AlertLog and wait for end of test
    ------------------------------------------------------------
    ControlProc : process
    begin
        SetTestName("Tb_send_data");
        TranscriptOpen;
        SetTranscriptMirror(TRUE);
        SetLogEnable(PASSED, FALSE);
        SetLogEnable(INFO, FALSE);

        -- Wait for testbench initialization 
        wait for 0 ns;
        wait until nReset = '1';
        ClearAlerts;
        WaitForBarrier(TestDone, 300 ms);
        AlertIf(now >= 300 ms, "Test finished due to timeout");
        AlertIf(GetAffirmCount < 1, "Test is not Self-Checking");

        wait for 1 us;
        EndOfTestReports(ReportAll => TRUE);
        TranscriptClose;
        std.env.finish;
        wait;
    end process ControlProc;

    ------------------------------------------------------------
    -- write command  (inlined)
    ------------------------------------------------------------
    write_cmd : process
    begin
        cmd_valid <= '0';
        wait until nReset = '1';
        log("******************write data****************");

        -- wait for handshake
        wait until cmd_ready = '1';
        wait until rising_edge(Clk);

        -- send_write inlined
        cmd_inst  <= x"01";  -- write instruction
        cmd_addr  <= x"04";  -- address
        cmd_data  <= x"FF";  -- data
        cmd_valid <= '1';    -- handshake valid
        log("******************write data done****************");
        WaitForBarrier(TestDone);
        wait;
    end process write_cmd;

    ------------------------------------------------------------
    -- AxiReceiverProc
    --   Generate transactions for AxiReceiver
    ------------------------------------------------------------
    AxiReceiverProc : process
        variable ExpData : std_logic_vector(DATA_WIDTH-1 downto 0);
        variable RcvData : std_logic_vector(DATA_WIDTH-1 downto 0);
    begin
        WaitForClock(StreamRxRec1, 2);

        ExpData := x"FF";
        Get(StreamRxRec1, RcvData);
        log("Data Received: " & to_hstring(RcvData));
        AffirmIfEqual(RcvData, ExpData, "wrong data not same");

        WaitForClock(StreamRxRec1, 2);
        WaitForBarrier(TestDone);
        wait;
    end process AxiReceiverProc;

end AxiSendGet2;

------------------------------------------------------------
-- Configuration
------------------------------------------------------------
configuration Tb_send_data of TestHarness_fifo is
    for TestHarness
        for TestCtrl_1 : TestCtrl
            use entity work.TestCtrl(AxiSendGet2);
        end for;
    end for;
end Tb_send_data;
