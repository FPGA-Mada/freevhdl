library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity cdc_multi_bit_sync is
  generic (
    WIDTH   : integer := 8;  -- number of independent single-bit signals
    STAGES  : integer := 2   -- must be >= 2
  );
  port (
    clk_A   : in  std_logic;
    rst_A   : in  std_logic;
    data_A  : in  std_logic_vector(WIDTH-1 downto 0);

    clk_B   : in  std_logic;
    rst_B   : in  std_logic;
    data_B  : out std_logic_vector(WIDTH-1 downto 0)
  );
end cdc_multi_bit_sync;

architecture rtl of cdc_multi_bit_sync is
  -- Registered in clk_A to remove glitches
  signal data_A_reg : std_logic_vector(WIDTH-1 downto 0) := (others => '0');

  -- Synchronizer pipeline in clk_B
  type sync_array is array (0 to STAGES-1) of std_logic_vector(WIDTH-1 downto 0);
  signal sync_pipe : sync_array := (others => (others => '0'));

begin
  -- Assert minimum number of stages
  assert (STAGES >= 2)
    report "cdc_multi_bit_sync: STAGES must be >= 2 for proper metastability protection"
    severity FAILURE;

  -- Input register (clk_A)
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

  -- Synchronizer pipeline (clk_B)
  process(clk_B)
  begin
    if rising_edge(clk_B) then
      if rst_B = '1' then
        sync_pipe <= (others => (others => '0'));
      else
        sync_pipe(0) <= data_A_reg;              -- stage 0
        for i in 1 to STAGES-1 loop
          sync_pipe(i) <= sync_pipe(i-1);        -- retiming
        end loop;
      end if;
    end if;
  end process;

  data_B <= sync_pipe(STAGES-1); -- synchronized output

end rtl;
