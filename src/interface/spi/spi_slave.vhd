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
    -- FSM register record
    --------------------------------------------------------------------
    type fsm_reg_t is record
        sclk            : std_logic;
        counter         : integer range 0 to 3*DATA_WIDTH-1;
        state           : state_t;
        valid           : std_logic;
        data            : std_logic_vector(DATA_WIDTH-1 downto 0);
        miso            : std_logic;
        shift_reg       : std_logic_vector(3*DATA_WIDTH-1 downto 0);
        addr            : std_logic_vector(DATA_WIDTH-1 downto 0);
        data_from_master: std_logic_vector(DATA_WIDTH-1 downto 0);
    end record;

    signal r, r_next : fsm_reg_t;

    --------------------------------------------------------------------
    -- Synchronizer signals
    --------------------------------------------------------------------
    signal ss_sync, sclk_sync, mosi_sync : std_logic_vector(1 downto 0);
    signal ss_i, sclk_i, mosi_i          : std_logic;

    --------------------------------------------------------------------
    -- Shift MSB-first procedure
    --------------------------------------------------------------------
    procedure shift_data_msb (
        signal current_data : in std_logic_vector;
        variable next_data  : out std_logic_vector;
        variable bit_out    : out std_logic
    ) is
    begin
        bit_out  := current_data(current_data'high);
        next_data := current_data(current_data'high-1 downto 0) & '0';
    end procedure shift_data_msb;

begin

    --------------------------------------------------------------------
    -- Output assignments
    --------------------------------------------------------------------
    data  <= r.data;
    valid <= r.valid;
    miso  <= r.miso;

    --------------------------------------------------------------------
    -- SPI synchronizer
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
        rising_sclk  := sclk_i and not  r.sclk;
        falling_sclk := not sclk_i and r.sclk;

        -- Update registered SCLK
        v.sclk := sclk_i;

        -- Clear valid when master accepts data
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
                        v.state            := WAIT_SS;
                        v.valid            := '1';
                        v.data             := v.shift_reg(DATA_WIDTH-1 downto 0);
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
                        shift_data_msb(r.data_from_master, v.data_from_master, v.miso);

                        if r.counter = 3*DATA_WIDTH-1 then
                            v.state   := WAIT_SS;
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
