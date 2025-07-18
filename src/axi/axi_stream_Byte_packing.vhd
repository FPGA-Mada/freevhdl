library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Byte_packing is
    generic (
        DATA_WIDTH_g    : integer := 8;
        NUMB_OUTPUT_g   : integer := 3
    );
    port (
        clk       : in  std_logic;  
        rst       : in  std_logic;

        -- Input stream
        s_valid   : in  std_logic; 
        s_ready   : out std_logic; 
        s_data    : in  std_logic_vector(DATA_WIDTH_g - 1 downto 0);

        -- Output stream
        m_valid   : out std_logic; 
        m_ready   : in  std_logic;
        m_data    : out std_logic_vector(NUMB_OUTPUT_g * DATA_WIDTH_g - 1 downto 0)
    );
end Byte_packing;

architecture Behavioral of Byte_packing is

    signal m_valid_s : std_logic := '0';

    type m_data_t is array (0 to NUMB_OUTPUT_g - 1) of std_logic_vector(DATA_WIDTH_g - 1 downto 0);
    signal m_data_s  : m_data_t := (others => (others => '0'));

    type byte_store_t is array (0 to NUMB_OUTPUT_g - 1) of std_logic_vector(DATA_WIDTH_g - 1 downto 0);
    signal byte_store : byte_store_t := (others => (others => '0'));

    signal index_pos : integer range 0 to NUMB_OUTPUT_g - 1 := 0;

begin

    -- Ready when we're not currently asserting valid, or the receiver has accepted the current word
    s_ready <= not m_valid_s or m_ready;
    m_valid <= m_valid_s;

    -- Output data mapping
    map_data_s : for i in 0 to NUMB_OUTPUT_g - 1 generate
        m_data(((i + 1) * DATA_WIDTH_g - 1) downto (i * DATA_WIDTH_g)) <= m_data_s(i);
    end generate;

    byte_pack_proc : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                m_valid_s  <= '0';
                m_data_s   <= (others => (others => '0'));
                byte_store <= (others => (others => '0'));
                index_pos  <= 0;

            else
                -- If current output has been accepted, clear valid flag
                if m_valid_s = '1' and m_ready = '1' then
                    m_valid_s <= '0';
                end if;

                -- If input is valid and we are ready, accept data
                if s_valid = '1' and s_ready = '1' then
                    byte_store(index_pos) <= s_data;

                    if index_pos = NUMB_OUTPUT_g - 1 then
                        -- All bytes collected, output word is ready
                        for i in 0 to NUMB_OUTPUT_g - 2 loop
                            m_data_s(i) <= byte_store(i);
                        end loop;
                        m_data_s(NUMB_OUTPUT_g - 1) <= s_data;

                        m_valid_s <= '1';
                        index_pos <= 0;
                    else
                        index_pos <= index_pos + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

end Behavioral;
