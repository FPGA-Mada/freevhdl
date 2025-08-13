library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_top is
    generic (
        DATA_WIDTH   : positive := 8;
        BAUD_RATE    : positive := 9600;
        FREQUENCY_HZ : positive := 100_000_000
    );
    port (
        clk     : in  std_logic;
        rst     : in  std_logic;

        -- Input data to transmit
        s_valid : in  std_logic;
        s_data  : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
        s_ready : out std_logic;

        -- Output received data
        m_data       : out std_logic_vector(DATA_WIDTH - 1 downto 0);
        m_valid      : out std_logic;
        m_ready      : in  std_logic;

        -- Parity error indicator from receiver
        error_parity : out std_logic
    );
end uart_top;

architecture Behavioral of uart_top is

    signal tx_line : std_logic;  -- Connection between TX and RX

begin

    -- Instantiate UART Transmitter
    uart_tx_inst : entity work.uart_tx
        generic map (
            DATA_WIDTH   => DATA_WIDTH,
            BAUD_RATE    => BAUD_RATE,
            FREQUENCY_HZ => FREQUENCY_HZ
        )
        port map (
            clk     => clk,
            rst     => rst,
            s_valid => s_valid,
            s_ready => s_ready,
            s_data  => s_data,
            tx      => tx_line
        );

    -- Instantiate UART Receiver
    uart_rx_inst : entity work.uart_rx
        generic map (
            DATA_WIDTH   => DATA_WIDTH,
            BAUD_RATE    => BAUD_RATE,
            FREQUENCY_HZ => FREQUENCY_HZ
        )
        port map (
            clk          => clk,
            rst          => rst,
            m_data       => m_data,
            m_valid      => m_valid,
            m_ready      => m_ready,
            error_parity => error_parity,
            rx           => tx_line  -- Connect RX to TX output
        );

end Behavioral;
