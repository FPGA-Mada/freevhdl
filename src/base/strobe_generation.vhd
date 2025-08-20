library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity strobe_generation is
    generic (
        FREQ_SYS_HZ : positive;  -- System clock frequency
        FREQ_TARGET : positive   -- Desired strobe frequency
    );
    port (
        clk       : in  std_logic;  -- System clock
        rst       : in  std_logic;  -- Synchronous reset
        tx        : in  std_logic;  -- Input trigger
        tx_strobe : out std_logic   -- Output strobe pulse (1 cycle)
    );
end strobe_generation;

architecture Behavioral of strobe_generation is

    -- Calculate the counter max based on system and target frequencies
    constant COUNTER_MAX : positive := FREQ_SYS_HZ / FREQ_TARGET;

    -- State record for two-process style
    type TwoProcess_r is record
        counter   : integer range 0 to COUNTER_MAX - 1;  -- Countdown for strobe
        tx_strobe : std_logic;                           -- Output pulse
        tx        : std_logic;                           -- Delayed input for edge detection
    end record;

    -- Signals to hold current and next state
    signal r, r_next : TwoProcess_r;

    -- Reset value for the record
    constant RESET_R : TwoProcess_r := (
        counter   => 0,
        tx_strobe => '0',
        tx        => '0'
    );

begin

    -------------------------------------------------------------------------
    -- Sequential process: register state on rising edge of clk
    -------------------------------------------------------------------------
    seq_proc: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                r <= RESET_R;
            else
                r <= r_next;
            end if;
        end if;
    end process seq_proc;

    -------------------------------------------------------------------------
    -- Combinational process: calculate next state
    -------------------------------------------------------------------------
    comb_proc: process(all)
        variable v : TwoProcess_r;
    begin
        -- Start with current state
        v := r;

        v.tx := tx;

        -- Default: no strobe
        v.tx_strobe := '0';

        -- Detect rising edge of tx
        if (tx = '1' and r.tx = '0') then
            -- Start countdown to generate strobe
            v.counter := COUNTER_MAX - 1;

        -- Countdown for strobe generation
        elsif (r.counter > 0) then
            v.counter := r.counter - 1;

            -- Generate 1-cycle strobe when counter reaches 0
            if r.counter = 1 then
                v.tx_strobe := '1';
            end if;
        end if;

        -- Assign computed next state
        r_next <= v;
    end process comb_proc;

    -- Connect output
    tx_strobe <= r.tx_strobe;

end Behavioral;
