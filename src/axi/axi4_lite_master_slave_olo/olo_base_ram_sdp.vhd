library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity olo_base_ram_sdp is
  generic (
    Depth_g         : positive;
    Width_g         : positive;
    RamStyle_g      : string := "auto";
    RamBehavior_g   : string := "RBW"
  );
  port (
    Clk       : in  std_logic;
    Wr_Addr   : in  std_logic_vector;
    Wr_Data   : in  std_logic_vector(Width_g - 1 downto 0);
    Wr_Ena    : in  std_logic;
    Rd_Addr   : in  std_logic_vector;
    Rd_Data   : out std_logic_vector(Width_g - 1 downto 0)
  );
end olo_base_ram_sdp;

architecture rtl of olo_base_ram_sdp is

  -- Calculate log2 ceiling
  function clog2(n : natural) return natural is
    variable result : natural := 0;
    variable v : natural := n - 1;
  begin
    while v > 0 loop
      v := v / 2;
      result := result + 1;
    end loop;
    return result;
  end;

  constant AddrWidth_c : natural := clog2(Depth_g);

  -- Memory array
  type ram_type is array (0 to Depth_g - 1) of std_logic_vector(Width_g - 1 downto 0);
  signal ram : ram_type := (others => (others => '0'));

  -- RAM style attribute
  attribute ram_style : string;
  attribute ram_style of ram : signal is RamStyle_g;

begin

  -- RAM write and synchronous read
  process(Clk)
    variable wr_idx : integer;
    variable rd_idx : integer;
  begin
    if rising_edge(Clk) then
      wr_idx := to_integer(unsigned(Wr_Addr));
      rd_idx := to_integer(unsigned(Rd_Addr));

      if Wr_Ena = '1' then
        if wr_idx >= 0 and wr_idx < Depth_g then
          ram(wr_idx) <= Wr_Data;
        end if;
      end if;

      if rd_idx >= 0 and rd_idx < Depth_g then
        Rd_Data <= ram(rd_idx);
      else
        Rd_Data <= (others => '0');
      end if;
    end if;
  end process;

end rtl;
