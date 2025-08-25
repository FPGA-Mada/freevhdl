-------------------------------------------------------------------------------
-- UART Receiver (uart_rx.vhd)
--
-- Features:
--   * Parameterized data width
--   * Configurable parity: NONE, EVEN, ODD
--   * AXI-Stream style interface (m_valid / m_ready)
--   * Start bit noise filtering
--   * Mid-bit sampling for accurate data capture
--
-- Frame Format:
--   Start bit ('0'), DATA_WIDTH bits (LSB first),
--   Optional parity bit, Stop bit ('1')
--
-- Notes:
--   * Single clock domain (clk)
--   * rst is synchronous active-high
--   * Baud tick generated internally
--   * Shift register length and parity index computed using functions
--
-- Author: Nambinina Rakotojaona
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_rx is
    generic (
        DATA_WIDTH   : positive := 8;
        BAUD_RATE    : positive := 9600;
        FREQUENCY_HZ : positive := 100_000_000;
        PARITY       : string := "EVEN"  -- "NONE", "EVEN", "ODD"
    );
    port (
        clk          : in  std_logic;
        rst          : in  std_logic;
        m_data       : out std_logic_vector(DATA_WIDTH-1 downto 0);
        m_valid      : out std_logic;
        m_ready      : in  std_logic;
        error_parity : out std_logic;
        rx           : in  std_logic
    );
end uart_rx;

architecture Behavioral of uart_rx is

    ---------------------------------------------------------------------------
    -- Functions
    ---------------------------------------------------------------------------
    -- Compute number of frame bits (data + optional parity)
    function get_frame_bits(DATA_WIDTH: positive; PARITY: string) return positive is
    begin
        if PARITY = "NONE" then
            return DATA_WIDTH;
        else
            return DATA_WIDTH + 1; -- data + parity
        end if;
    end function;

    -- Compute parity of data
    function calc_parity(data: std_logic_vector; PARITY: string) return std_logic is
        variable p : std_logic := '0';
    begin
        for i in data'range loop
            p := p xor data(i);
        end loop;
        if PARITY = "NONE" then return '0';
        elsif PARITY = "EVEN" then return p;
        else return not p; -- ODD parity
        end if;
    end function;

    -- Return index of parity bit in shift register
    function parity_index(DATA_WIDTH: positive; PARITY: string) return integer is
    begin
        if PARITY = "NONE" then
            return -1;
        else
            return DATA_WIDTH; -- parity bit is right after data bits
        end if;
    end function;

    ---------------------------------------------------------------------------
    -- Constants
    ---------------------------------------------------------------------------
    constant COUNTER_MAX  : positive := FREQUENCY_HZ / BAUD_RATE;
    constant COUNTER_HALF : positive := COUNTER_MAX / 2;
    constant FRAME_BITS   : positive := get_frame_bits(DATA_WIDTH, PARITY);

    ---------------------------------------------------------------------------
    -- State type
    ---------------------------------------------------------------------------
    type state_t is (WAIT_START, START_CONFIRM, RECEIVE_BITS, CHECK_STOP);

    type uart_rx_state_t is record
        state        : state_t;
        baud_counter : integer range 0 to COUNTER_MAX-1;
        bit_counter  : integer range 0 to FRAME_BITS-1;
        shift_reg    : std_logic_vector(FRAME_BITS-1 downto 0);
        m_valid      : std_logic;
        error_parity : std_logic;
    end record;

    constant RESET_STATE : uart_rx_state_t := (
        state        => WAIT_START,
        baud_counter => 0,
        bit_counter  => 0,
        shift_reg    => (others => '0'),
        m_valid      => '0',
        error_parity => '0'
    );

    signal r, r_next : uart_rx_state_t;
    
    signal sync_rx : std_logic_vector (1 downto 0);
    signal rx_i : std_logic;

begin

    ---------------------------------------------------------------------------
    -- Outputs
    ---------------------------------------------------------------------------
    m_data       <= r.shift_reg(DATA_WIDTH-1 downto 0);
    m_valid      <= r.m_valid;
    error_parity <= r.error_parity;
    rx_i <= sync_rx(1);
    
    ---------------------------------------------------------------------------
    -- sync rx signal
    ---------------------------------------------------------------------------
    sync_rx_proc: process (clk)
        begin
            if rising_edge(clk) then
                sync_rx(0) <= rx;
                sync_rx(1) <= sync_rx(0);
            end if;
        end process;
        
    ---------------------------------------------------------------------------
    -- Sequential process
    ---------------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                r <= RESET_STATE;
            else
                r <= r_next;
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Combinational next-state logic
    ---------------------------------------------------------------------------
    process(all)
        variable v : uart_rx_state_t;
        variable baud_tick : std_logic;
    begin
        v := r;
        v.m_valid := '0';
        v.error_parity := r.error_parity;

        -- Increment baud counter
        v.baud_counter := (r.baud_counter + 1) mod COUNTER_MAX;
        baud_tick := '1' when r.baud_counter = COUNTER_MAX-1 else '0';

        case r.state is

            ---------------------------------------------------------------
            when WAIT_START =>
                if rx_i = '0' then -- potential start bit
                    v.state := START_CONFIRM;
                    v.baud_counter := 0;
                    v.shift_reg := (others => '0');
                    v.bit_counter := 0;
                    v.error_parity := '0';
                end if;

            ---------------------------------------------------------------
            when START_CONFIRM =>
                if r.baud_counter = COUNTER_HALF then
                    if rx_i = '0' then
                        v.state := RECEIVE_BITS;
                        v.baud_counter := 0;
                        v.bit_counter := 0;
                    else
                        v.state := WAIT_START; -- noise detected
                    end if;
                end if;

            ---------------------------------------------------------------
            when RECEIVE_BITS =>
                if baud_tick = '1' then
                    -- shift in LSB first
                    v.shift_reg := rx_i & r.shift_reg(FRAME_BITS-1 downto 1);

                    if r.bit_counter = FRAME_BITS-1 then
                        v.state := CHECK_STOP;
                    else
                        v.bit_counter := r.bit_counter + 1;
                    end if;
                end if;

            ---------------------------------------------------------------
            when CHECK_STOP =>
                if baud_tick = '1' then
                    -- stop bit check
                    if rx_i = '1' then
                        v.m_valid := '1';
                        if PARITY /= "NONE" then
                            v.error_parity := calc_parity(r.shift_reg(DATA_WIDTH-1 downto 0), PARITY)
                                              xor r.shift_reg(parity_index(DATA_WIDTH, PARITY));
                        else
                            v.error_parity := '0';
                        end if;
                    end if;
                    v.state := WAIT_START;
                    v.baud_counter := 0;
                end if;

            when others =>
                v.state := WAIT_START;

        end case;

        r_next <= v;
    end process;

end Behavioral;
