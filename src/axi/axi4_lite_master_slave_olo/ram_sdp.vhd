library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.math_utils.all;  -- Assumed to contain 'clog2' function

-- Entity declaration for single-port dual-access RAM
entity ram_sdp is
  generic (
    Depth_g      : positive;  -- Number of memory words
    Width_g      : positive;  -- Width of each memory word in bits
    Add_Width_g  : positive   -- Width of address bus
  );
  port (
    Clk         : in  std_logic;  -- Clock signal
    Rst         : in  std_logic;  -- Active high reset

    -- AXI-like write and read interface
    Wr_Addr     : in  std_logic_vector(Add_Width_g - 1 downto 0);  -- Write address
    Byte_En     : in  std_logic_vector(Width_g / 8 - 1 downto 0);  -- Byte enable per 8-bit segment
    Wr_Data     : in  std_logic_vector(Width_g - 1 downto 0);      -- Write data
    Wr_Ena      : in  std_logic;                                   -- Write enable
    Rd_Ena      : in  std_logic;                                   -- Read enable
    Rd_Addr     : in  std_logic_vector(Add_Width_g - 1 downto 0);  -- Read address
    Rd_Data     : out std_logic_vector(Width_g - 1 downto 0);      -- Read data output
    Rb_valid    : out std_logic;                                   -- Read data valid

    -- Read-only port for external logic (PL interface)
    Rd_Data_PL  : out std_logic_vector(Width_g - 1 downto 0);      -- PL read data output
    Rd_Addr_PL  : in  std_logic_vector(Add_Width_g - 1 downto 0) := (others => '0');  -- PL read address
    Rd_En_PL    : in  std_logic := '0';                            -- PL read enable
    Rd_Valid_PL : out std_logic                                    -- PL read data valid
  );
end ram_sdp;

architecture rtl of ram_sdp is

  -- Byte count in each word (Width_g must be divisible by 8)
  constant ByteCount_c : integer := Width_g / 8;

  -- Starting bit index for word-aligned addressing (log2 of byte count)
  constant start_wr_index : integer := clog2(ByteCount_c);

  -- Define the RAM as an array of words
  type ram_type is array (0 to Depth_g - 1) of std_logic_vector(Width_g - 1 downto 0);
  signal ram : ram_type := (others => (others => '0'));  -- Initialize RAM with zeros

begin

	assert Width_g mod 8 = 0 
		report "value of width_g must be divided by 8"
		severity failure;

  --------------------------------------------------------------------
  -- AXI Port: Synchronous Write and Read Access
  --------------------------------------------------------------------
  axi_access_proc: process(Clk)
    variable wr_idx       : integer;  -- Write word index
    variable rd_idx_axi   : integer;  -- Read word index (AXI side)
  begin
    if rising_edge(Clk) then
      if Rst = '1' then
        -- Reset output values
        Rd_Data  <= (others => '0');
        Rb_valid <= '0';
      else
        -- Calculate word-aligned addresses
        wr_idx     := to_integer(unsigned(Wr_Addr(Wr_Addr'high downto start_wr_index)));
        rd_idx_axi := to_integer(unsigned(Rd_Addr(Rd_Addr'high downto start_wr_index)));

        -- Default values
        Rd_Data  <= (others => '0');
        Rb_valid <= '0';

        -- Byte-wise write logic if enabled and index is in range
        if Wr_Ena = '1' and wr_idx < Depth_g then
          for i in 0 to ByteCount_c - 1 loop
            if Byte_En(i) = '1' then
              ram(wr_idx)((i + 1) * 8 - 1 downto i * 8) <= Wr_Data((i + 1) * 8 - 1 downto i * 8);
            end if;
          end loop;
        end if;

        -- Read logic if enabled and index is in range
        if Rd_Ena = '1' and rd_idx_axi < Depth_g then
          Rd_Data  <= ram(rd_idx_axi);
          Rb_valid <= '1';
        end if;
      end if;
    end if;
  end process;

  --------------------------------------------------------------------
  -- PL Read Port: Independent Read Access for PL Logic
  --------------------------------------------------------------------
  pl_read_proc: process(Clk)
    variable rd_idx_pl : integer;  -- Read word index for PL port
  begin
    if rising_edge(Clk) then
      if Rst = '1' then
        -- Reset PL output values
        Rd_Data_PL  <= (others => '0');
        Rd_Valid_PL <= '0';
      else
        -- Convert PL read address to index
        rd_idx_pl := to_integer(unsigned(Rd_Addr_PL));

        -- Default values
        Rd_Data_PL  <= (others => '0');
        Rd_Valid_PL <= '0';

        -- PL read access if enabled and in range
        if Rd_En_PL = '1' and rd_idx_pl < Depth_g then
          Rd_Data_PL  <= ram(rd_idx_pl);
          Rd_Valid_PL <= '1';
        end if;
      end if;
    end if;
  end process;

end rtl;
