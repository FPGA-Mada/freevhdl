library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_rx is
    generic (
        DATA_WIDTH   : positive := 8;
        BAUD_RATE    : positive := 9600;
        FREQUENCY_HZ : positive := 100_000_000
    );
    port (
        clk          : in  std_logic;
        rst          : in  std_logic;
        m_data       : out std_logic_vector(DATA_WIDTH - 1 downto 0);
        m_valid      : out std_logic;
        m_ready      : in  std_logic;
        error_parity : out std_logic;
        rx           : in  std_logic
    );
end uart_rx;

architecture Behavioral of uart_rx is

    constant COUNTER_MAX  : positive := FREQUENCY_HZ / BAUD_RATE;
    constant COUNTER_HALF : positive := COUNTER_MAX / 2;

    type state_t is (WAIT_RX_LOW, START_COUNTING, RECEIVE_DATA, RECEIVE_PARITY, RECEIVE_STOP);

    function calc_even_parity(data: std_logic_vector) return std_logic is
        variable p : std_logic := '0';
    begin
        for i in data'range loop
            p := p xor data(i);
        end loop;
        return p;
    end function;

    type uart_rx_reg is record
        m_valid           : std_logic;
        m_data            : std_logic_vector(DATA_WIDTH - 1 downto 0);
        counter_baud_rate  : integer range 0 to COUNTER_MAX -1;
        counter_bit_width  : integer range 0 to DATA_WIDTH -1;
        error_parity      : std_logic;
        state             : state_t;
    end record;

    constant RESET_R : uart_rx_reg := (
        m_valid           => '0',
        m_data            => (others => '0'),
        counter_baud_rate => 0,
        counter_bit_width => 0,
        error_parity      => '0',
        state             => WAIT_RX_LOW
    );

    signal r, r_next : uart_rx_reg;

begin

    -- Output signals
    m_valid      <= r.m_valid;
    m_data       <= r.m_data;
    error_parity <= r.error_parity;

    -- Sequential process
    seq_proc: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                r <= RESET_R;
            else
                r <= r_next;
            end if;
        end if;
    end process;

    -- Combinational next-state logic
    comb_proc: process(all)
        variable v : uart_rx_reg;
    begin
        v := r;

        -- Clear valid and parity error when downstream accepts data
        if (r.m_valid = '1' and m_ready = '1') then
            v.m_valid := '0';
            v.error_parity := '0';
        end if;

        -- Increment baud rate counter
        v.counter_baud_rate := (r.counter_baud_rate + 1) mod COUNTER_MAX;

        case r.state is
            when WAIT_RX_LOW =>
                if rx = '0' then
                    v.counter_baud_rate := 0;
                    v.state := START_COUNTING;
                    v.error_parity := '0';
                end if;

            when START_COUNTING =>
                if r.counter_baud_rate = COUNTER_HALF then
                    if rx = '0' then
                        v.state := RECEIVE_DATA;
                        v.counter_baud_rate := 0;
                        v.counter_bit_width := 0;
                    else
                        v.state := WAIT_RX_LOW;
                    end if;
                end if;

            when RECEIVE_DATA =>
                if r.counter_baud_rate = COUNTER_MAX - 1 then
                    v.counter_baud_rate := 0;
                    v.counter_bit_width := (r.counter_bit_width + 1) mod DATA_WIDTH;
                    v.m_data := rx & r.m_data(DATA_WIDTH - 1 downto 1);

                    if r.counter_bit_width = DATA_WIDTH - 1 then
                        v.state := RECEIVE_PARITY;
                        v.counter_bit_width := 0;
                    end if;
                end if;

            when RECEIVE_PARITY =>
                if r.counter_baud_rate = COUNTER_MAX - 1 then
                    v.m_valid := '1';
                    if calc_even_parity(r.m_data) = rx then
                        v.error_parity := '0';
                    else
                        v.error_parity := '1';
                    end if;
                    v.state := RECEIVE_STOP;
                    v.counter_baud_rate := 0;
                end if;

            when RECEIVE_STOP =>
                if r.counter_baud_rate = COUNTER_MAX - 1 then
                    if rx = '1' then
                        v.state := WAIT_RX_LOW;
                        v.counter_baud_rate := 0;
                    end if;
                end if;

            when others =>
                null;
        end case;

        r_next <= v;
    end process;

end Behavioral;
