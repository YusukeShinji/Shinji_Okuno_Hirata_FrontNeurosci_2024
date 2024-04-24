-------------------------------------------------------------------------------
-- BSD 3-Clause License
-- Copyright (c) 2024, Yusuke Shinji
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_SIGNED.all;

entity STDP_PkC_PF is
Port (
	CLK : in  STD_LOGIC;
	RST : in  STD_LOGIC;
	VALID_I : in  STD_LOGIC;
	VALID_O : out STD_LOGIC;
	-- constant --
	gum_LTD	: in  STD_LOGIC_VECTOR(31 downto 0);
	gum_LTP	: in  STD_LOGIC_VECTOR(31 downto 0);
	t_win		: in  STD_LOGIC_VECTOR(31 downto 0);
	INIT    : in  STD_LOGIC_VECTOR(31 downto 0);
	-- input --
	g_weight_grc_old : in  STD_LOGIC_VECTOR(15 downto 0);
	weight_old       : in  STD_LOGIC_VECTOR(15 downto 0);
	spk_grc          : in  STD_LOGIC;
	spk_cf           : in  STD_LOGIC;
	-- output --
	g_weight_grc_new : out STD_LOGIC_VECTOR(15 downto 0);
	weight_new       : out STD_LOGIC_VECTOR(15 downto 0)
);
end STDP_PkC_PF;

architecture Behavioral of STDP_PkC_PF is
	-- State Machine --
	signal VALID_REG0_MUL : STD_LOGIC;
	signal VALID_REG1_DIF : STD_LOGIC;
	signal VALID_REG2_MUL : STD_LOGIC;
	signal VALID_REG3_WIN : STD_LOGIC;
	signal VALID_REG4_ADD : STD_LOGIC;
	signal VALID_REG5_SAT : STD_LOGIC;

	signal RST_LFSR : STD_LOGIC := '1';

	-- Low-Path Filter --
	signal spkshift      : STD_LOGIC_VECTOR(15 downto 0);
	signal tau_spk       : STD_LOGIC_VECTOR(47 downto 0);
	signal g_spk         : STD_LOGIC_VECTOR(47 downto 0);

--	signal spkmean_add_all : STD_LOGIC_VECTOR(47 downto 0);
	signal spkmean_add     : STD_LOGIC_VECTOR(47 downto 0);

