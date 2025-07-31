library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity non_cdc_data_buffer is
  generic (
    Latency     : integer := 3;
    DATA_WIDTH  : integer := 32
  );
  port (
    clk_A  : in  std_logic;
    rst_A  : in  std_logic;
    data_A : in  std_logic_vector(DATA_WIDTH - 1 downto 0);

    clk_B  : in  std_logic;
    rst_B  : in  std_logic;
    data_B : out std_logic_vector(DATA_WIDTH - 1 downto 0)
  );
end non_cdc_data_buffer;

architecture Behavioral of non_cdc_data_buffer is
  type data_latency is array (0 to Latency - 1) of std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal data_delay : data_latency := (others => (others => '0'));
  signal data_A_reg : std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
begin

  -- Register input data in clk_A domain
  process(clk_A)
  begin
    if rising_edge(clk_A) then
      if rst_A = '1' then
        data_A_reg <= (others => '0');
      else
        data_A_reg <= data_A;
      end if;
    end if;
  end process;

  -- Transfer and delay data in clk_B domain
  process(clk_B)
  begin
    if rising_edge(clk_B) then
      if rst_B = '1' then
        for i in 0 to Latency - 1 loop
          data_delay(i) <= (others => '0');
        end loop;
      else
        data_delay(0) <= data_A_reg;
        for i in 1 to Latency - 1 loop
          data_delay(i) <= data_delay(i - 1);
        end loop;
      end if;
    end if;
  end process;
  
  -- Output the final delayed value
  data_B <= data_delay(Latency - 1);

end Behavioral;
