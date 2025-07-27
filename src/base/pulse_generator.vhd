library IEEE; 
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity pulse is
    generic (
        PULSE_WIDTH : positive := 1
    );
    Port (
        clk : in std_logic;
        rst : in std_logic;
        In_data : in std_logic;
        Out_data : out std_logic 
    );
end pulse;

architecture Behavioral of pulse is
    signal Out_data_s : std_logic := '0';
    signal counter_pulse : integer range 0 to PULSE_WIDTH := 0;
    signal prev_In_data : std_logic := '0';
begin
    -- output 
    Out_data <= Out_data_s;

    pulse_proc : process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                counter_pulse <= 0;
                Out_data_s <= '0';
                prev_In_data <= '0';
            else
                prev_In_data <= In_data;

                if (In_data = '1' and prev_In_data = '0') then
                    counter_pulse <= PULSE_WIDTH;
                    Out_data_s <= '1';
                elsif (counter_pulse > 1) then
                    counter_pulse <= counter_pulse - 1;
                    Out_data_s <= '1';
                elsif (counter_pulse = 1) then
                    counter_pulse <= 0;
                    Out_data_s <= '0';
                else
                    Out_data_s <= '0';
                end if;

            end if;
        end if;
    end process;
end Behavioral;
