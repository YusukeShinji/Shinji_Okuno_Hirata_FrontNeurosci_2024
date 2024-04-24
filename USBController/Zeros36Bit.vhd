--------------------------------------------------------------------------------
-- BSD 3-Clause License
-- Copyright (c) 2024, Hirotsugu Okuno
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

--  Uncomment the following lines to use the declarations that are
--  provided for instantiating Xilinx primitive components.
--library UNISIM;
--use UNISIM.VComponents.all;

entity Zeros36Bit is
	port(
		VALUE		:out	std_logic_vector(35 downto 0)
		);
end Zeros36Bit;

architecture Behavioral of Zeros36Bit is

begin
	VALUE <= CONV_STD_LOGIC_VECTOR(0,36);
end Behavioral;
