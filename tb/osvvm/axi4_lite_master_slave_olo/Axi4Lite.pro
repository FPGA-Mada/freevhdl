TestSuite Test_axi4_register 

SetLogSignals true


analyze TestCtrl_e.vhd
analyze TbAxi4.vhd


#Testcases:
analyze normal_operation.vhd
simulate normal_operation