TestSuite TestHarness_frame 

SetLogSignals true



analyze TestCtrl_e.vhd
analyze TestHarness_fifo.vhd


#Testcases:

analyze Tb_send_data.vhd

simulate Tb_send_data