--	signal g_weight_old  : STD_LOGIC_VECTOR(31 downto 0);
	signal spkmean_rnd   : STD_LOGIC_VECTOR(15 downto 0);
	signal spkmean_new   : STD_LOGIC_VECTOR(31 downto 0);
	signal g_weight_new  : STD_LOGIC_VECTOR(15 downto 0);
	constant g_weight_max : STD_LOGIC_VECTOR(15 downto 0) := (14=>'1', others=>'0');

	-- Variable --
	signal weight_add_all : STD_LOGIC_VECTOR(31 downto 0);
	signal weight_rnd : STD_LOGIC_VECTOR(15 downto 0);
	signal weight_add : STD_LOGIC_VECTOR(15 downto 0);
	signal weight_sat : STD_LOGIC_VECTOR(15 downto 0);
	signal weight_LTD : STD_LOGIC_VECTOR(31 downto 0);
		-- 32 bit(sign1, int7, dec24)
	signal weight_LTP : STD_LOGIC_VECTOR(31 downto 0);
		-- 32 bit(sign1, int7, dec24)
	signal t_win_min : STD_LOGIC_VECTOR(31 downto 0);

	-- Constant --
	constant zeros			: STD_LOGIC_VECTOR(31 downto 0)
		:= (others=>'0');
	constant weight_max	: STD_LOGIC_VECTOR(weight_add'range)
		:= "0100000000000000";
	constant weight_min	: STD_LOGIC_VECTOR(weight_add'range)
		:= (others=>'0'); --"1011111111111111";

	-- Delay --
	signal g_weight_old_delay0  : STD_LOGIC_VECTOR(15 downto 0);
	signal g_weight_old_delay1  : STD_LOGIC_VECTOR(15 downto 0);
	signal g_spkmean_new_delay3 : STD_LOGIC_VECTOR(15 downto 0);
	signal g_spkmean_new_delay4 : STD_LOGIC_VECTOR(15 downto 0);
	signal g_spkmean_new_delay5 : STD_LOGIC_VECTOR(15 downto 0);
	signal spk_grc_delay0 : STD_LOGIC;
	signal spk_grc_delay1 : STD_LOGIC;
	signal spk_grc_delay2 : STD_LOGIC;
	signal spk_cf_delay0 : STD_LOGIC;
	signal spk_cf_delay1 : STD_LOGIC;
	signal spk_cf_delay2 : STD_LOGIC;
	signal weight_delay0	: STD_LOGIC_VECTOR(15 downto 0);
	signal weight_delay1	: STD_LOGIC_VECTOR(15 downto 0);
	signal weight_delay2	: STD_LOGIC_VECTOR(15 downto 0);
	signal weight_delay3	: STD_LOGIC_VECTOR(15 downto 0);

	-- LFSR Random --
	signal INIT0 : STD_LOGIC_VECTOR(31 downto 0);
	signal INIT1 : STD_LOGIC_VECTOR(31 downto 0);
	signal rand0 : STD_LOGIC_VECTOR(31 downto 0);
	signal rand1 : STD_LOGIC_VECTOR(31 downto 0);

	COMPONENT LFSR32bit
  PORT(
    CLK : IN  STD_LOGIC;
		RST : IN  STD_LOGIC;
    ENA : IN  STD_LOGIC;
    INIT : IN  STD_LOGIC_VECTOR(31 downto 0);
		LFSR : OUT STD_LOGIC_VECTOR(31 downto 0)
  );
  END COMPONENT;

	COMPONENT MULT_32_16
	PORT (
		clk : IN STD_LOGIC;
		a : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
		b : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		ce : IN STD_LOGIC;
		p : OUT STD_LOGIC_VECTOR(47 DOWNTO 0)
	);
	END COMPONENT;

begin
--- Valid  protocol -----------------------------------------------------------
  VALID_REG0_MUL <= '1' when VALID_I='1' else
                    '0';

	process(CLK, RST) begin
		if RST='1' then
			VALID_REG1_DIF <= '0';
		elsif(CLK'event and CLK='1') then
			if VALID_REG0_MUL='1' then
				VALID_REG1_DIF <= '1';
			else
				VALID_REG1_DIF <= '0';
			end if;
		end if;
	end process;

	process(CLK, RST) begin
		if RST='1' then
			VALID_REG2_MUL <= '0';
		elsif(CLK'event and CLK='1') then
			if VALID_REG1_DIF='1' then
				VALID_REG2_MUL <= '1';
			else
				VALID_REG2_MUL <= '0';
			end if;
		end if;
	end process;

	process(CLK, RST) begin
		if RST='1' then
			VALID_REG3_WIN <= '0';
		elsif(CLK'event and CLK='1') then
			if VALID_REG2_MUL='1' then
				VALID_REG3_WIN <= '1';
			else
				VALID_REG3_WIN <= '0';
			end if;
		end if;
	end process;

  process(CLK, RST) begin
    if RST='1' then
      VALID_REG4_ADD <= '0';
    elsif(CLK'event and CLK='1') then
			if VALID_REG3_WIN='1' then
      	VALID_REG4_ADD <= '1';
    	else
      	VALID_REG4_ADD <= '0';
    	end if;
		end if;
  end process;

  process(CLK, RST) begin
    if RST='1' then
      VALID_REG5_SAT <= '0';
    elsif(CLK'event and CLK='1') then
			if VALID_REG4_ADD='1' then
		    VALID_REG5_SAT <= '1';
		  else
		    VALID_REG5_SAT <= '0';
		  end if;
		end if;
  end process;

	process(CLK, RST) begin
    if RST='1' then
      RST_LFSR <= '0';
		end if;
  end process;
-------------------------------------------------------------------------------

--- Low-Path Filter -----------------------------------------------------------
--- Mult ----------------------------------------------
	-- dy/dt = a*x - b*y
	-- y = b*x - b*y + y  -- When converging to x then a = b
	-- b = t_win   =   1  / tau =   1  / (100 ms)
	-- a = gum_LTD = gain / tau = gain / (100 ms)

	spkshift <= zeros(15) & spk_grc & zeros(13 downto 0);
		-- 16bit(sign1, int1, dec14)

	MULT_32_16_COMP0 : MULT_32_16
	PORT MAP (
		clk => clk,
		a => gum_LTD,          -- 32bit(sign1, int7, dec24)
		b => spkshift,         -- 16bit(sign1, int1, dec14)
		ce => VALID_REG0_MUL,
		p => g_spk             -- 48bit(sign1, int9 dec38)
	);

	t_win_min <= -t_win;
	MULT_32_16_COMP1 : MULT_32_16
	PORT MAP (
		clk => clk,
		a => t_win_min,           -- 32bit(sign1, int7, dec24)
		b => g_weight_grc_old, -- 16bit(sign1, int1, dec14)
		ce => VALID_REG0_MUL,
		p => tau_spk           -- 48bit(sign1, int9 dec38)
	);

	INIT0 <= INIT;
	uut : LFSR32bit
	PORT MAP (
    CLK => CLK,
    RST => RST_LFSR,
    ENA => VALID_REG0_MUL,
    INIT => INIT0,
    LFSR => rand0
  );

	-- Delay --
	process(CLK, RST) begin
		if(CLK'event and CLK='1') then
			g_weight_old_delay0 <= g_weight_grc_old;
			weight_delay0      <= weight_old;
			spk_grc_delay0     <= spk_grc;
			spk_cf_delay0      <= spk_cf;
		end if;
	end process;
----------------------------------------------------

--- Diff -------------------------------------------
	process(CLK, RST) begin
		if(RST='1') then
			spkmean_add <= (others=>'0');
		elsif(CLK'event and CLK='1') then
			if(VALID_REG1_DIF='1') then
				spkmean_add <= g_spk + tau_spk;
				--spkmean_add_all(39 downto 8);
			end if;
		end if;
	end process;

	process(CLK, RST) begin
		if(RST='1') then
			spkmean_rnd <= (others=>'0');
		elsif(CLK'event and CLK='1') then
			if(VALID_REG1_DIF='1') then
				if ('0'&rand0(30 downto 0)) < ('0'&spkmean_add(30 downto 0)) then
				-- if ('0'&rand0(23 downto 0)) < ('0'&spkmean_add(23 downto 0)) then
					spkmean_rnd <= (0=>'1',others=>'0');
				else
					spkmean_rnd <= (others=>'0');
				end if;
			end if;
		end if;
	end process;

	-- Delay --
	process(CLK, RST) begin
		if(CLK'event and CLK='1') then
			g_weight_old_delay1 <= g_weight_old_delay0;
			weight_delay1  <= weight_delay0;
			spk_grc_delay1 <= spk_grc_delay0;
			spk_cf_delay1  <= spk_cf_delay0;
		end if;
	end process;
----------------------------------------------------

--- Add -------------------------------------------
	process(CLK, RST) begin
		if(RST='1') then
			spkmean_new <= (others=>'0');
		elsif(CLK'event and CLK='1') then
			if(VALID_REG2_MUL='1') then
				spkmean_new <=
					(zeros(0) & g_weight_old_delay1 & zeros(14 downto 0))
				  + spkmean_add(47 downto 16);
					-- (zeros(7 downto 0) & g_weight_old_delay1 & zeros(7 downto 0))
				  -- + spkmean_add(47 downto 16);
					-- 32bit(sign1, int9 dec22)
			end if;
		end if;
	end process;

	process(CLK, RST) begin
		if(RST='1') then
			g_weight_new <= (others=>'0');
		elsif(CLK'event and CLK='1') then
			if(VALID_REG2_MUL='1') then
				g_weight_new <=
					g_weight_old_delay1	+
					spkmean_add(46 downto 31) +
					spkmean_rnd;
					-- g_weight_old_delay1	+
					-- spkmean_add(39 downto 24) +
					-- spkmean_rnd;
					-- 16bit(sign1, int1 dec14)
			end if;
		end if;
	end process;

	process(CLK, RST) begin
		if(CLK'event and CLK='1') then
			weight_delay2  <= weight_delay1;
			spk_grc_delay2 <= spk_grc_delay1;
			spk_cf_delay2  <= spk_cf_delay1;
		end if;
	end process;
----------------------------------------------------

-------------------------------------------------------------------------------

-- LTD & LTP ------------------------------------------------------------------
	w_LTD_process: process(CLK, RST) begin
		if RST='1' then
			weight_LTD <= (others=>'0');
		elsif rising_edge(CLK) then
			if VALID_REG3_WIN='1' then
				if spk_cf_delay2='1' then
					weight_LTD <= -spkmean_new;
				else
					weight_LTD <= (others=>'0');
				end if;
			else
				weight_LTD <= (others=>'0');
			end if;
		end if;
	end process;

	w_LTP_process: process(CLK, RST) begin
		if RST='1' then
			weight_LTP <= (others=>'0');
		elsif rising_edge(CLK) then
			if VALID_REG3_WIN='1' then
				if (spk_grc_delay2='1') and (spk_cf_delay2='0') then
					weight_LTP <= gum_LTP;
				else
					weight_LTP <= (others=>'0');
				end if;
			else
				weight_LTP <= (others=>'0');
			end if;
		end if;
	end process;

	-- LFSR for Round --
	INIT1 <= INIT(7 downto 0) & INIT(31 downto 8);
	LFSR32bit_COMP: LFSR32bit PORT MAP(
		CLK => CLK,
		RST => RST_LFSR,
		ENA => VALID_REG3_WIN,
		INIT => INIT1,
		LFSR => rand1
	);

	-- Delay --
	process(CLK, RST) begin
		if(CLK'event and CLK='1') then
			weight_delay3      <= weight_delay2;
			-- g_spkmean_new_delay3 <= g_weight_new;
		end if;
	end process;

	-- Saturation
	process(CLK, RST) begin
		if RST='1' then
			g_spkmean_new_delay3 <= (others=>'0');
		elsif(CLK'event and CLK='1') then
			if g_weight_new>g_weight_max then
				g_spkmean_new_delay3 <= g_weight_max;
			else
				g_spkmean_new_delay3 <= g_weight_new;
			end if;
		end if;
	end process;
-------------------------------------------------------------------------------

-- w(t) = w(t-dt) + LTD + LTP -------------------------------------------------
	weight_add_all <= weight_LTD + weight_LTP;

	-- Randmized rounding --
	-- RR ver.2 (pre sum) --
	weight_rnd <= (0=>'1', others=>'0') when (("0"&rand1(15 downto 0)) < ("0"&weight_add_all(15 downto 0))) else (others=>'0');

	weight_add_process: process(CLK, RST) begin
		if RST='1' then
			weight_add <= (others=>'0');
		elsif rising_edge(CLK) then
			if VALID_REG4_ADD='1' then
				weight_add <= weight_delay3 + weight_add_all(31 downto 16) + weight_rnd;
			else
				weight_add <= (others=>'0');
			end if;
		end if;
	end process;

	-- Delay --
	process(CLK, RST) begin
		if(CLK'event and CLK='1') then
			g_spkmean_new_delay4 <= g_spkmean_new_delay3;
		end if;
	end process;
-------------------------------------------------------------------------------

-- Saturation -----------------------------------------------------------------
	weight_sat_process: process(CLK, RST) begin
		if RST='1' then
			weight_sat <= (others=>'0');
		elsif rising_edge(CLK) then
			if VALID_REG5_SAT='1' then
				if weight_add<weight_min then
					weight_sat <= weight_min;
				elsif weight_add>weight_max then
					weight_sat <= weight_max;
				else
					weight_sat <= weight_add;
				end if;
			else
				weight_sat <= (others=>'0');
			end if;
		end if;
	end process;

	-- Delay --
	process(CLK, RST) begin
		if(CLK'event and CLK='1') then
			g_spkmean_new_delay5 <= g_spkmean_new_delay4;
		end if;
	end process;
-------------------------------------------------------------------------------

-- Output ---------------------------------------------------------------------
	process(CLK, RST) begin
		if RST='1' then
			VALID_O <= '0';
		elsif(CLK'event and CLK='1') then
			if VALID_REG5_SAT='1' then
				VALID_O <= '1';
			else
				VALID_O <= '0';
			end if;
		end if;
	end process;

	weight_new       <= weight_sat;
	g_weight_grc_new <= g_spkmean_new_delay5;
-------------------------------------------------------------------------------
end Behavioral;
