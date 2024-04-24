-------------------------------------------------------------------------------
-- Leaky Integrate and Fire Neuron model
--
-- BSD 3-Clause License
-- Copyright (c) 2024, Yusuke Shinji
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_SIGNED.all;

entity MEMPOT16bit is
Port(
	CLK     : in  STD_LOGIC;
  RST     : in  STD_LOGIC;
  VALID_I : in  STD_LOGIC;
	VALID_O	: out STD_LOGIC;
	-- Constant --
  INIT      : in  STD_LOGIC_VECTOR(31 downto 0);
	k_inp     : in  STD_LOGIC_VECTOR(31 downto 0); -- 32bit(sign1, int1, dec30)
	f_lek     : in  STD_LOGIC_VECTOR(31 downto 0); -- 32bit(sign1, int1, dec30)
	e_lrt     : in  STD_LOGIC_VECTOR(31 downto 0); -- 32bit(sign1, int7, dec24)
	v_end     : in  STD_LOGIC_VECTOR(31 downto 0); -- 32bit(sign1, int7, dec24)
	v_thr     : in  STD_LOGIC_VECTOR(31 downto 0); -- 32bit(sign1, int7, dec24)
	v_udr     : in  STD_LOGIC_VECTOR(31 downto 0); -- 32bit(sign1, int7, dec24)
	v_rst     : in  STD_LOGIC_VECTOR(31 downto 0); -- 32bit(sign1, int7, dec24)
	-- Inputs --
	i_syn     : in  STD_LOGIC_VECTOR(15 downto 0); -- 16bit(sign1, int15, dec0)
  v_mb_old  : in  STD_LOGIC_VECTOR(15 downto 0); -- 16bit(sign1, int7, dec8)
	-- Outputs --
	v_mb_new  : out STD_LOGIC_VECTOR(15 downto 0); -- 16bit(sign1, int7, dec8)
	t_spk_new : out STD_LOGIC                      --  1bit(sign0, int1, dec0)
);
end MEMPOT16bit;

architecture Behavioral of MEMPOT16bit is
	-- Pipeline Register --
  signal VALID_REG0_MLT : STD_LOGIC;
  signal VALID_REG1_ADD : STD_LOGIC;
  signal VALID_REG2_THR : STD_LOGIC;

	-- Variable --
	signal v_diff        : STD_LOGIC_VECTOR(15 downto 0);

	signal v_syn		     : STD_LOGIC_VECTOR(47 downto 0);
	signal v_leak		     : STD_LOGIC_VECTOR(47 downto 0);

	signal v_syn_high    : STD_LOGIC_VECTOR(3 downto 0);
	signal v_syn_low	   : STD_LOGIC_VECTOR(3 downto 0); --(7 downto 0);
	signal v_leak_high   : STD_LOGIC_VECTOR(7 downto 0);

--	signal v_end_delay0 : STD_LOGIC_VECTOR(15 downto 0);
	signal v_end_high   : STD_LOGIC_VECTOR(9 downto 0);
	signal v_end_low    : STD_LOGIC_VECTOR(13 downto 0);
	signal v_end_delay0 : STD_LOGIC_VECTOR(55 downto 0);
	signal v_intg       : STD_LOGIC_VECTOR(15 downto 0);

	signal v_add_all     : STD_LOGIC_VECTOR(55 downto 0);
	signal v_add         : STD_LOGIC_VECTOR(15 downto 0);
	signal v_rnd         : STD_LOGIC_VECTOR(15 downto 0);
	signal v_rnd_add     : STD_LOGIC_VECTOR(31 downto 0); -- 4out5in rounding
