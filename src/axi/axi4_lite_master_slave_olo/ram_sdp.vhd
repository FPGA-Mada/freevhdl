library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.math_utils.all;

entity ram_sdp is
  generic (
    Depth_g      : positive;
    Width_g      : positive;
    Add_Width_g  : positive
  );
  port (
    Clk         : in  std_logic;
    Rst         : in  std_logic;  -- Active high reset

    -- AXI-like user interface
    Wr_Addr     : in  std_logic_vector(Add_Width_g - 1 downto 0);
    Byte_En     : in  std_logic_vector(Width_g / 8 - 1 downto 0);
    Wr_Data     : in  std_logic_vector(Width_g - 1 downto 0);
    Wr_Ena      : in  std_logic;
    Rd_Ena      : in  std_logic;
    Rd_Addr     : in  std_logic_vector(Add_Width_g - 1 downto 0);
    Rd_Data     : out std_logic_vector(Width_g - 1 downto 0);
    Rb_valid    : out std_logic;

    -- PL interface (read-only)
    Rd_Data_PL  : out std_logic_vector(Width_g - 1 downto 0);
    Rd_Addr_PL  : in  std_logic_vector(Add_Width_g - 1 downto 0) := (others => '0');
    Rd_En_PL    : in  std_logic := '0';
    Rd_Valid_PL : out std_logic
  );
end ram_sdp;

architecture rtl of ram_sdp is

  constant ByteCount_c : integer := Width_g / 8;

  type ram_type is array (0 to Depth_g - 1) of std_logic_vector(Width_g - 1 downto 0);
  signal ram : ram_type := (others => (others => '0'));

begin

  --------------------------------------------------------------------
  -- AXI Port: Write and Read
  --------------------------------------------------------------------
  axi_access_proc: process(Clk)
    variable wr_idx       : integer;
    variable rd_idx_axi   : integer;
  begin
    if rising_edge(Clk) then
      if Rst = '1' then
        Rd_Data  <= (others => '0');
        Rb_valid <= '0';
      else
        wr_idx      := to_integer(unsigned(Wr_Addr(Wr_Addr'high downto 2)));
        rd_idx_axi  := to_integer(unsigned(Rd_Addr(Rd_Addr'high downto 2)));

        -- Write logic
        if Wr_Ena = '1' and wr_idx < 100 then
          for i in 0 to ByteCount_c - 1 loop
            if Byte_En(i) = '1' then
              ram(wr_idx)((i + 1) * 8 - 1 downto i * 8) <= Wr_Data((i + 1) * 8 - 1 downto i * 8);
            end if;
          end loop;
        end if;

        -- Read logic
        if Rd_Ena = '1' and rd_idx_axi < 100 then
          Rd_Data  <= ram(rd_idx_axi);
          Rb_valid <= '1';
        else
          Rd_Data  <= (others => '0');
          Rb_valid <= '0';
        end if;
      end if;
    end if;
  end process;

  --------------------------------------------------------------------
  -- PL Read Port (Read-only access)
  --------------------------------------------------------------------
  pl_read_proc: process(Clk)
    variable rd_idx_pl : integer;
  begin
    if rising_edge(Clk) then
      if Rst = '1' then
        Rd_Data_PL  <= (others => '0');
        Rd_Valid_PL <= '0';
      else
        rd_idx_pl := to_integer(unsigned(Rd_Addr_PL));
        if Rd_En_PL = '1' and rd_idx_pl < Depth_g then
          Rd_Data_PL  <= ram(rd_idx_pl);
          Rd_Valid_PL <= '1';
        else
          Rd_Data_PL  <= (others => '0');
          Rd_Valid_PL <= '0';
        end if;
      end if;
    end if;
  end process;

end rtl;
