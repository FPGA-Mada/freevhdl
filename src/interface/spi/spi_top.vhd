library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity spi_top is
    generic(
        CPOL       : boolean := false;
        DATA_WIDTH : positive := 8;
        FREQ_SYS   : positive := 100000000;
        FREQ_SPI   : positive := 1000000
    );
    port(
        clk        : in  std_logic;
        rst        : in  std_logic;
        -- Master command interface
        cmd_instr  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        cmd_addr   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        cmd_data   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        cmd_valid  : in  std_logic;
        cmd_ready  : out std_logic;
        -- Master output data
        master_valid : out std_logic;
        master_data  : out std_logic_vector(DATA_WIDTH-1 downto 0);
        master_ready : in std_logic;
        -- Slave output data
        slave_valid : out std_logic;
        slave_data  : out std_logic_vector(DATA_WIDTH-1 downto 0);
        slave_ready : in std_logic
    );
end spi_top;

architecture Behavioral of spi_top is

    -- Internal SPI wires
    signal ss_sig, sclk_sig, mosi_sig, miso_sig : std_logic;


begin

    ------------------------------------------------------------------------
    -- SPI Master instance
    ------------------------------------------------------------------------
    u_master : entity work.spi_master
        generic map(
            CPOL       => CPOL,
            DATA_WIDTH => DATA_WIDTH,
            FREQ_SYS   => FREQ_SYS,
            FREQ_SPI   => FREQ_SPI
        )
        port map(
            clk       => clk,
            rst       => rst,
            cmd_instr => cmd_instr,
            cmd_addr  => cmd_addr,
            cmd_data  => cmd_data,
            cmd_valid => cmd_valid,
            cmd_ready => cmd_ready,
            ss        => ss_sig,
            sclk      => sclk_sig,
            mosi      => mosi_sig,
            miso      => miso_sig,
            valid     => master_valid,
            ready     => master_ready, 
            data      => master_data
        );

    ------------------------------------------------------------------------
    -- SPI Slave instance
    ------------------------------------------------------------------------
    u_slave : entity work.spi_slave
        generic map(
            DATA_WIDTH => DATA_WIDTH
        )
        port map(
            clk   => clk,
            rst   => rst,
            ss    => ss_sig,
            sclk  => sclk_sig,
            mosi  => mosi_sig,
            miso  => miso_sig,
            valid => slave_valid,
            ready => slave_ready, 
            data  => slave_data
        );


end Behavioral;
