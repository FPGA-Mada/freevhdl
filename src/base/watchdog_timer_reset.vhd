-------------------------------------------------------------------------------
-- Description    :  Watchdog Timer with configurable reset polarity.
--                   This module generates a system reset after a specified
--                   period of inactivity. Once triggered, the reset remains
--                   asserted indefinitely until the system is manually restarted.
--
-- Features:
--   1. Configurable granularity counter to scale the input clock.
--   2. Configurable time-to-reset counter to define reset timeout.
--   3. Configurable reset polarity (active-high or active-low).
--
-- Generic Parameters:
--   Granularity_counter   : Number of input clock cycles per "tick" of time counter.
--   Time_to_reset_counter : Number of "ticks" before asserting reset.
--   reset_active_high     : Boolean to select reset polarity.
--
-- Ports:
--   clk              : Input clock signal.
--   reset_system     : Output reset signal (configurable polarity).
--   reset_system_inv : Output reset signal with inverse polarity.
--
-- Notes:
--   - The reset remains asserted permanently once the timeout occurs.
--   - Counters are sized automatically based on the maximum values.
--   - Granularity counter allows long durations without huge counters.
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;  -- for safe large counters
use work.math_utils.all;    -- for clog2 function

entity watchdog_timer_reset is
    generic (
        Granularity_counter   : natural := 100_000_000;  -- 1 second for 100 MHz input clock
        Time_to_reset_counter : natural := 3600;         -- desired reset time in seconds
        reset_active_high     : boolean := true          -- reset polarity
    );
    port (
        clk              : in  std_logic;
        reset_system     : out std_logic;
        reset_system_inv : out std_logic
    );
end watchdog_timer_reset;

architecture Behavioral of watchdog_timer_reset is
    -- Counter widths calculated automatically for minimal resources
    constant counter_gran_width       : positive := clog2(Granularity_counter);
    constant counter_time_reset_width : positive := clog2(Time_to_reset_counter);

    -- Internal signals
    signal reset_reg          : std_logic := '0';
    signal counter_gran       : unsigned(counter_gran_width-1 downto 0) := (others => '0');
    signal counter_time_reset : unsigned(counter_time_reset_width-1 downto 0) := (others => '0');
begin

    -- Watchdog timer process
    watchdog_proc: process(clk)
    begin
        if rising_edge(clk) then
            -- Increment granularity counter
            if counter_gran = Granularity_counter - 1 then
                counter_gran <= (others => '0');

                -- Increment time-to-reset counter
                if counter_time_reset = Time_to_reset_counter - 1 then
                    -- Assert reset according to configured polarity
                    reset_reg <= '1' when reset_active_high else '0';
                else
                    counter_time_reset <= counter_time_reset + 1;
                    reset_reg <= '0' when reset_active_high else '1';
                end if;
            else
                counter_gran <= counter_gran + 1;
            end if;
        end if;
    end process;

    -- Output assignments
    reset_system     <= reset_reg;
    reset_system_inv <= not reset_reg;

end Behavioral;
