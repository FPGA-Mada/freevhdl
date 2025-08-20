library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity strobe_generation is
    generic (
        RETRIGERING : boolean := false;          -- Allow retriggering during countdown
        FREQ_SYS_HZ : positive;                  -- System clock frequency
        FREQ_TARGET : positive                   -- Desired strobe frequency
    );
    port (
        clk       : in  std_logic;               -- System clock
        rst       : in  std_logic;               -- Synchronous reset
        tx        : in  std_logic;               -- Input trigger
        tx_strobe : out std_logic                -- Output strobe pulse (1 cycle)
    );
end strobe_generation;

architecture Behavioral of strobe_generation is

    constant COUNTER_MAX : positive := FREQ_SYS_HZ / FREQ_TARGET;

    type TwoProcess_r is record
        counter        : integer range 0 to COUNTER_MAX - 1;
        tx_strobe      : std_logic;
        tx             : std_logic;
        flag_tx_detect : std_logic;
    end record;

    signal r, r_next : TwoProcess_r;

    constant RESET_R : TwoProcess_r := (
        counter        => 0,
        tx_strobe      => '0',
        tx             => '0',
        flag_tx_detect => '0'
    );

begin
    -------------------------------------------------------------------------
    -- Compile-time check
    -------------------------------------------------------------------------
    assert ((FREQ_SYS_HZ > FREQ_TARGET) and (FREQ_TARGET /= 0))
        report "FREQ_SYS_HZ must be greater than FREQ_TARGET!"
        severity FAILURE;

    -------------------------------------------------------------------------
    -- Sequential process
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
    -- Combinational process (handles both retriggering modes)
    -------------------------------------------------------------------------
    comb_proc: process(all)
        variable v : TwoProcess_r;
    begin
        v := r;
        v.tx := tx;
        v.tx_strobe := '0';

        if RETRIGERING then
            -- Retriggering allowed: start countdown on every rising edge of tx
            if (tx = '1' and r.tx = '0') then
                v.counter := COUNTER_MAX - 1;
            elsif (r.counter > 0) then
                v.counter := r.counter - 1;
                if v.counter = 0 then
                    v.tx_strobe := '1';
                end if;
            end if;

        else
            -- No retriggering: ignore new tx edges until countdown finishes
            if (tx = '1' and r.tx = '0' and r.flag_tx_detect = '0') then
                v.counter := COUNTER_MAX - 1;
                v.flag_tx_detect := '1';
            elsif (r.counter > 0) then
                v.counter := r.counter - 1;
                if r.counter = 1 then
                    v.tx_strobe := '1';
                    v.flag_tx_detect := '0';
                end if;
            end if;
        end if;

        r_next <= v;
    end process comb_proc;

    -- Output assignment
    tx_strobe <= r.tx_strobe;

end Behavioral;
