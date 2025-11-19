--------------------------------------------------------------------------------
-- Copyright (c) 2025 GMV
-- All Rights Reserved
--------------------------------------------------------------------------------
-- __ _ _ __ _____ __
-- / _` | '_ ` _ \ \ / / Company: GMV
-- | (_| | | | | | \ V / Author: Nambinina Rakotojaona
-- \__, |_| |_| |_|\_/ Module: ram_sp_valid_out
-- __/ |
-- |___/
--
-- Create Date: November 2025
-- Design Name: ML-KEM
-- Module Name: ram_sp_valid_out.vhd
-- Project Name: CyberCUBE
-- Target Devices: 
-- Tool versions: 
-- Description: 
-- Dependencies:
--
-- Revision 0.01 - File Created
-- Additional Comments:
----------------------------------------------------------------------------------
library IEEE;
    use IEEE.STD_LOGIC_1164.ALL;
    use IEEE.NUMERIC_STD.ALL;
    use work.math_utils.all;
    
entity ram_sp_valid_out is
    generic (
        DEPTH : positive ;
        WIDTH : positive
    );
    Port (
        clk : in std_logic;
        -- read memory interface
        Rd_En : in std_logic;
        Rd_Addr : in std_logic_vector(clog2(DEPTH)-1 downto 0);
        Rd_Data : out std_logic_vector(WIDTH-1 downto 0);
        Rd_valid : out std_logic ;
        -- write memory interface
        Wr_En : in std_logic;
        Wr_Addr: in std_logic_vector (clog2(DEPTH)-1 downto 0);
        Wr_Data : in std_logic_vector(WIDTH-1 downto 0)
    );
end ram_sp_valid_out;

architecture Behavioral of ram_sp_valid_out is
    --*** memory array ***--
    type mem_t is array(0 to DEPTH-1) of std_logic_vector(WIDTH-1 downto 0);
    signal mem : mem_t := (others => (others => '0'));    
begin

    --*** Write process ***--
    write_proc: process(clk)
        variable Addr_v : integer;
        begin
            if rising_edge(clk) then
                Addr_v := to_integer(unsigned(Wr_Addr));
                if (Wr_En = '1') then 
                    mem(Addr_v) <= Wr_Data; 
                end if;
            end if;
        end process write_proc;
       
    --*** Read process ***--
    read_proc: process(clk)
        variable Addr_v : integer;
        begin
            if rising_edge(clk) then
                Addr_v := to_integer(unsigned(Rd_Addr));
                Rd_valid <= '0';
                if (Rd_En = '1') then 
                    Rd_Data <= mem(Addr_v); 
                    Rd_valid <= '1';
                end if;
            end if;
        end process read_proc;
end Behavioral;