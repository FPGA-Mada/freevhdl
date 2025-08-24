library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity spi_master is
    generic(
        CPOL : boolean := false;
        DATA_WIDTH : positive := 8;
        FREQ_SYS   : positive := 100_000_000;
        FREQ_SPI   : positive := 1_000_000
    );
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        cmd_instr : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        cmd_addr  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        cmd_data  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        cmd_valid : in  std_logic;
        cmd_ready : out std_logic;
        ss        : out std_logic;
        sclk      : out std_logic;
        mosi      : out std_logic;
        miso      : in  std_logic;
        valid     : out std_logic;
        ready     : in  std_logic;
        data      : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end spi_master;

architecture Behavioral of spi_master is

    constant CLOCK_DIV  : integer := (FREQ_SYS + FREQ_SPI/2)/FREQ_SPI;
    constant CLOCK_HALF : integer := CLOCK_DIV/2;
    constant DELAY_CYCLES : integer := FREQ_SYS / (2 * FREQ_SPI);

    type state_t is (WAIT_CMD, WRITE_TX, READ_TX);

    type spi_reg_t is record
        counter_spi   : integer range 0 to CLOCK_DIV-1;
        counter_bit   : integer range 0 to 3*DATA_WIDTH-1;
        write_data    : std_logic_vector(3*DATA_WIDTH-1 downto 0);
        read_data     : std_logic_vector(2*DATA_WIDTH-1 downto 0);
        ss            : std_logic;
        sclk          : std_logic;
        mosi          : std_logic;
        state         : state_t;
        cmd_ready     : std_logic;
        data          : std_logic_vector(DATA_WIDTH-1 downto 0);
        valid         : std_logic;
        delay_counter : integer range 0 to DELAY_CYCLES-1;
        start_counter : boolean;
    end record;

    signal r, r_next : spi_reg_t;
    signal miso_sync, miso_async : std_logic;

begin
    -- Outputs
    sclk      <= r.sclk;
    ss        <= r.ss;
    mosi      <= r.mosi;
    cmd_ready <= r.cmd_ready;
    data      <= r.data;
    valid     <= r.valid;

    -- MISO synchronizer
    sync_miso: process(clk)
    begin
        if rising_edge(clk) then
            miso_async <= miso;
            miso_sync  <= miso_async;
        end if;
    end process;

    -- Sequential process
    seq_proc: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                r.state <= WAIT_CMD;
                r.ss <= '1';
                r.sclk <= '0';
                r.start_counter <= false;
                r.counter_bit <= 0;
                r.valid <= '0';
            else
                r <= r_next;
            end if;
        end if;
    end process;

    -- Combinatorial FSM
    comb_proc: process(all)
        variable v : spi_reg_t;
        variable rising_sclk, falling_sclk, falling_sclk_delayed : std_logic;
    begin
        v := r;

        -- Clock divider
        v.counter_spi := (r.counter_spi + 1) mod CLOCK_DIV;
        v.sclk := '0';
        if v.counter_spi >= CLOCK_HALF then
            v.sclk := '1';
        end if;

        -- Edge detection
        rising_sclk  := '1' when (v.sclk = '1' and r.sclk = '0') else '0';
        falling_sclk := '1' when (v.sclk = '0' and r.sclk = '1') else '0';
        falling_sclk_delayed := '0';

        -- Delay counter for MISO sampling
        if r.start_counter then
            if r.delay_counter = DELAY_CYCLES-1 then
                v.delay_counter := 0;
                falling_sclk_delayed := '1';
                v.start_counter := false;
            else
                v.delay_counter := r.delay_counter + 1;
            end if;
        end if;

        if falling_sclk = '1' then
            v.start_counter := true;
        end if;

        -- Clear valid when slave ready
        if r.valid = '1' and ready = '1' then
            v.valid := '0';
        end if;

        -- FSM
        case r.state is
            when WAIT_CMD =>
                v.cmd_ready := '1';
                v.ss := '1';
                v.sclk := '0';
                if cmd_valid = '1' and r.cmd_ready = '1' then
                    v.cmd_ready := '0';
                    v.ss := '0';
                    if cmd_instr = x"01" then
                        v.state := WRITE_TX;
                        v.write_data := cmd_instr & cmd_addr & cmd_data;
                    else
                        v.state := READ_TX;
                        v.read_data := cmd_instr & cmd_addr;
                    end if;
                end if;

            when WRITE_TX =>
                if rising_sclk = '1' then
                    v.mosi := r.write_data(r.write_data'high);
                    v.write_data := r.write_data(r.write_data'high-1 downto 0) & '0';
                    if r.counter_bit = 3*DATA_WIDTH-1 then
                        v.counter_bit := 0;
                        v.state := WAIT_CMD;
                    else
                        v.counter_bit := r.counter_bit + 1;
                    end if;
                end if;

            when READ_TX =>
                -- MOSI shift
                if rising_sclk = '1' then
                    if r.counter_bit < 2*DATA_WIDTH then
                        v.mosi := r.read_data(r.read_data'high);
                        v.read_data := r.read_data(r.read_data'high-1 downto 0) & '0';
                    end if;
                    v.counter_bit := r.counter_bit + 1;
                end if;

                -- MISO capture
                if falling_sclk_delayed = '1' then
                    if r.counter_bit >= 2*DATA_WIDTH then
                        v.data := r.data(v.data'high-1 downto 0) & miso_sync;
                        if r.counter_bit = 3*DATA_WIDTH-1 then
                            v.counter_bit := 0;
                            v.state := WAIT_CMD;
                            v.valid := '1';
                        end if;
                    end if;
                end if;

            when others =>
                null;
        end case;

        r_next <= v;
    end process;

end Behavioral;
