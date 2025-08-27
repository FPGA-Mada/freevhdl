-------------------------------------------------------------------------------
-- Title       : Cycle Counter
-------------------------------------------------------------------------------
-- Description : 
--   A generic cycle counter with start/stop control.
--   - Counts clock cycles when 'start' is asserted.
--   - Stops counting when 'stop' is asserted and outputs the cycle count.
--   - Provides a one-cycle pulse on 'valid' when a cycle count is captured.
--   - Provides a one-cycle pulse on 'overflow' when the counter reaches its 
--     maximum value (2^BITS - 1).
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity cycle_counter is
  generic (
    BITS : positive := 16
  );
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    start    : in  std_logic;
    stop     : in  std_logic;
    cycles   : out unsigned(BITS-1 downto 0);
    overflow : out std_logic;
    valid    : out std_logic
  );
end cycle_counter;

architecture rtl of cycle_counter is

  -- FSM states
  type t_state is (st_idle, st_count);

  -- Record grouping for datapath and control
  type t_reg is record
    state    : t_state;
    counter  : unsigned(BITS-1 downto 0);
    cycles   : unsigned(BITS-1 downto 0);
    overflow : std_logic;
    valid    : std_logic;
  end record;

  signal r, r_next : t_reg;

begin

  --------------------------------------------------------------------
  -- Output assignments
  --------------------------------------------------------------------
  cycles   <= r.cycles;
  overflow <= r.overflow;
  valid    <= r.valid;

  --------------------------------------------------------------------
  -- Sequential process (registers)
  --------------------------------------------------------------------
  seq_proc : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        -- reset only flag and counter
        r.state    <= st_idle;
        r.counter  <= (others => '0');
        r.overflow <= '0';
        r.valid    <= '0';
      else
        r <= r_next;
      end if;
    end if;
  end process seq_proc;

  --------------------------------------------------------------------
  -- Combinational process (next-state logic)
  --------------------------------------------------------------------
  comb_proc : process(all)
    variable v : t_reg;
  begin
    v := r;

    -- default one-cycle signals
    v.overflow := '0';
    v.valid    := '0';

    case r.state is
      -------------------------------------------------
      when st_idle =>
        v.counter := (others => '0');
        if start = '1' then
          v.state   := st_count;
          v.counter := to_unsigned(1, v.counter'length);
        end if;

      -------------------------------------------------
      when st_count =>
        v.counter := r.counter + 1;

        -- overflow detection
        if r.counter = (2**BITS - 1) then
          v.overflow := '1';
          v.state    := st_idle;
          v.counter  := (others => '0');

        -- stop condition
        elsif stop = '1' then
          v.cycles := r.counter;
          v.valid  := '1';
          v.state  := st_idle;
          v.counter := (others => '0');
        end if;

    end case;

    r_next <= v;
  end process comb_proc;

end rtl;
