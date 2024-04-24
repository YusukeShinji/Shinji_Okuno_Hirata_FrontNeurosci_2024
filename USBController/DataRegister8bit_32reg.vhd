--------------------------------------------------------------------------------
-- BSD 3-Clause License
-- Copyright (c) 2024, Hirotsugu Okuno
-- Copyright (c) 2024, Yusuke Shinji
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use ieee.std_logic_misc.all;

entity DataRegister8bit_32reg is
    Port (
		CLK 	: in	STD_LOGIC;
		RST 	: in	STD_LOGIC;
--		TRG   : in  STD_LOGIC;
		WRITE	: in	STD_LOGIC_VECTOR (28 downto 0);
		RO_00	: out	STD_LOGIC_VECTOR (31 downto 0);
		RO_01	: out	STD_LOGIC_VECTOR (31 downto 0);
		RO_02	: out	STD_LOGIC_VECTOR (31 downto 0);
		RO_03	: out	STD_LOGIC_VECTOR (31 downto 0);
		RO_04	: out	STD_LOGIC_VECTOR (31 downto 0);
		RO_05	: out	STD_LOGIC_VECTOR (31 downto 0);
		RO_06	: out	STD_LOGIC_VECTOR (31 downto 0);
		RO_07	: out	STD_LOGIC_VECTOR (31 downto 0);
		RO_08	: out	STD_LOGIC_VECTOR (31 downto 0);
		RO_09	: out	STD_LOGIC_VECTOR (31 downto 0);
		RO_10	: out	STD_LOGIC_VECTOR (31 downto 0);
		RO_11	: out	STD_LOGIC_VECTOR (31 downto 0);
		RO_12	: out	STD_LOGIC_VECTOR (31 downto 0);
		RO_13	: out	STD_LOGIC_VECTOR (31 downto 0)
	);
end DataRegister8bit_32reg;

architecture Behavioral of DataRegister8bit_32reg is
  type REG_ARRAY is array (0 to 55) of std_logic_vector(7 downto 0);
  signal REG : REG_ARRAY;
  constant zeros : std_logic_vector(7 downto 0) := (others=>'0');

begin
---- Output -------------------------------------------------------------------
	RO_00 <= REG( 3) & REG( 2) & REG( 1) & REG( 0);
	RO_01 <= REG( 7) & REG( 6) & REG( 5) & REG( 4);
	RO_02 <= REG(11) & REG(10) & REG( 9) & REG( 8);
	RO_03 <= REG(15) & REG(14) & REG(13) & REG(12);
	RO_04 <= REG(19) & REG(18) & REG(17) & REG(16);
	RO_05 <= REG(23) & REG(22) & REG(21) & REG(20);
	RO_06 <= REG(27) & REG(26) & REG(25) & REG(24);
	RO_07 <= REG(31) & REG(30) & REG(29) & REG(28);
	RO_08 <= REG(35) & REG(34) & REG(33) & REG(32);
	RO_09 <= REG(39) & REG(38) & REG(37) & REG(36);
	RO_10 <= REG(43) & REG(42) & REG(41) & REG(40);
	RO_11 <= REG(47) & REG(46) & REG(45) & REG(44);
	RO_12 <= REG(51) & REG(50) & REG(49) & REG(48);
	RO_13 <= REG(55) & REG(54) & REG(53) & REG(52);
-------------------------------------------------------------------------------

---- Register -----------------------------------------------------------------
	G1: for I in 0 to 55 generate
		process(CLK,RST) begin
			if(RST = '1') then
				REG(I) <= (others => '0');
			elsif(CLK'event and CLK = '1') then
				if(WRITE(3)= '1') and (WRITE(20 downto 4) = I) then
					REG(I) <= WRITE(28 downto 21);
				end if;
			end if;
		end process;
	end generate;
-------------------------------------------------------------------------------

end Behavioral;
