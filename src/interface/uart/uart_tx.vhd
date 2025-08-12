library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_tx is
    generic(
        DATA_WIDTH   : positive := 8;          -- Number of data bits per frame
        BAUD_RATE    : positive := 9600;       -- UART baud rate
        FREQUENCY_HZ : positive := 100_000_000 -- System clock frequency
    );
    port (
        clk     : in  std_logic;
        rst     : in  std_logic;

        -- AXI stream interface signals
        s_valid : in  std_logic;                             -- Data valid from source
        s_ready : out std_logic;                             -- Ready to accept new data
        s_data  : in  std_logic_vector(DATA_WIDTH - 1 downto 0); -- Input data

        -- UART transmit output
        tx      : out std_logic
    );
end uart_tx;

architecture Behavioral of uart_tx is

    constant COUNTER_MAX : positive := FREQUENCY_HZ / BAUD_RATE;

    type state_t is (WAIT_VALID_DATA, SEND_START_BIT, SEND_DATA, SEND_PARITY, SEND_STOP_BIT);

    type uart_state_t is record
        tx               : std_logic;
        state            : state_t;
        baud_counter     : integer range 0 to COUNTER_MAX - 1;
        data_bit_counter : integer range 0 to DATA_WIDTH - 1;
        stop_bit_counter : integer range 0 to 1;
        data_buffer      : std_logic_vector(DATA_WIDTH - 1 downto 0);
        parity           : std_logic;
    end record;

    signal r, r_next : uart_state_t;
    signal ready_sig : std_logic;

    constant RESET_STATE : uart_state_t := (
        tx               => '1',
        state            => WAIT_VALID_DATA,
        baud_counter     => 0,
        data_bit_counter => 0,
        stop_bit_counter => 0,
        data_buffer      => (others => '0'),
        parity           => '0'
    );

    function calc_even_parity(data: std_logic_vector) return std_logic is
        variable p : std_logic := '0';
    begin
        for i in data'range loop
            p := p xor data(i);
        end loop;
        return p;
    end function;

begin

    tx <= r.tx;
    s_ready <= ready_sig;

    -- Sequential process: registers update
    proc_sequential: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                r <= RESET_STATE;
            else
                r <= r_next;
            end if;
        end if;
    end process;

    -- Combinational process: next state and output logic
    proc_combinational: process(r, s_valid, s_data)
        variable v : uart_state_t;
        variable baud_tick : std_logic := '0';
        variable ready_int : std_logic := '0';  -- Default to '0'
    begin
		-- stable variable
        v := r;
		ready_int := '0';
        -- Generate baud rate tick
        if r.baud_counter = COUNTER_MAX - 1 then
            baud_tick := '1';
            v.baud_counter := 0;
        else
            baud_tick := '0';
            v.baud_counter := r.baud_counter + 1;
        end if;

        case r.state is
            when WAIT_VALID_DATA =>
                v.tx := '1';
                ready_int := '1';
                if s_valid = '1' and ready_int = '1' then
                    ready_int := '0';  -- Go low exactly when accepting data
                    v.data_buffer := s_data;
                    v.parity := calc_even_parity(s_data);
                    v.state := SEND_START_BIT;
                    v.data_bit_counter := 0;
                    v.stop_bit_counter := 0;
                end if;

            when SEND_START_BIT =>
                if baud_tick = '1' then
                    v.tx := '0';
                    v.state := SEND_DATA;
                end if;

            when SEND_DATA =>
                if baud_tick = '1' then
                    v.tx := r.data_buffer(0);
                    v.data_buffer := '0' & r.data_buffer(DATA_WIDTH - 1 downto 1);
                    if r.data_bit_counter = DATA_WIDTH - 1 then
                        v.data_bit_counter := 0;
                        v.state := SEND_PARITY;
                    else
                        v.data_bit_counter := r.data_bit_counter + 1;
                    end if;
                end if;

            when SEND_PARITY =>
                if baud_tick = '1' then
                    v.tx := r.parity;
                    v.state := SEND_STOP_BIT;
                    v.stop_bit_counter := 0;
                end if;

            when SEND_STOP_BIT =>
                if baud_tick = '1' then
                    v.tx := '1';
                    if r.stop_bit_counter = 1 then
                        v.state := WAIT_VALID_DATA;
                    else
                        v.stop_bit_counter := r.stop_bit_counter + 1;
                    end if;
                end if;

            when others =>
                v.state := WAIT_VALID_DATA;
        end case;

        ready_sig <= ready_int;
        r_next <= v;
    end process;

end Behavioral;
