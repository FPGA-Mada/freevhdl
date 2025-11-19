library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.math_utils.all;

entity ram_to_axi is
    generic(
        DATA_WIDTH_g : positive := 32;
        MEMORY_DEPTH_g : positive := 32;
        NUMB_DATA_EXTRACTED_FROM_RAM_g : positive := 30
    );
    Port (
        clk : in std_logic;
        rst : in std_logic;
        start : in std_logic;
        -- Write interface to memory
        Wr_En   : in std_logic;
        Wr_Addr : in std_logic_vector (clog2(MEMORY_DEPTH_g)-1 downto 0);
        Wr_Data : in std_logic_vector(DATA_WIDTH_g-1 downto 0);
        -- AXI stream interface
        m_valid : out std_logic;
        m_ready : in std_logic;
        m_data  : out std_logic_vector(DATA_WIDTH_g-1 downto 0);
        m_last  : out std_logic
    );
end ram_to_axi;

architecture Behavioral of ram_to_axi is

    signal Rd_Addr : std_logic_vector(clog2(MEMORY_DEPTH_g)-1 downto 0);
    signal Rd_Data : std_logic_vector(DATA_WIDTH_g -1 downto 0);
    signal Rd_Valid : std_logic;

    -- state machine
    type state_t is (IDLE_st, Rd_MEM_st);

    -- Two-process record
    type TwoProcess_r is record
        -- memory read interface
        Rd_En   : std_logic;
        Rd_Addr : unsigned(clog2(MEMORY_DEPTH_g)-1 downto 0);
        -- streaming interface
        m_valid : std_logic;
        m_data  : std_logic_vector(DATA_WIDTH_g-1 downto 0);
        m_last  : std_logic;
        -- state machine
        state   : state_t;
        -- previous start
        start   : std_logic;
        -- counter number of data
        counter_data_to_send : unsigned (clog2(NUMB_DATA_EXTRACTED_FROM_RAM_g)-1 downto 0);
    end record;

    signal r, r_next : TwoProcess_r;

begin
    -- output assignments
    m_valid <= r.m_valid;
    m_data  <= r.m_data;
    m_last  <= r.m_last;

    -- sequential process
    seq_proc: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                -- reset all signals
                r.Rd_En   <= '0';
                r.Rd_Addr <= (others => '0');
                r.m_valid <= '0';
                r.m_data  <= (others => '0');
                r.m_last  <= '0';
                r.state   <= IDLE_st;
                r.start   <= '0';
                r.counter_data_to_send <= (others => '0');
            else
                r <= r_next;
            end if;
        end if;
    end process seq_proc;

    -- combinational process
    comb_proc: process(all)
        variable v        : TwoProcess_r;
        variable tx_start : std_logic;
    begin
        -- default: copy current state
        v := r;

        -- defaults
        v.Rd_En   := '0';

        -- rising edge detection of start
        tx_start := '1' when start = '1' and r.start = '0' else '0';
        v.start := start;

        -- deassert m_valid and m_last only after handshake
        if (r.m_valid = '1' and m_ready = '1')then
            v.m_valid := '0';
            if (r.m_last = '1') then
                v.m_last := '0';
            end if;
        end if;
        
        -- state machine
        case r.state is
            when IDLE_st =>
                if tx_start = '1' and m_ready = '1' then
                    v.state   := Rd_MEM_st;
                    v.Rd_Addr := (others => '0');
                    v.Rd_En   := '1';
                end if;

            when Rd_MEM_st =>
                if m_ready = '1' then
                    if r.Rd_Addr <= NUMB_DATA_EXTRACTED_FROM_RAM_g - 2 then
                        v.Rd_Addr := r.Rd_Addr + 1;
                        v.Rd_En   := '1';
                        v.counter_data_to_send := (others => '0');
                    end if;
                end if;

                if Rd_Valid = '1' then
                    v.counter_data_to_send := r.counter_data_to_send + 1;
                    v.m_valid := '1';
                    v.m_data  := Rd_Data;
                    if r.counter_data_to_send = NUMB_DATA_EXTRACTED_FROM_RAM_g - 1 then
                        v.m_last := '1';
                        v.state  := IDLE_st;
                    end if;
                end if;
        end case;

        -- assign next state
        r_next <= v;
    end process comb_proc;

    -- RAM instantiation
    Rd_Addr <= std_logic_vector(r.Rd_Addr);

    u_ram_sp : entity work.ram_sp_valid_out
        generic map (
            DEPTH => MEMORY_DEPTH_g,
            WIDTH => DATA_WIDTH_g
        )
        port map (
            clk      => clk,
            Rd_En    => r.Rd_En,
            Rd_Addr  => Rd_Addr,
            Rd_Data  => Rd_Data,
            Rd_Valid => Rd_Valid,
            Wr_En    => Wr_En,
            Wr_Addr  => Wr_Addr,
            Wr_Data  => Wr_Data
        );

end Behavioral;