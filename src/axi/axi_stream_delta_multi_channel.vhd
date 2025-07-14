library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity delta_multi_channel is
  generic (
    DATA_WIDTH : positive := 8;
    CHANNELS     : positive := 3;
    OPERATION_MODE : string := "INV"; -- INV : calculate difference, else calculate sum
    IMAGE_TYPE   : string   := "MULTICHANNEL"  -- Options: "GRAY", "MULTICHANNEL"
  );
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;

    -- AXI Stream Slave
    s_valid  : in  std_logic;
    s_ready  : out std_logic;
    s_data   : in  std_logic_vector(DATA_WIDTH - 1 downto 0);

    -- AXI Stream Master
    m_valid  : out std_logic;
    m_ready  : in  std_logic;
    m_data   : out std_logic_vector(DATA_WIDTH - 1 downto 0)
  );
end delta_multi_channel;

architecture Behavioral of delta_multi_channel is

  -- Output registers
  signal m_data_reg  : std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
  signal m_valid_reg : std_logic := '0';

  -- GRAY mode
  signal prev_pixel  : std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
  signal first_gray  : std_logic := '1';

  -- RGB mode
  type pixel_array_t is array (0 to CHANNELS - 1) of std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal pixel_history  : pixel_array_t := (others => (others => '0'));
  signal counter_pixel  : integer range 0 to CHANNELS -1 := 0;
  signal first_rgb      : std_logic := '1';

begin

  --*** Output port assignments
  m_data  <= m_data_reg;
  m_valid <= m_valid_reg;

  --*** Ready to accept input if output is not valid or downstream ready
  s_ready <= not m_valid_reg or m_ready;

  --*** Configuration checks
  assert (DATA_WIDTH mod 8) = 0
    report "DATA_WIDTH_g must be divisible by 8"
    severity failure;

  assert (IMAGE_TYPE = "GRAY" or IMAGE_TYPE = "MULTICHANNEL")
    report "Unsupported IMAGE_TYPE. Use 'GRAY' or 'MULTICHANNEL'"
    severity failure;
  
  assert CHANNELS > 0
    report "CHANNELS must be positive"
    severity failure;

  -----------------------------------------------------------------------------
  -- GRAY Mode Logic
  -----------------------------------------------------------------------------
  GRAY_OPERATION: if IMAGE_TYPE = "GRAY" generate
    process(clk)
    begin
      if rising_edge(clk) then
        if rst = '1' then
          prev_pixel  <= (others => '0');
          first_gray  <= '1';
          m_data_reg  <= (others => '0');
          m_valid_reg <= '0';
        else
          if m_valid_reg = '1' and m_ready = '1' then
            m_valid_reg <= '0';
          end if;

          if s_valid = '1' and s_ready = '1' then
            if first_gray = '1' then
              m_data_reg <= s_data;
              first_gray <= '0';
            else
              if OPERATION_MODE = "INV" then
                  m_data_reg <= std_logic_vector(unsigned(s_data) - unsigned(prev_pixel));
              else
                  m_data_reg <= std_logic_vector(unsigned(s_data) + unsigned(prev_pixel));  
              end if;
            end if;
            prev_pixel <= s_data;
            m_valid_reg <= '1';
          end if;
        end if;
      end if;
    end process;
  end generate;

  -----------------------------------------------------------------------------
  -- MULTICHANNEL Mode Logic
  -----------------------------------------------------------------------------
  RGB_OPERATION: if IMAGE_TYPE = "MULTICHANNEL" generate
    process(clk)
    begin
      if rising_edge(clk) then
        if rst = '1' then
          pixel_history <= (others => (others => '0'));
          counter_pixel <= 0;
          first_rgb     <= '1';
          m_data_reg    <= (others => '0');
          m_valid_reg   <= '0';
        else
          if m_valid_reg = '1' and m_ready = '1' then
            m_valid_reg <= '0';
            m_data_reg <= (others => '0');
          end if;

          if s_valid = '1' and s_ready = '1' then
            if first_rgb = '1' then
              pixel_history(counter_pixel) <= s_data;
              m_data_reg <= s_data;

              if counter_pixel = CHANNELS -1 then
                first_rgb <= '0';
              end if;
            else
              if (OPERATION_MODE = "INV") then
                  m_data_reg <= std_logic_vector(unsigned(s_data) - unsigned(pixel_history(counter_pixel)));
              else
                  m_data_reg <= std_logic_vector(unsigned(s_data) + unsigned(pixel_history(counter_pixel)));
              end if;
              pixel_history(counter_pixel) <= s_data;
            end if;

            if counter_pixel = CHANNELS -1 then
              counter_pixel <= 0;
            else
              counter_pixel <= counter_pixel + 1;
            end if;

            m_valid_reg <= '1';
          end if;
        end if;
      end if;
    end process;
  end generate;

end Behavioral;
