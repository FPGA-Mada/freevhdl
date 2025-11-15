library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.math_utils.all;

entity ram_sp is
  generic (
    RAM_DEPTH  : integer := 32;
    DATA_WIDTH : integer := 32
  );
  port (
    clk  : in  std_logic;
    rst  : in  std_logic;
    
	-- write side 
	wr_en : in std_logic;
	wr_addr: in std_logic_vector(clog2(RAM_DEPTH)-1 downto 0);
	wr_data: in std_logic_vector(DATA_WIDTH -1 downto 0);
	
	-- read side 
	rd_en : in std_logic;
	rd_addr: in std_logic_vector(clog2(RAM_DEPTH)-1 downto 0);
	rd_data : out std_logic_vector(DATA_WIDTH -1 downto 0)
  );
end entity;

architecture Behavioral of ram_sp is
	-- memory array
    type ram_type is array (0 to RAM_DEPTH - 1) of std_logic_vector (DATA_WIDTH -1 downto 0);
    signal ram_mem : ram_type := (others => (others => '0'));
	signal rd_data_r : std_logic_vector(DATA_WIDTH-1 downto 0);
    begin
	-- output
	rd_data <= rd_data_r;
	-- write process
	write_proc: process(clk)
		variable addr : integer;
		begin
			if rising_edge(clk) then
				addr := to_integer(unsigned(wr_addr));
				if (wr_en = '1') then 
					ram_mem(addr) <= wr_data;
				end if;
			end if;
		end process write_proc;
	
	-- read process 
	read_proc: process(clk)
		variable addr : integer;
		begin
			if rising_edge(clk) then
			    addr := to_integer(unsigned(rd_addr));
				if rst = '1' then 
					rd_data_r <= (others => '0');
				elsif(rd_en = '1') then
					rd_data_r <= ram_mem(addr);
				end if;
			end if;
		end process;
end architecture;
