-- File: math_utils.vhd
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package math_utils is
  function clog2(n : integer) return integer;
  function max_value(a, b : integer) return integer;
  function min_value(a, b : integer) return integer;
  function ispowerof2(a : integer) return boolean;
  function binarytogray(a : std_logic_vector) return std_logic_vector;
  function graytobinary (a : std_logic_vector) return std_logic_vector;
  function pow2 (a : integer) return integer;
end package;

package body math_utils is

   function pow2 (a : integer) return integer is 
	  begin 
		return 2**a;
   end function;

	function binarytogray(a : std_logic_vector) return std_logic_vector is
		variable res : std_logic_vector(a'range);
		begin
		res(a'high) := a(a'high);  -- MSB is same
		for i in a'high-1 downto a'low loop
			res(i) := a(i+1) xor a(i);
		end loop;
		return res;
	end function;
	
	function graytobinary(a : std_logic_vector) return std_logic_vector is
		variable res : std_logic_vector(a'range);
		begin
		res(a'high) := a(a'high);  -- MSB is same
		for i in a'high-1 downto a'low loop
			res(i) := res(i+1) xor a(i);
		end loop;
		return res;
	end function;

 
  function clog2(n : integer) return integer is
    variable res : integer := 0;
    variable val : integer := n - 1;
  begin
    while val > 0 loop
      val := val / 2;
      res := res + 1;
    end loop;
    return res;
  end function;

  function max_value(a, b : integer) return integer is 
  begin
    if (a > b) then
      return a;
    else
      return b;
    end if;
  end function;

  function min_value(a, b : integer) return integer is
  begin
    if (a < b) then
      return a;
    else 
      return b;
    end if;
  end function;

  function ispowerof2(a : integer) return boolean is
    variable a_uns : unsigned(31 downto 0);
    variable aminus1_uns : unsigned(31 downto 0);
  begin
    if a < 1 then
      return false;
    else
      a_uns := to_unsigned(a, 32);
      aminus1_uns := to_unsigned(a-1, 32);
      return (a_uns and aminus1_uns) = to_unsigned(0, 32);
    end if;
  end function;
end package body;
