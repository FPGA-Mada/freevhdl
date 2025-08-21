library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity spi_master is
    generic(
        DATA_WIDTH : positive := 8;
        FREQ_SYS   : positive := 100_000_000; -- system clock frequency (Hz)
        FREQ_SPI   : positive := 1_000_000;   -- target SPI frequency (Hz)
        CPOL       : std_logic := '0';        -- clock polarity (0=idle low, 1=idle high)
        CPHA       : std_logic := '0'         -- clock phase (0=sample on 1st edge, 1=sample on 2nd edge)
    );
    port (
        clk  : in  std_logic;
        rst  : in  std_logic;
        -- command interface
        cmd_instruction : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        cmd_addr        : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        cmd_data        : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        cmd_valid       : in  std_logic;
        -- SPI interface
        sck   : out std_logic;
        mosi  : out std_logic;
        miso  : in  std_logic;
        cs    : out std_logic;
        -- data stream interface
        valid : out std_logic;
        ready : in  std_logic;
        data  : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end spi_master;

architecture Behavioral of spi_master is

    -- Calculate SPI clock divider
    -- Calculate SPI clock divider (with integer rounding)
    constant SPI_DIV  : integer := (FREQ_SYS + FREQ_SPI/2) / FREQ_SPI;
    constant HALF_DIV : integer := SPI_DIV / 2;

    -- FSM states
    type state_t is (IDLE, SEND_INST, SEND_DATA, READ_DATA);

    -- Record to hold internal registers
    type reg_t is record
        clk_count   : integer range 0 to SPI_DIV-1;
        sclk        : std_logic;
        mosi        : std_logic;
        cs          : std_logic;
        state       : state_t;
        instr_shift : std_logic_vector(2*DATA_WIDTH-1 downto 0);
        data_shift  : std_logic_vector(DATA_WIDTH-1 downto 0);
        bit_count   : integer range 0 to 2*DATA_WIDTH;
        data_count  : integer range 0 to DATA_WIDTH;
        write_flag  : std_logic;
        data_out    : std_logic_vector(DATA_WIDTH-1 downto 0);
        valid_out   : std_logic;
    end record;

    constant RESET_R : reg_t := (
        clk_count   => 0,
        sclk        => CPOL,
        mosi        => '0',
        cs          => '1',
        state       => IDLE,
        instr_shift => (others => '0'),
        data_shift  => (others => '0'),
        bit_count   => 0,
        data_count  => 0,
        write_flag  => '0',
        data_out    => (others => '0'),
        valid_out   => '0'
    );

    signal r, r_next : reg_t;

    -- Standard write opcode
    constant OP_WRITE : std_logic_vector(DATA_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(1, DATA_WIDTH));

begin

    -- Output assignments
    sck   <= r.sclk;
    mosi  <= r.mosi;
    cs    <= r.cs;
    valid <= r.valid_out;
    data  <= r.data_out;

    -----------------------------------------------------------------
    -- Sequential Process
    -----------------------------------------------------------------
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

    -----------------------------------------------------------------
    -- Combinational Process
    -----------------------------------------------------------------
    comb_proc: process(all)
        variable v : reg_t;
        variable sclk_rising, sclk_falling : boolean;
        variable sclk_next : std_logic;
    begin
        v := r;

        -- Clock divider
        v.clk_count := (r.clk_count + 1) mod SPI_DIV;
        if v.clk_count < HALF_DIV then
            sclk_next := not CPOL;
        else
            sclk_next := CPOL;
        end if;

        sclk_rising  := (r.sclk = '0' and sclk_next = '1');
        sclk_falling := (r.sclk = '1' and sclk_next = '0');
        v.sclk := sclk_next;

        -- Handshake clearing
        if (r.valid_out = '1' and ready = '1') then
            v.valid_out := '0';
        end if;

        -- FSM
        case r.state is
            when IDLE =>
                v.cs := '1';
                v.sclk := CPOL;
                v.mosi := '0';
                v.bit_count := 0;
                v.data_count := 0;
                if cmd_valid = '1' then
                    v.write_flag := '1' when (cmd_instruction = OP_WRITE) else '0';
                    v.instr_shift := cmd_instruction & cmd_addr;
                    v.data_shift  := cmd_data;
                    v.clk_count := 0;
                    v.cs := '0';
                    v.state := SEND_INST;
                end if;

            when SEND_INST =>
                -- Shift MOSI on CPHA edge
                if ((CPHA = '0' and sclk_falling) or (CPHA = '1' and sclk_rising)) then
                    v.mosi := v.instr_shift(v.instr_shift'high);
                    v.instr_shift := v.instr_shift(v.instr_shift'high-1 downto 0) & '0';
                end if;

                -- Increment bit count on sampling edge
                if ((CPHA = '0' and sclk_rising) or (CPHA = '1' and sclk_falling)) then
                    v.bit_count := r.bit_count + 1;
                    if v.bit_count >= 2*DATA_WIDTH then
                        v.bit_count := 0;
                        if r.write_flag = '1' then
                            v.state := SEND_DATA;
                        else
                            v.data_out := (others => '0');
                            v.state := READ_DATA;
                        end if;
                    end if;
                end if;

            when SEND_DATA =>
                if ((CPHA = '0' and sclk_falling) or (CPHA = '1' and sclk_rising)) then
                    v.mosi := v.data_shift(v.data_shift'high);
                    v.data_shift := v.data_shift(v.data_shift'high-1 downto 0) & '0';
                end if;

                if ((CPHA = '0' and sclk_rising) or (CPHA = '1' and sclk_falling)) then
                    v.data_count := r.data_count + 1;
                    if v.data_count >= DATA_WIDTH then
                        v.cs := '1';
                        v.mosi := '0';
                        v.state := IDLE;
                    end if;
                end if;

            when READ_DATA =>
                if ((CPHA = '0' and sclk_rising) or (CPHA = '1' and sclk_falling)) then
                    v.data_out := v.data_out(v.data_out'high-1 downto 0) & miso;
                    v.data_count := r.data_count + 1;
                    if v.data_count >= DATA_WIDTH then
                        v.valid_out := '1';
                        v.cs := '1';
                        v.state := IDLE;
                    end if;
                end if;

            when others =>
                v := RESET_R;
        end case;

        -- Assertion to prevent invalid states
        assert v.bit_count <= 2*DATA_WIDTH report "Bit count overflow" severity warning;
        assert v.data_count <= DATA_WIDTH report "Data count overflow" severity warning;

        r_next <= v;
    end process;

end Behavioral;
