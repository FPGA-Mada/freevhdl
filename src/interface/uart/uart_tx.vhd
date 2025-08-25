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
-- Author: Nambinina Rakotojaona
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

    -- Compute total frame bits (start + data + parity? + stop)
    function get_frame_bits(DATA_WIDTH : positive; PARITY : string) return positive is
    begin
        if PARITY = "NONE" then
            return DATA_WIDTH + 2; -- start + data + stop
        else
            return DATA_WIDTH + 3; -- start + data + parity + stop
        end if;
    end function;

    -- Build UART frame (stop + optional parity + data + start)
    function packet_format (
        data        : std_logic_vector;
        parity_bit  : std_logic;
        parity      : string
    ) return std_logic_vector is
        variable frame : std_logic_vector(get_frame_bits(data'length, parity)-1 downto 0);
    begin
        if parity = "NONE" then
            frame := '1' & data & '0';  -- stop + data + start
        else
            frame := '1' & parity_bit & data & '0';  -- stop + parity + data + start
        end if;
        return frame;
    end function;

    -- Calculate parity bit
    function calc_parity(data : std_logic_vector; parity_in : string) return std_logic is
        variable p : std_logic := '0';
    begin
        for i in data'range loop
            p := p xor data(i);
        end loop;

        if parity_in = "NONE" then
            return '0';
        elsif parity_in = "EVEN" then
            return p;
        else  -- ODD
            return not p;
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
    type state_t is (IDLE, TRANSMIT);

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
        state            => IDLE,
        baud_counter     => 0,
        data_bit_counter => 0,
        shift_data_reg   => (others => '0'),
        parity           => '0',
        s_ready          => '0'
    );
    
    -- Shift register procedure: shift right and output LSB
    procedure shift_data_lsb (
        signal current_reg   : in  std_logic_vector;
        variable next_reg    : out std_logic_vector;
        variable tx_output   : out std_logic
    ) is
    begin
        -- Output the LSB
        tx_output := current_reg(current_reg'low);
        
        -- Shift right and fill MSB with '0'
        next_reg := '0' & current_reg(current_reg'high downto 1);
    end procedure shift_data_lsb;

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
        variable v         : uart_state_t;
        variable baud_tick  : std_logic := '0';
    begin
        v := r;

        -- Baud counter increment (simpler than modulo)
        if r.baud_counter >= COUNTER_MAX - 1 then
            baud_tick := '1';
            v.baud_counter := 0;
        else
            baud_tick := '0';
            v.baud_counter := r.baud_counter + 1;
        end if;

        case r.state is
            -------------------------------------------------------------------
            when IDLE =>
                -- Idle line, ready to accept new data
                v.tx := '1';
                v.s_ready := '1';
                if s_valid = '1' and r.s_ready = '1' then
                    v.s_ready := '0';
                    v.parity := calc_parity(s_data, PARITY);
                    v.shift_data_reg := packet_format(s_data, v.parity, PARITY);
                    v.state := TRANSMIT;
                    v.data_bit_counter := 0;
                end if;

            -------------------------------------------------------------------
            when TRANSMIT =>
                -- Transmit frame LSB first
                if baud_tick = '1' then
                    -- call procedure shift data
                    shift_data_lsb (r.shift_data_reg, v.shift_data_reg,v.tx);
                    if v.data_bit_counter = FRAME_BITS - 1 then
                        v.state := IDLE;
                        v.data_bit_counter := 0;
                    else
                        v.data_bit_counter := v.data_bit_counter + 1;
                    end if;
                end if;

            -------------------------------------------------------------------
            when others =>
                v.state := IDLE;
        end case;

        r_next <= v;
    end process;

end Behavioral;