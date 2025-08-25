-------------------------------------------------------------------------------
-- UART Transmitter (uart_tx.vhd)
--
-- Features:
--   * Parameterized data width
--   * Configurable parity: NONE, EVEN, ODD
--   * AXI-Stream style interface (s_valid / s_ready)
--
-- Frame Format:
--   Start bit ('0'), DATA_WIDTH bits (LSB first),
--   Optional parity bit, Stop bit ('1')
--
-- Notes:
--   * Single clock domain (clk)
--   * rst is synchronous active-high
--   * Baud tick is generated internally
--
-- Author: Senior-Style Reference Implementation
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_tx is
    generic(
        DATA_WIDTH   : positive := 8;             -- Number of data bits per frame
        BAUD_RATE    : positive := 9600;          -- UART baud rate
        FREQUENCY_HZ : positive := 100_000_000;   -- System clock frequency
        PARITY       : string   := "EVEN"         -- "NONE", "EVEN", or "ODD"
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

    ---------------------------------------------------------------------------
    -- Local Functions
    ---------------------------------------------------------------------------

    -- Function to compute total frame bits (start + data + parity? + stop)
    function get_frame_bits(
        DATA_WIDTH : positive;
        PARITY     : string
    ) return positive is
    begin
        if PARITY = "NONE" then
            return DATA_WIDTH + 2; -- start + data + stop
        else
            return DATA_WIDTH + 3; -- start + data + parity + stop
        end if;
    end function;

    -- Parity calculator
    function calc_parity(data : std_logic_vector; parity_in : string) return std_logic is
        variable p : std_logic := '0';
    begin
        -- XOR of all bits
        for i in data'range loop
            p := p xor data(i);
        end loop;

        if parity_in = "NONE" then
            return '0';  -- unused
        elsif parity_in = "EVEN" then
            return p;    -- XOR gives even parity
        elsif parity_in = "ODD" then
            return not p;
        else
            return '0';
        end if;
    end function;

    ---------------------------------------------------------------------------
    -- Constants
    ---------------------------------------------------------------------------
    constant COUNTER_MAX : positive := FREQUENCY_HZ / BAUD_RATE;
    constant FRAME_BITS  : positive := get_frame_bits(DATA_WIDTH, PARITY);

    ---------------------------------------------------------------------------
    -- Type / Record Declarations
    ---------------------------------------------------------------------------
    type state_t is (WAIT_VALID_DATA, SEND_DATA);

    type uart_state_t is record
        tx               : std_logic;
        state            : state_t;
        baud_counter     : integer range 0 to COUNTER_MAX - 1;
        data_bit_counter : integer range 0 to FRAME_BITS - 1;
        shift_data_reg   : std_logic_vector(FRAME_BITS-1 downto 0);
        parity           : std_logic;
        s_ready          : std_logic;
    end record;

    signal r, r_next : uart_state_t;

    ---------------------------------------------------------------------------
    -- Reset State
    ---------------------------------------------------------------------------
    constant RESET_STATE : uart_state_t := (
        tx               => '1',              -- idle line
        state            => WAIT_VALID_DATA,
        baud_counter     => 0,
        data_bit_counter => 0,
        shift_data_reg   => (others => '0'),
        parity           => '0',
        s_ready          => '0'
    );

begin

    ---------------------------------------------------------------------------
    -- Assertions: Defensive checks for generics
    ---------------------------------------------------------------------------
    assert BAUD_RATE > 0
        report "BAUD_RATE must be > 0"
        severity failure;

    assert FREQUENCY_HZ > (BAUD_RATE * 2)
        report "FREQUENCY_HZ must be at least 2x BAUD_RATE"
        severity failure;

    assert (PARITY = "NONE") or (PARITY = "EVEN") or (PARITY = "ODD")
        report "Invalid PARITY generic"
        severity failure;

    ---------------------------------------------------------------------------
    -- Output Assignments
    ---------------------------------------------------------------------------
    tx      <= r.tx;
    s_ready <= r.s_ready;

    ---------------------------------------------------------------------------
    -- Sequential process: register updates
    ---------------------------------------------------------------------------
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

    ---------------------------------------------------------------------------
    -- Combinational process: next-state and output logic
    ---------------------------------------------------------------------------
    proc_combinational: process(all)
        variable v : uart_state_t;
        variable baud_tick : std_logic := '0';
    begin
        v := r;

        -- Baud counter increment
        v.baud_counter := (r.baud_counter + 1) mod COUNTER_MAX;
        baud_tick := '1' when r.baud_counter = COUNTER_MAX - 1 else '0';

        case r.state is
            -------------------------------------------------------------------
            when WAIT_VALID_DATA =>
                v.tx := '1';    -- idle line
                v.s_ready := '1';
                if s_valid = '1' and r.s_ready = '1' then
                    v.s_ready := '0';
                    v.parity := calc_parity(s_data, PARITY);

                    if (PARITY = "NONE") then
                        -- Format: stop(1) & data & start(0)
                        v.shift_data_reg := '1' & s_data & '0';
                    else
                        -- Format: stop(1) & parity & data & start(0)
                        v.shift_data_reg := '1' & v.parity & s_data & '0';
                    end if;

                    v.state := SEND_DATA;
                    v.data_bit_counter := 0;
                end if;

            -------------------------------------------------------------------
            when SEND_DATA =>
                if baud_tick = '1' then
                    -- Transmit LSB first
                    v.tx := r.shift_data_reg(0);
                    -- Shift right, pad MSB with '0'
                    v.shift_data_reg := '0' & r.shift_data_reg(FRAME_BITS-1 downto 1);

                    if (r.data_bit_counter = FRAME_BITS - 1) then
                        v.state := WAIT_VALID_DATA;
                        v.data_bit_counter := 0;
                        v.tx := '1'; -- return line to idle
                    else
                        v.data_bit_counter := r.data_bit_counter + 1;
                    end if;
                end if;

            -------------------------------------------------------------------
            when others =>
                v.state := WAIT_VALID_DATA;
        end case;

        r_next <= v;
    end process;

end Behavioral;
