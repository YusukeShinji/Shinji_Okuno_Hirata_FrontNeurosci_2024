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

entity SYNCND16bit is
Port(
	CLK : in STD_LOGIC;
	RST : in STD_LOGIC;
	VALID_I : in  STD_LOGIC;
	VALID_O : out STD_LOGIC;
	VALID_O_PRE : OUT STD_LOGIC;
	-- Constant --
	INIT      : in  STD_LOGIC_VECTOR(31 downto 0);
	tau_syn   : in  STD_LOGIC_VECTOR(31 downto 0); -- 32bit(sign1, int1, dec30)
	-- Inputs --
	w_sum	    : in  STD_LOGIC_VECTOR(15 downto 0); -- 16bit(sign1, int1, dec14)
	g_syn_old : in  STD_LOGIC_VECTOR(15 downto 0); --  8bit(sign1, int1, dec14)
	-- Outputs --
	g_syn_new : out STD_LOGIC_VECTOR(15 downto 0)  --  8bit(sign1, int1, dec14)
);
end SYNCND16bit;

architecture Behavioral of SYNCND16bit is
	-- Pipeline Register --
	signal VALID_REG0_DIFF : STD_LOGIC;
	signal VALID_REG1_MLT	: STD_LOGIC;
	signal VALID_REG2_ADD	: STD_LOGIC;
	signal VALID_REG3_RND	: STD_LOGIC;

	-- Variable --
	signal g_syn_old_delay0 : STD_LOGIC_VECTOR(15 downto 0);
	signal g_syn_old_delay1 : STD_LOGIC_VECTOR(15 downto 0);
	signal g_syn_old_delay2 : STD_LOGIC_VECTOR(15 downto 0);

	signal w_sum_high       : STD_LOGIC_VECTOR(1 downto 0);
	signal w_sum_low        : STD_LOGIC_VECTOR(13 downto 0);
	signal w_sum_delay0     : STD_LOGIC_VECTOR(15 downto 0);

	signal g_gain           : STD_LOGIC_VECTOR(15 downto 0);
	signal g_leak           : STD_LOGIC_VECTOR(31 downto 0);
	signal g_in             : STD_LOGIC_VECTOR(31 downto 0);

	signal g_sum_all        : STD_LOGIC_VECTOR(31 downto 0);
	signal g_sum            : STD_LOGIC_VECTOR(15 downto 0);

	signal g_sum2           : STD_LOGIC_VECTOR(15 downto 0);
	signal g_rnd            : STD_LOGIC_VECTOR(15 downto 0);
--	signal logi_rnd_pls     : boolean;
--	signal logi_rnd_min     : boolean;

	constant one            : STD_LOGIC_VECTOR(15 downto 0) := (14=>'1', others=>'0');
	constant one_rnd        : STD_LOGIC_VECTOR(15 downto 0) := (0=>'1', others=>'0');

	COMPONENT MULT_32_16
	PORT (
		clk : IN STD_LOGIC;
		a : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
		b : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		ce : IN STD_LOGIC;
		p : OUT STD_LOGIC_VECTOR(47 DOWNTO 0)
	);
	END COMPONENT;

	COMPONENT MULT_16_16
	PORT (
		clk : IN STD_LOGIC;
		a : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		b : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		ce : IN STD_LOGIC;
		p : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
	);
	END COMPONENT;

	-- LFSR Random --
	signal rand : STD_LOGIC_VECTOR(31 downto 0);

	COMPONENT LFSR32bit
	PORT(
		CLK : IN  STD_LOGIC;
		RST : IN  STD_LOGIC;
		ENA : IN  STD_LOGIC;
		INIT : IN  STD_LOGIC_VECTOR(31 downto 0);
		LFSR : OUT STD_LOGIC_VECTOR(31 downto 0)
	);
	END COMPONENT;

