--------------------------------------------------------------------------------
-- BSD 3-Clause License
-- Copyright (c) 2024, Yusuke Shinji
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity FF_t_spk_BkC is
Port (
  CLK : in  STD_LOGIC;
  RST : in  STD_LOGIC;
  hem : in  STD_LOGIC;
  WRITE1 : in  STD_LOGIC_VECTOR(1 downto 0);
  DOUT1 : out STD_LOGIC_VECTOR(24 downto 0)
);
end FF_t_spk_BkC;

architecture Behavioral of FF_t_spk_BkC is
	signal W_ADDR : STD_LOGIC_VECTOR(4 downto 0) := (others=>'0');
  signal DATA_L : STD_LOGIC_VECTOR(24 downto 0) := (others=>'0');
  signal DATA_R : STD_LOGIC_VECTOR(24 downto 0) := (others=>'0');

begin
---- Write-in control -------------------------------------------------------
	-- Address--
	process(CLK, RST) begin
		if RST='1' then
			W_ADDR <= (others=>'0');
		elsif rising_edge(CLK) then
			if WRITE1(0)='1' then
				W_ADDR <= W_ADDR +1;
			end if;
		end if;
	end process;
-------------------------------------------------------------------------------

--- Latch ---------------------------------------------------------------------
	process(CLK) begin
		if rising_edge(CLK) then
			if WRITE1(0)='1' then
				if hem='0' then
					DATA_L( to_integer(unsigned(W_ADDR)) ) <= WRITE1(1);
				end if;
			end if;
		end if;
	end process;

	process(CLK) begin
		if rising_edge(CLK) then
			if WRITE1(0)='1' then
				if hem='1' then
					DATA_R( to_integer(unsigned(W_ADDR)) ) <= WRITE1(1);
				end if;
			end if;
		end if;
	end process;
-------------------------------------------------------------------------------

--- Output --------------------------------------------------------------------
	DOUT1 <= DATA_L when hem='0' else
					 DATA_R when hem='1' else
					 (others=>'0');
-------------------------------------------------------------------------------
end Behavioral;
