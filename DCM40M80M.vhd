--------------------------------------------------------------------------------
-- BSD 3-Clause License
-- Copyright (c) 2024, Hirotsugu Okuno
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity DCM40M80M is
	Port(
		CLK_IN		: in	std_logic;
		RST			: in	std_logic;
		CLK40M		: out	std_logic;
		CLK80M		: out	std_logic
	);
end DCM40M80M;

architecture Behavioral of DCM40M80M is

component DCM40M80M_SP6
	port(
	  CLK_IN1    : in     std_logic;
	  CLK_OUT1   : out    std_logic;
	  CLK_OUT2   : out    std_logic;
	  RESET      : in     std_logic
	 );
end component;

begin

U0 : DCM40M80M_SP6
	port map(
		CLK_IN1            => CLK_IN,
		CLK_OUT1           => CLK40M,
		CLK_OUT2           => CLK80M,
		RESET              => RST
	);

end Behavioral;