begin
--- Valid  protocol -----------------------------------------------------------
  VALID_REG0_DIFF <= '1' when VALID_I='1' else
	                   '0';

  process(CLK, RST) begin
  	if RST='1' then
  		VALID_REG1_MLT <= '0';
  	elsif (CLK'event and CLK='1') then
			if VALID_REG0_DIFF='1' then
				VALID_REG1_MLT <= '1';
			else
				VALID_REG1_MLT <= '0';
			end if;
  	end if;
  end process;

  process(CLK, RST) begin
  	if RST='1' then
  		VALID_REG2_ADD <= '0';
  	elsif (CLK'event and CLK='1') then
			if VALID_REG1_MLT='1' then
				VALID_REG2_ADD <= '1';
			else
				VALID_REG2_ADD <= '0';
			end if;
		end if;
  end process;

	process(CLK, RST) begin
		if RST='1' then
			VALID_REG3_RND <= '0';
		elsif (CLK'event and CLK='1') then
			if VALID_REG2_ADD='1' then
				VALID_REG3_RND <= '1';
			else
				VALID_REG3_RND <= '0';
			end if;
		end if;
	end process;
-------------------------------------------------------------------------------

--- Difference ----------------------------------------------------------------
--	process(CLK, RST) begin
--		if RST='1' then
--			g_gain <= (others=>'0');
--		elsif (CLK'event and CLK='1') then
--			if VALID_REG0_DIFF='1' then
--				g_gain <= g_syn_old; -- one - g_syn_old;
--			else
--				g_gain <= (others=>'0');
--			end if;
--		end if;
--	end process;

	process(CLK, RST) begin
		if RST='1' then
			w_sum_delay0 <= (others=>'0');
		elsif (CLK'event and CLK='1') then
			if VALID_REG0_DIFF='1' then
				w_sum_delay0 <= w_sum;
			else
				w_sum_delay0 <= (others=>'0');
			end if;
		end if;
	end process;

	process(CLK, RST) begin
		if (CLK'event and CLK='1') then
			g_syn_old_delay0 <= g_syn_old;
		end if;
	end process;
-------------------------------------------------------------------------------

--- Multiplication	-----------------------------------------------------------
	MULT_16_16_leak_COMP : MULT_16_16
	PORT MAP (
		clk => clk,
		a => tau_syn(31 downto 16),
		b => g_syn_old_delay0,
		ce => VALID_REG1_MLT,
		p => g_leak   --  32bit(sign1, int9, dec22)
	);

--	MULT_16_16_input_COMP : MULT_16_16
--	PORT MAP (
--		clk => clk,
--		a => w_sum_delay0,
--		b => g_gain,
--		ce => VALID_REG1_MLT,
--		p => g_in     --  32bit(sign1, int15, dec16)
--	);
	w_sum_high <= (others=>w_sum_delay0(15));
	w_sum_low <= (others=>'0');
	process(CLK, RST) begin
		if RST='1' then
			g_in <= (others=>'0');
		elsif (CLK'event and CLK='1') then
			if VALID_REG1_MLT='1' then
				g_in <= w_sum_high & w_sum_delay0 & w_sum_low;
					--  32bit(sign1, int3, dec28)
			else
				g_in <= (others=>'0');
			end if;
		end if;
	end process;

	process(CLK, RST) begin
		if (CLK'event and CLK='1') then
			g_syn_old_delay1 <= g_syn_old_delay0;
		end if;
	end process;

	uut: LFSR32bit PORT MAP (
		CLK => CLK,
		RST => RST,
		ENA => VALID_REG1_MLT,
		INIT => INIT,
		LFSR => rand
	);
-------------------------------------------------------------------------------

--- Summation -----------------------------------------------------------------
	g_sum_all   <= g_leak + g_in;
		-- 32bit(sign1, int9, dec22)
	g_sum_process: process(CLK, RST) begin
		if RST='1' then
			g_sum <= (others=>'0');
		elsif (CLK'event and CLK='1') then
			if VALID_REG2_ADD='1' then
				g_sum <= g_sum_all(29 downto 14); -- 16bit(sign1, int3, dec12)
				-- g_sum <= g_sum_all(45 downto 30); -- 16bit(sign1, int7, dec8)
			end if;
		end if;
	end process;

	process(CLK, RST) begin
		if (CLK'event and CLK='1') then
			g_syn_old_delay2 <= g_syn_old_delay1;
		end if;
	end process;

	-- Randmized rounding --
	-- RR ver.2 (pre sum) --
	g_rnd_process: process(CLK, RST) begin
		if RST='1' then
			g_rnd <= (others=>'0');
		elsif rising_edge(CLK) then
			if VALID_REG2_ADD='1' then
				if (("0"&rand(13 downto 0)) < ("0"&g_sum_all(13 downto 0))) then
					g_rnd <= (0=>'1', others=>'0'); -- = 1
				else
					g_rnd <= (others=>'0');
				end if;
			else
				g_rnd <= (others=>'0');
			end if;
		end if;
	end process;

	-- RR ver.1 (parallel sum) --
--	logi_rnd_pls <= True when (("0"&rand(13 downto 0)) < ("0"&g_in_all(13 downto 0))) else False;
--	logi_rnd_min <= True when (("0"&rand(13 downto 0)) < ("0"&g_leak(13 downto 0))) else False;
--
--	g_rnd_process: process(CLK, RST) begin
--		if RST='1' then
--			g_rnd <= (others=>'0');
--		elsif rising_edge(CLK) then
--			if VALID_REG2_ADD='1' then
--				if (logi_rnd_pls) and (logi_rnd_min) then
--					g_rnd <= (1=>'1', others=>'0'); -- = 2
--				elsif (logi_rnd_pls) xor (logi_rnd_min) then
--					g_rnd <= (0=>'1', others=>'0'); -- = 1
--				else
--					g_rnd <= (others=>'0');         -- =  0
--				end if;
--			else
--				g_rnd <= (others=>'0');
--			end if;
--		end if;
--	end process;

	-- 4out5in rounding --
--	g_rnd_process: process(CLK, RST) begin
--		if RST='1' then
--			g_rnd <= (others=>'0');
--		elsif rising_edge(CLK) then
--			if VALID_REG2_ADD='1' then
--				g_rnd <= (0=>g_sum_all(13),others=>'0');
--			end if;
--		end if;
--	end process;
-------------------------------------------------------------------------------

--- Rounding ------------------------------------------------------------------
	g_sum2_process: process(CLK, RST) begin
		if RST='1' then
			g_sum2 <= (others=>'0');
		elsif rising_edge(CLK) then
			if VALID_REG3_RND='1' then
				g_sum2 <= g_sum + g_rnd + g_syn_old_delay2;
			end if;
		end if;
	end process;
-------------------------------------------------------------------------------

--- Output --------------------------------------------------------------------
	process(CLK, RST) begin
		if RST='1' then
			VALID_O <= '0';
		elsif (CLK'event and CLK='1') then
			if VALID_REG3_RND='1' then
				VALID_O <= '1';
			else
				VALID_O <= '0';
			end if;
		end if;
	end process;

	VALID_O_PRE <= VALID_REG3_RND;

	g_syn_new <= g_sum2;
-------------------------------------------------------------------------------
end Behavioral;
