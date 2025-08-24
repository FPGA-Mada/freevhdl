library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity spi_slave is
    generic (
        DATA_WIDTH : positive := 8
    );
    port (
        clk   : in  std_logic;
        rst   : in  std_logic;
        -- SPI interface
        ss    : in  std_logic;
        sclk  : in  std_logic;
        mosi  : in  std_logic;
        miso  : out std_logic;
        -- AXI-like interface
        valid : out std_logic;
        ready : in  std_logic;
        data  : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end spi_slave;

architecture Behavioral of spi_slave is

    --------------------------------------------------------------------
    -- Constants
    --------------------------------------------------------------------
    constant WRITE_CMD : std_logic_vector(DATA_WIDTH-1 downto 0) := x"01";

    --------------------------------------------------------------------
    -- FSM state type
    --------------------------------------------------------------------
    type state_t is (WAIT_SS, CAPTURE_CMD, CAPTURE_DATA, CAPTURE_READ);

    --------------------------------------------------------------------
    -- FSM record
    --------------------------------------------------------------------
    type fsm_reg_t is record
        sclk      : std_logic;
        counter   : integer range 0 to 3*DATA_WIDTH-1;
        state     : state_t;
        valid     : std_logic;
        data      : std_logic_vector(DATA_WIDTH-1 downto 0);
        miso      : std_logic;
        shift_reg : std_logic_vector(3*DATA_WIDTH-1 downto 0);
        addr      : std_logic_vector(DATA_WIDTH-1 downto 0);
        data_from_master : std_logic_vector(DATA_WIDTH-1 downto 0);
    end record;

    signal r, r_next : fsm_reg_t;

    --------------------------------------------------------------------
    -- Synchronizer signals (moved OUT of block!)
    --------------------------------------------------------------------
    signal ss_sync, sclk_sync, mosi_sync : std_logic_vector(1 downto 0);
    signal ss_i, sclk_i, mosi_i          : std_logic;

begin

    --------------------------------------------------------------------
    -- Output assignments
    --------------------------------------------------------------------
    data  <= r.data;
    valid <= r.valid;
    miso  <= r.miso;

    --------------------------------------------------------------------
    -- SPI synchronizer (no block, signals declared outside)
    --------------------------------------------------------------------
    sync_proc: process(clk)
    begin
        if rising_edge(clk) then
            -- Stage 1
            ss_sync(0)   <= ss;
            sclk_sync(0) <= sclk;
            mosi_sync(0) <= mosi;
            -- Stage 2
            ss_sync(1)   <= ss_sync(0);
            sclk_sync(1) <= sclk_sync(0);
            mosi_sync(1) <= mosi_sync(0);
        end if;
    end process;

    ss_i   <= ss_sync(1);
    sclk_i <= sclk_sync(1);
    mosi_i <= mosi_sync(1);

    --------------------------------------------------------------------
    -- Sequential process
    --------------------------------------------------------------------
    seq_proc: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                r.state <= WAIT_SS;
                r.valid <= '0';
            else
                r <= r_next;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Combinational FSM process
    --------------------------------------------------------------------
    comb_proc: process(all)
        variable v : fsm_reg_t;
        variable rising_sclk, falling_sclk : std_logic;
    begin
        v := r;

        -- Detect SCLK edges
        rising_sclk  := '1' when (sclk_i = '1' and r.sclk = '0') else '0';
        falling_sclk := '1' when (sclk_i = '0' and r.sclk = '1') else '0';

        -- Update registered sclk
        v.sclk := sclk_i;

        -- Clear valid when master accepts
        if r.valid = '1' and ready = '1' then
            v.valid := '0';
        end if;

        -- FSM
        case r.state is
            when WAIT_SS =>
                if ss_i = '0' then
                    v.state   := CAPTURE_CMD;
                    v.counter := 0;
                end if;

            when CAPTURE_CMD =>
                if rising_sclk = '1' then
                    v.shift_reg := v.shift_reg(v.shift_reg'high-1 downto 0) & mosi_i;
                    v.counter   := r.counter + 1;

                    if r.counter = DATA_WIDTH-1 then
                        if v.shift_reg(DATA_WIDTH-1 downto 0) = WRITE_CMD then
                            v.state := CAPTURE_DATA;
                        else
                            v.state := CAPTURE_READ;
                        end if;
                    end if;
                end if;

            when CAPTURE_DATA =>
                if rising_sclk = '1' then
                    v.shift_reg := v.shift_reg(v.shift_reg'high-1 downto 0) & mosi_i;
                    v.counter   := r.counter + 1;

                    if r.counter = 3*DATA_WIDTH-1 then
                        v.state := WAIT_SS;
                        v.valid := '1';
                        v.data  := v.shift_reg(DATA_WIDTH-1 downto 0);
                        v.data_from_master := v.data;
                    end if;
                end if;

            when CAPTURE_READ =>
                -- Capture address
                if rising_sclk = '1' then
                    v.shift_reg := v.shift_reg(v.shift_reg'high-1 downto 0) & mosi_i;
                    v.counter   := r.counter + 1;

                    if r.counter <= 2*DATA_WIDTH-1 then
                        v.addr := v.shift_reg(2*DATA_WIDTH-1 downto DATA_WIDTH);
                    end if;
                end if;

                -- Drive MISO
                if falling_sclk = '1' then
                    if r.counter >= 2*DATA_WIDTH then
                        v.miso := r.data_from_master(r.data_from_master'high);
                        v.data_from_master := r.data_from_master(r.data_from_master'high-1 downto 0) & '0';

                        if r.counter = 3*DATA_WIDTH-1 then
                            v.state := WAIT_SS;
                            v.counter := 0;
                        end if;
                    end if;
                end if;

            when others =>
                null;
        end case;

        -- Assign next state
        r_next <= v;
    end process;

end Behavioral;
