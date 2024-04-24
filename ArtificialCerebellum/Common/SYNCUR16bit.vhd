-------------------------------------------------------------------------------
-- Conductance Based Synapse Model
--
-- BSD 3-Clause License
-- Copyright (c) 2024, Yusuke Shinji
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_SIGNED.all;

entity SYNCUR16bit is
Port (
	CLK : in  STD_LOGIC;
	RST : in  STD_LOGIC;
	VALID_I : in  STD_LOGIC;
	VALID_O : out STD_LOGIC;
	-- Constant --
	v_rev     : in  STD_LOGIC_VECTOR(15 downto 0); -- 16bit(sing1, int7, dec8)
	-- Input --
	g_syn	    : in  STD_LOGIC_VECTOR(15 downto 0); -- 16bit(sing1, int1, dec14)
	v_mb_old  : in  STD_LOGIC_VECTOR(15 downto 0); -- 16bit(sing1, int7, dec8)
	-- Output --
	i_syn     : out  STD_LOGIC_VECTOR(15 downto 0) -- 16bit(sing1, int7, dec8)
);
end SYNCUR16bit;

architecture Behavioral of SYNCUR16bit is
	-- Pipeline Register --
	signal VALID_REG0_DIFF	: STD_LOGIC;
	signal VALID_REG1_MLT	: STD_LOGIC;
	signal VALID_REG2_RND	: STD_LOGIC;

	-- Variable --
	signal v_diff      : STD_LOGIC_VECTOR(15 downto 0);
	signal g_syn_delay : STD_LOGIC_VECTOR(15 downto 0);
	signal i_syn_one   : STD_LOGIC_VECTOR(31 downto 0);
	signal i_syn_round : STD_LOGIC_VECTOR(15 downto 0);

	COMPONENT MULT_16_16
	PORT (
		clk : IN STD_LOGIC;
		a : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		b : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		ce : IN STD_LOGIC;
		p : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
	);
	END COMPONENT;

begin
--- Valid  protocol -----------------------------------------------------------
VALID_REG0_DIFF <= '1' when VALID_I='1' else
								 '0';

process(CLK, RST) begin
	if RST='1' then
		VALID_REG1_MLT <= '0';
	elsif(CLK'event and CLK = '1') then
		if VALID_REG0_DIFF='1' then
			VALID_REG1_MLT <= '1';
		else
			VALID_REG1_MLT <= '0';
		end if;
	end if;
end process;

process(CLK, RST) begin
	if RST='1' then
		VALID_REG2_RND <= '0';
	elsif(CLK'event and CLK = '1') then
		if VALID_REG1_MLT='1' then
			VALID_REG2_RND <= '1';
		else
			VALID_REG2_RND <= '0';
		end if;
	end if;
end process;
-------------------------------------------------------------------------------

--- Difference from reversal membrane potential -------------------------------
	v_diff_process: process(CLK, RST) begin
		if RST='1' then
			v_diff <= (others=>'0');
		elsif rising_edge(CLK) then
			if VALID_REG0_DIFF='1' then
				v_diff <= v_rev - v_mb_old;
			else
				v_diff <= (others=>'0');
			end if;
		end if;
	end process;

	-- Delay
	g_syn_delay_process: process(CLK, RST) begin
		if RST='1' then
			g_syn_delay <= (others=>'0');
		elsif rising_edge(CLK) then
			if VALID_REG0_DIFF='1' then
				g_syn_delay <=	g_syn;
			else
				g_syn_delay <= (others=>'0');
			end if;
		end if;
	end process;
-------------------------------------------------------------------------------

--- One of i_syn --------------------------------------------------------------
	MULT_16_16_COMP : MULT_16_16
	PORT MAP (
		clk => clk,
		a => v_diff,          -- 16bit(sing1, int7, dec8)
		b => g_syn_delay,     -- 16bit(sing1, int9, dec6)
		ce => VALID_REG1_MLT,
		p => i_syn_one        -- 32bit(sing1, int17, dec14)
	);
-------------------------------------------------------------------------------

--- Rounding ------------------------------------------------------------------
	i_syn_round_process: process(CLK, RST) begin
		if RST='1' then
			i_syn_round <= (others=>'0');
		elsif rising_edge(CLK) then
			if VALID_REG2_RND='1' then
				i_syn_round <= i_syn_one(25 downto 10) + i_syn_one(13); -- 16bit(sing1, int11, dec4)
				--i_syn_round <= i_syn_one(29 downto 14) + i_syn_one(13); -- 16bit(sing1, int15, dec0)
				--i_syn_round <= i_syn_one(23 downto 8) + i_syn_one(7); -- 16bit(sing1, int7, dec8)
			else
				i_syn_round <= (others=>'0');
			end if;
		end if;
	end process;
-------------------------------------------------------------------------------

--- Output --------------------------------------------------------------------
	process(CLK, RST) begin
		if RST='1' then
			VALID_O <= '0';
		elsif(CLK'event and CLK = '1') then
			if VALID_REG2_RND='1' then
				VALID_O <= '1';
			else
				VALID_O <= '0';
			end if;
		end if;
	end process;

	i_syn	<= i_syn_round;
-------------------------------------------------------------------------------
end Behavioral;
