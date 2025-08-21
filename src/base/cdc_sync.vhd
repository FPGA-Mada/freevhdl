-------------------------------------------------------------------------------
-- cdc_multi_bit_sync
--
-- PURPOSE:
--   Synchronize multiple independent single-bit signals from clk_A domain
--   into clk_B domain using a multi-stage synchronizer.
--
-- NOTES:
--   - No reset is used: synchronizers do not need reset.
--   - Each bit is synchronized individually.
--   - This is ONLY safe for independent control/status signals.
--   - For multi-bit coherent data transfer, use handshake/FIFO/Gray code.
--   - Attributes keep/dont_touch added to preserve FFs during synthesis.
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity cdc_multi_bit_sync is
  generic (
    WIDTH   : integer := 1;  -- number of independent single-bit signals
    STAGES  : integer := 2   -- must be >= 2
  );
  port (
    clk_A   : in  std_logic;
    data_A  : in  std_logic_vector(WIDTH-1 downto 0);

    clk_B   : in  std_logic;
    data_B  : out std_logic_vector(WIDTH-1 downto 0)
  );
end cdc_multi_bit_sync;

architecture rtl of cdc_multi_bit_sync is
  -- Input register in clk_A domain
  signal data_A_reg : std_logic_vector(WIDTH-1 downto 0) := (others => '0');

  -- Synchronizer pipeline in clk_B domain
  type sync_array is array (0 to STAGES-1) of std_logic_vector(WIDTH-1 downto 0);
  signal sync_pipe : sync_array := (others => (others => '0'));

  -- -------------------------------
  -- Keep attributes for synthesis
  -- -------------------------------

  -- Standard VHDL attributes
  attribute keep : string;
  attribute dont_touch : string;

  attribute keep of data_A_reg : signal is "true";
  attribute keep of sync_pipe   : signal is "true";

  attribute dont_touch of data_A_reg : signal is "true";
  attribute dont_touch of sync_pipe   : signal is "true";

begin
  -- Assert minimum number of stages
  assert (STAGES >= 2)
    report "cdc_multi_bit_sync: STAGES must be >= 2 for proper metastability protection"
    severity FAILURE;

  -- Input register (clk_A domain)
  process(clk_A)
  begin
    if rising_edge(clk_A) then
      data_A_reg <= data_A;
    end if;
  end process;

  -- Synchronizer pipeline (clk_B domain)
  process(clk_B)
  begin
    if rising_edge(clk_B) then
      sync_pipe(0) <= data_A_reg;              -- stage 0
      for i in 1 to STAGES-1 loop
        sync_pipe(i) <= sync_pipe(i-1);        -- retiming
      end loop;
    end if;
  end process;

  -- Output: synchronized signals
  data_B <= sync_pipe(STAGES-1);

end rtl;