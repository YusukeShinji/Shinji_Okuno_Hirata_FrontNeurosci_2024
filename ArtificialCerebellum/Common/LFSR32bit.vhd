--------------------------------------------------------------------------------
-- BSD 3-Clause License
-- Copyright (c) 2024, Hirotsugu Okuno
-- Copyright (c) 2024, Yusuke Shinji
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity LFSR32bit is
Port (
	CLK : in  STD_LOGIC;
	RST : in  STD_LOGIC;
  ENA : in  STD_LOGIC;
  -- Input --
  INIT : in  STD_LOGIC_VECTOR (31 downto 0);
  -- Output --
  LFSR : out STD_LOGIC_VECTOR (31 downto 0)
);
end LFSR32bit;

architecture Behavioral of LFSR32bit is
	signal LFSR0   : std_logic_vector(31 downto 0) := (others=>'0');
	signal NewBit0 : std_logic := '0';

begin
--- LFSR ---------------------------------------------------------------------
	NewBit0 <= LFSR0(31) xor LFSR0(30) xor LFSR0(29) xor LFSR0(9);

	process(CLK,RST) begin
		if(RST='1') then
			LFSR0 <= INIT;
		elsif(CLK'event and CLK = '1') then
			if(ENA='1') then
				LFSR0 <= (LFSR0(30 downto 0) & NewBit0) - 1;
					-- LFSR = 0 to (2^31)-1
			end if;
		end if;
	end process;
-------------------------------------------------------------------------------

--- Output --------------------------------------------------------------------
  LFSR <= LFSR0;
-------------------------------------------------------------------------------

end Behavioral;