--	signal logi_rnd_pls  : boolean;
--	signal logi_rnd_min  : boolean;

	signal logi_thr      : boolean;
	signal logi_udr      : boolean;
	signal v_new         : STD_LOGIC_VECTOR(15 downto 0);
	signal t_spk         : STD_LOGIC;

	-- LFSR Random --
	signal rand  : STD_LOGIC_VECTOR(31 downto 0);


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
  VALID_REG0_MLT <= '1' when VALID_I='1' else
                    '0';

  process(CLK, RST) begin
    if RST='1' then
      VALID_REG1_ADD <= '0';
    elsif(CLK'event and CLK = '1') then
			if VALID_REG0_MLT='1' then
				VALID_REG1_ADD <= '1';
			else
				VALID_REG1_ADD <= '0';
			end if;
		end if;
  end process;

  process(CLK, RST) begin
    if RST='1' then
      VALID_REG2_THR <= '0';
    elsif(CLK'event and CLK = '1') then
			if VALID_REG1_ADD='1' then
				VALID_REG2_THR <= '1';
			else
				VALID_REG2_THR <= '0';
			end if;
		end if;
  end process;
-------------------------------------------------------------------------------

--- Multiplier ----------------------------------------------------------------

	-- v_syn = k_inp * i_syn
	MULT_32_16_COMP_in : MULT_32_16
	PORT MAP (
		clk => clk,
		a => k_inp, -- 32it(sign1, int1, dec30)
		b => i_syn, -- 16bit(sign1, int15, dec0)
		ce => VALID_REG0_MLT,
		p => v_syn -- 48it(sign1, int17, dec30)
	);

	-- v_leak = f_lek * v_mb_old
	v_diff <= e_lrt(31 downto 16) - v_mb_old;
	MULT_32_16_COMP_old : MULT_32_16
	PORT MAP (
		clk => clk,
		a => f_lek, -- 32it(sign1, int1, dec30)
		b => v_diff, -- 16bit(sign1, int7, dec8)
		ce => VALID_REG0_MLT,
		p => v_leak -- 48it(sign1, int9, dec38)
	);

	-- v_intg = v_mb_old
	v_intg_process: process(CLK, RST) begin
		if RST='1' then
			v_intg <= (others=>'0');
		elsif rising_edge(CLK) then
			if VALID_REG0_MLT='1' then
				v_intg <= v_mb_old; -- 16bit(sign1, int7, dec8)
			else
				v_intg <= (others=>'0');
			end if;
		end if;
	end process;

	v_end_high <= (others=>v_end(31));
	v_end_low  <= (others=>v_end(31));
	delay0_process: process(CLK, RST) begin
		if rising_edge(CLK) then
			-- v_end_delay0 <= v_end(31 downto 16);
			v_end_delay0 <= v_end_high & v_end & v_end_low;
		end if;
	end process;

  uut: LFSR32bit PORT MAP (
    CLK => CLK,
    RST => RST,
    ENA => VALID_REG0_MLT,
    INIT => INIT,
    LFSR => rand
  );
-----------------------------------------------------------------------------

--- Adder -------------------------------------------------------------------

	-- Add --
	v_syn_high  <= (others=>v_syn(47));
	v_syn_low   <= (others=>'0');
	v_leak_high <= (others=>v_leak(47));
	v_add_all <= (v_syn_high & v_syn & v_syn_low) + (v_leak_high & v_leak) + v_end_delay0;
--	v_add_all <= v_syn + v_leak;

	v_add_process: process(CLK, RST) begin
		if RST='1' then
			v_add <= (others=>'0');
		elsif rising_edge(CLK) then
			if VALID_REG1_ADD='1' then
				v_add <= v_intg --+ v_end_delay0
				         + v_add_all(45 downto 30); 											-- RR ver.2 (pre sum)
				         -- + v_syn(45 downto 30) + v_leak(45 downto 30);	-- RR ver.1 (parallel sum)
				--  16bit(sign1, int7, dec8)
			else
				v_add <= (others=>'0');
			end if;
		end if;
	end process;

	-- Randmized rounding --
	-- RR ver.2 (pre sum) --
	v_rnd_process: process(CLK, RST) begin
		if RST='1' then
			v_rnd <= (others=>'0');
		elsif rising_edge(CLK) then
			if VALID_REG1_ADD='1' then
				if (("0"&rand(29 downto 0)) < ("0"&v_add_all(29 downto 0))) then
					v_rnd <= (0=>'1', others=>'0'); -- = 1
				else
					v_rnd <= (others=>'0');
				end if;
			else
				v_rnd <= (others=>'0');
			end if;
		end if;
	end process;

	-- RR ver.1 (parallel sum) --
--	logi_rnd_pls <= True when (("0"&rand(29 downto 0)) <= ("0"&v_syn(29 downto 0))) else False;
--	logi_rnd_min <= True when (("1"&rand(29 downto 0)) <= ("1"&v_leak(29 downto 0))) else False;
--
--	v_rnd_process: process(CLK, RST) begin
--		if RST='1' then
--			v_rnd <= (others=>'0');
--		elsif rising_edge(CLK) then
--			if VALID_REG1_ADD='1' then
--				if    ( logi_rnd_pls and logi_rnd_min ) then
--					v_rnd <= (1=>'1', others=>'0'); -- = 2
--				elsif ( logi_rnd_pls xor logi_rnd_min ) then
--					v_rnd <= (0=>'1', others=>'0'); -- = 1
--				else
--					v_rnd <= (others=>'0'); -- =  0
--				end if;
--			else
--				v_rnd <= (others=>'0');
--			end if;
--		end if;
--	end process;

	-- 4out5in rounding --
--	v_rnd_process: process(CLK, RST) begin
--		if RST='1' then
--			v_rnd <= (others=>'0');
--		elsif rising_edge(CLK) then
--			if VALID_REG1_ADD='1' then
--				v_rnd <= (0=>v_add_all(29),others=>'0');
--			end if;
--		end if;
--	end process;
-----------------------------------------------------------------------------

--- Threshold determination--------------------------------------------------

	-- Logic of Threshold --
	logi_thr <= True when (v_add >= v_thr(31 downto 16)) else False;
	logi_udr <= True when (v_add <= v_udr(31 downto 16)) else False;

	---- Threshold ----
	v_new_process: process(CLK, RST) begin
		if RST='1' then
			v_new <= (others=>'0');
		elsif rising_edge(CLK) then
			if VALID_REG2_THR='1' then
				if (logi_thr) then
					-- RST membrane potential
					v_new <= --v_add + v_rnd + (v_rst(31 downto 16) - v_thr(31 downto 16));
									 v_rst(31 downto 16);
					         -- 8bit(sign1, int7, dec0)
				elsif (logi_udr) then
					v_new <= v_udr(31 downto 16);
				else
					v_new <= v_add + v_rnd;
				end if;
			else
				v_new <= (others=>'0');
			end if;
		end if;
	end process;

	t_spk_process: process(CLK, RST) begin
		if RST='1' then
			t_spk <= '0';
		elsif rising_edge(CLK) then
			if VALID_REG2_THR='1' then
				if (logi_thr) then
					t_spk <= '1';
				else
					-- Reset
					t_spk <= '0';
				end if;
			else
				t_spk <= '0';
			end if;
		end if;
	end process;
-------------------------------------------------------------------------------

--- Output --------------------------------------------------------------------
  process(CLK, RST) begin
    if RST='1' then
      VALID_O <= '0';
    elsif(CLK'event and CLK = '1') then
			if VALID_REG2_THR='1' then
				VALID_O <= '1';
			else
				VALID_O <= '0';
			end if;
		end if;
  end process;

	v_mb_new  <= v_new; -- 16bit(sign1, int7, dec8)
  t_spk_new <= t_spk; --  1bit(int1)
-------------------------------------------------------------------------------

end Behavioral;
