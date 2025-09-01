-------------------------------------------------------------------------------
-- Title       : Smart Triggered Counter
-------------------------------------------------------------------------------
-- Description :
--   A generic free-running counter with trigger-based start and decrement.
--   - Waits for a rising edge on a designated start trigger to begin counting.
--   - Decrements on rising edges of a designated decrement trigger.
--   - When the counter reaches zero, it either reloads to maximum if 
--     period_enable is high, or stops and waits for the next start trigger.
--   - Provides outputs:
--       * period_counter : current value of the counter
--       * period_active  : one-cycle pulse when the period starts or reloads
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.olo_base_pkg_array.all;
use work.olo_base_pkg_math.all;

entity smart_counter is
    generic(
        COUNTER_WIDTH : positive := 64
    );
    port (
        clk              : in  std_logic;
        rst              : in  std_logic;
        -- trigger signals for start and decrement
        trigger_signals  : in  std_logic_vector(COUNTER_WIDTH-1 downto 0);
        start_index      : in  unsigned(log2ceil(COUNTER_WIDTH)-1 downto 0);
        decrement_index  : in  unsigned(log2ceil(COUNTER_WIDTH)-1 downto 0);
        period_enable    : in  std_logic;
        -- outputs
        period_counter   : out unsigned(COUNTER_WIDTH-1 downto 0);
        period_active    : out std_logic       
    );
end smart_counter;

architecture Behavioral of smart_counter is
    --------------------------------------------------------------------
    -- Constants & Types
    --------------------------------------------------------------------
    constant PERIOD_MAX : unsigned(COUNTER_WIDTH-1 downto 0) := (others => '1');

    type state_t is (st_wait_trigger, st_counting);

    type CounterRecord is record 
        period_counter : unsigned(COUNTER_WIDTH-1 downto 0);
        period_active  : std_logic; 
        state          : state_t;
        trigger_signals: std_logic_vector(COUNTER_WIDTH-1 downto 0);    
    end record;

    --------------------------------------------------------------------
    -- Signals
    --------------------------------------------------------------------
    signal r, r_next : CounterRecord;

begin
    --------------------------------------------------------------------
    -- Sequential process
    --------------------------------------------------------------------
    seq_proc: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                r.period_counter <= (others => '0');
                r.period_active  <= '0';
                r.state          <= st_wait_trigger;
                r.trigger_signals <= (others => '0');
            else
                r <= r_next;
            end if;
        end if;
    end process seq_proc;
        
    --------------------------------------------------------------------
    -- Combinational process
    --------------------------------------------------------------------
    comb_proc: process(all)
        variable v : CounterRecord;
        variable flag_rising_edge : std_logic;
    begin
        -- default assignments
        v := r;
        v.period_active := '0';
        v.trigger_signals := trigger_signals;
        flag_rising_edge := '0';

        -- edge detection for decrement signal
        if (trigger_signals(to_integer(decrement_index)) = '1' and 
            r.trigger_signals(to_integer(decrement_index)) = '0') then
            flag_rising_edge := '1';
        end if;

        -- FSM
        case r.state is 
            when st_wait_trigger =>
                if (trigger_signals(to_integer(start_index)) = '1') then
                    v.period_counter := PERIOD_MAX;
                    if (period_enable = '1') then
                        v.period_active := '1';
                    end if;
                    v.state := st_counting;
                end if;

            when st_counting =>
                if (flag_rising_edge = '1') then
                    if (r.period_counter = 0) then
                        if (period_enable = '1') then
                            v.period_counter := PERIOD_MAX;
                            v.period_active  := '1';
                        else
                            v.state := st_wait_trigger;
                        end if;
                    else
                        v.period_counter := r.period_counter - 1;
                    end if;
                end if;
        end case;

        -- assign to r_next
        r_next <= v;
    end process comb_proc;

    --------------------------------------------------------------------
    -- Output mapping
    --------------------------------------------------------------------
    period_counter <= r.period_counter;
    period_active  <= r.period_active;

end Behavioral;
