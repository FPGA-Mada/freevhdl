-------------------------------------------------------------------------------
-- Title       : Loadable Free-Running Counter
-------------------------------------------------------------------------------
-- Description :
--   A generic free-running counter with optional load and overflow detection.
--   - Increments on every rising edge of the clock when not reset.
--   - Wraps to zero and asserts a one-cycle overflow pulse when the maximum 
--     count (SYS_CLOCK / WRAP_CLOCK) is reached.
--   - Allows loading an arbitrary value via the 'load' signal.
--   - Provides outputs:
--       * counter_out : current counter value
--       * overflow    : one-cycle pulse when counter wraps
-------------------------------------------------------------------------------

library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
	use IEEE.MATH_REAL.ALL;

library work;
	use work.olo_base_pkg_array.all;
	use work.olo_base_pkg_math.all;

entity loadable_counter is
    generic(
        SYS_CLOCK  : real := 50.0e6;  -- system clock frequency in Hz
        WRAP_CLOCK : real := 1.0e6  -- desired wrap rate in Hz
    );
    port (
        clk          : in  std_logic;
        rst          : in  std_logic;
        load         : in  std_logic;
        Counter_load : in  unsigned(log2ceil(integer(round(SYS_CLOCK/WRAP_CLOCK)))-1 downto 0);
        counter_out  : out unsigned(log2ceil(integer(round(SYS_CLOCK/WRAP_CLOCK)))-1 downto 0);
        overflow     : out std_logic
    );
end loadable_counter;

architecture Behavioral of loadable_counter is
    constant COUNTER_MAX   : integer := integer(round(SYS_CLOCK/WRAP_CLOCK));
    constant COUNTER_WIDTH : integer := log2ceil(COUNTER_MAX);

    -- record type for two-process counter
    type TwoProcess_r is record
        counter_out : unsigned(COUNTER_WIDTH-1 downto 0);
        overflow    : std_logic;      
    end record;

    signal r, r_next : TwoProcess_r;

begin
	
	--*** assertion check ***--
    assert (SYS_CLOCK > 0.0 and WRAP_CLOCK > 0.0 and SYS_CLOCK > 2.0 * WRAP_CLOCK)
        report "SYS_CLOCK and WRAP_CLOCK constraints violated"
        severity failure;
		
    ---*** outputs ***---
    counter_out <= r.counter_out;
    overflow    <= r.overflow;

    ---*** sequential logic ***---
    seq_proc: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                r.counter_out <= (others => '0');
                r.overflow    <= '0';
            else
                r <= r_next;
            end if;
        end if;
    end process seq_proc;

    ---*** combinational logic ***---
    comb_proc: process(all)
        variable v : TwoProcess_r;
    begin
        -- copy current state
        v := r;

        -- free-running increment
        v.counter_out := r.counter_out + 1;
        v.overflow    := '0';

        -- wrap at max count
        if r.counter_out = COUNTER_MAX - 1 then
            v.counter_out := (others => '0');
            v.overflow    := '1';
        end if;

        -- load new value if requested
        if load = '1' then
            v.counter_out := Counter_load;
        end if;

        -- assign next state
        r_next <= v;
    end process comb_proc;

end Behavioral;
