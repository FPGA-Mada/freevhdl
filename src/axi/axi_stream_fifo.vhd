library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.math_utils.all;

entity axi_stream_fifo is
    generic (
        FIFO_DEPTH : integer := 32;
        DATA_WIDTH : integer := 32
    );
    port (
        clk     : in  std_logic;
        rst     : in  std_logic;

        -- Stream input
        s_valid : in  std_logic;
        s_data  : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
        s_ready : out std_logic;

        -- Stream output
        m_valid : out std_logic;
        m_data  : out std_logic_vector(DATA_WIDTH - 1 downto 0);
        m_ready : in  std_logic
    );
end axi_stream_fifo;

architecture Behavioral of axi_stream_fifo is

    -- FIFO memory (only data, no last)
    type fifo_type is array (0 to FIFO_DEPTH - 1) of std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal fifo_mem : fifo_type := (others => (others => '0'));

    -- Status flags
    signal fifo_full  : std_logic := '0';
    signal fifo_empty : std_logic := '1';

    -- Pointers and counters
    signal wr_indx : unsigned(clog2(FIFO_DEPTH) - 1 downto 0) := (others => '0');
    signal rd_indx : unsigned(clog2(FIFO_DEPTH) - 1 downto 0) := (others => '0');
    signal count   : unsigned(clog2(FIFO_DEPTH) downto 0)     := (others => '0');

    -- Control
    signal do_write : std_logic;
    signal do_read  : std_logic;
    signal rw_state : std_logic_vector(1 downto 0);
begin

    -- FIFO status
    fifo_full  <= '1' when (to_integer(count) = FIFO_DEPTH) else '0';
    fifo_empty <= '1' when (to_integer(count) = 0)          else '0';

    -- Handshake logic
    s_ready <= not fifo_full;
    do_write <= '1' when (s_valid = '1' and s_ready = '1') else '0';
    do_read  <= '1' when (m_valid = '1' and m_ready = '1') else '0';
    rw_state <= do_write & do_read;

    -- Output signals
    m_valid <= not fifo_empty;
    m_data  <=  fifo_mem(to_integer(rd_indx));

    -- Main FIFO process
    fifo_proc : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                count      <= (others => '0');
                wr_indx    <= (others => '0');
                rd_indx    <= (others => '0');
                fifo_mem   <= (others => (others => '0'));
            else
                -- Write operation
                if do_write = '1' then
                    fifo_mem(to_integer(wr_indx)) <= s_data;
                    wr_indx <= to_unsigned((to_integer(wr_indx) + 1) mod FIFO_DEPTH, wr_indx'length);
                end if;

                -- Read operation
                if do_read = '1' then
                    rd_indx <= to_unsigned((to_integer(rd_indx) + 1) mod FIFO_DEPTH, rd_indx'length);
                end if;

                -- Update FIFO count
                case rw_state is
                    when "10" => count <= count + 1;  -- Write only
                    when "01" => count <= count - 1;  -- Read only
                    when others => null;              -- Both or neither
                end case;
            end if;
        end if;
    end process;

end Behavioral;
