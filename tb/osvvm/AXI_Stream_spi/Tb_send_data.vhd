--
--  File Name:         Tb_send_data.vhd
--  Design Unit Name:  Architecture of TestCtrl
--  Revision:          OSVVM MODELS STANDARD VERSION
--
--  Maintainer:        Jim Lewis      email:  jim@synthworks.com
--  Contributor(s):
--     Jim Lewis      jim@synthworks.com
--
--
--  Description:
--      Validates Stream Model Independent Transactions
--      Send, Get, Check with 2nd parameter, with ID, Dest, User
--
--
--  Developed by:
--        SynthWorks Design Inc.
--        VHDL Training Classes
--        http://www.SynthWorks.com
--
--  Revision History:
--    Date      Version    Description
--    10/2020   2020.10    Initial revision
--
--
--  This file is part of OSVVM.
--  
--  Copyright (c) 2018 - 2020 by SynthWorks Design Inc.  
--  
--  Licensed under the Apache License, Version 2.0 (the "License");
--  you may not use this file except in compliance with the License.
--  You may obtain a copy of the License at
--  
--      https://www.apache.org/licenses/LICENSE-2.0
--  
--  Unless required by applicable law or agreed to in writing, software
--  distributed under the License is distributed on an "AS IS" BASIS,
--  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--  See the License for the specific language governing permissions and
--  limitations under the License.TestCtrl
--  


architecture AxiSendGet2 of TestCtrl is
  use      osvvm.ScoreboardPkg_slv.all;
  signal   TestDone : integer_barrier := 1 ;
  signal   SB : ScoreboardIDType;
		
	procedure send_write(
		addr_in  : in  std_logic_vector(DATA_WIDTH -1 downto 0);
	    data_in  : in  std_logic_vector(DATA_WIDTH -1 downto 0);
	    instr_out: out std_logic_vector(DATA_WIDTH -1 downto 0);
	    addr_out : out std_logic_vector(DATA_WIDTH -1 downto 0);
	    data_out : out std_logic_vector(DATA_WIDTH -1 downto 0);
	    valid_out : out std_logic
	) is
	begin
		instr_out <= x"01";
		addr_out  <= addr_in;
		data_out  <= data_in;
		valid_out <= '1';
	end procedure send_write;
	
	procedure send_read(
	    addr_in  : in  std_logic_vector(DATA_WIDTH -1 downto 0);
		 instr_out: out std_logic_vector(DATA_WIDTH -1 downto 0);
		 addr_out : out std_logic_vector(DATA_WIDTH -1 downto 0)
	) is
	begin
		instr_out <= x"00";
		addr_out  <= addr_in;
	end procedure send_read;
	
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
    wait until nReset = '1' ; 
	SB <= NEWID ("Score_Board"); 
    ClearAlerts;
    WaitForBarrier(TestDone, 100 ms);
    AlertIf(now >= 100 ms, "Test finished due to timeout");
    AlertIf(GetAffirmCount < 1, "Test is not Self-Checking");

    wait for 1 us;
    EndOfTestReports(ReportAll => TRUE);
    TranscriptClose;
    std.env.finish;
    wait;
  end process ControlProc;
  
  
  ------------------------------------------------------------
  -- write command 
  ------------------------------------------------------------
	write_cmd : process
	begin
		cmd_valid <= '0';
		wait until nReset = '1';
		log("write data");
		wait until cmd_ready = '1';  -- handshake
		send_write(x"04", x"FF",cmd_inst,cmd_addr,cmd_data,cmd_valid);
		wait until cmd_ready = '0';
		cmd_valid <= '0';
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


end AxiSendGet2 ;

Configuration Tb_send_data of TestHarness_fifo is
  for TestHarness
    for TestCtrl_5 : TestCtrl
      use entity work.TestCtrl(AxiSendGet2) ; 
    end for ; 
  end for ; 
end Tb_send_data ; 
