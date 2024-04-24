--------------------------------------------------------------------------------
-- BSD 3-Clause License
-- Copyright (c) 2024, Yusuke Shinji
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_SIGNED.ALL;
--use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.std_logic_misc.all;

entity CELL_BkC is
Port (
	CLK : in  STD_LOGIC;
	RST : in  STD_LOGIC;
	hem   : in  STD_LOGIC;
	RST_ADDR : in STD_LOGIC;
	VALID_I : in  STD_LOGIC;
	VALID_O : out STD_LOGIC;
	END_SUM_I_BkC_GrC : in STD_LOGIC;
	-- Constant --
	INIT     : in  STD_LOGIC_VECTOR(31 downto 0);
	-- Input --
	t_spk_grc : in  STD_LOGIC_VECTOR(4095 downto 0);
	-- Output --
	t_spk : out STD_LOGIC_VECTOR(24 downto 0)
);
end CELL_BkC;

architecture Behavioral of CELL_BkC is
	-- Valid --
	signal VALID_I_MUX_BkC_GrC : STD_LOGIC;
	signal VALID_O_MUX_BkC_GrC : STD_LOGIC;
	signal END_SUM_O_BkC_GrC : STD_LOGIC;

	signal END_SUM_O_BkC_GrC_delay : STD_LOGIC;

	signal VALID_I_SYNCND : STD_LOGIC;
	signal VALID_O_SYNCND_BkC_GrC : STD_LOGIC;
	signal VALID_O_PRE_SYNCND_BkC_GrC : STD_LOGIC;

--	signal READY_O_SYNCUR : STD_LOGIC;
	signal VALID_I_SYNCUR_BkC_GrC : STD_LOGIC;
	signal VALID_O_SYNCUR_BkC_GrC : STD_LOGIC;

	signal VALID_REG_SUM : STD_LOGIC;
	signal VALID_I_MEMPOT : STD_LOGIC;
	signal VALID_O_MEMPOT : STD_LOGIC;

	-- Value --
	signal INIT_Cell : STD_LOGIC_VECTOR(31 downto 0);
	signal INIT_g_grc: STD_LOGIC_VECTOR(31 downto 0);

	signal weight_BkC_GrC : STD_LOGIC_VECTOR(15 downto 0);

	signal weight_sum_BkC_GrC : STD_LOGIC_VECTOR(15 downto 0) := (others=>'0');

	signal g_syn_old_BkC_GrC : STD_LOGIC_VECTOR(15 downto 0);
	signal g_syn_new_BkC_GrC  : STD_LOGIC_VECTOR(15 downto 0);

	signal i_syn_BkC_GrC : STD_LOGIC_VECTOR(15 downto 0);
	signal i_syn         : STD_LOGIC_VECTOR(15 downto 0) := (others=>'0');

	signal v_mb_old : STD_LOGIC_VECTOR(15 downto 0);
	signal v_mb_new : STD_LOGIC_VECTOR(15 downto 0);

	signal v_mb_delay0 : STD_LOGIC_VECTOR(15 downto 0);
	signal v_mb_delay1 : STD_LOGIC_VECTOR(15 downto 0);
	signal v_mb_delay2 : STD_LOGIC_VECTOR(15 downto 0);
	signal v_mb_delay3 : STD_LOGIC_VECTOR(15 downto 0);

	signal t_spk_new : STD_LOGIC;

	-- Constant --
	constant weight_mean_BkC_GrC : STD_LOGIC_VECTOR(15 downto 0)
		   := "0000000000000001";
		-- := "0000000000000001";
		-- := "0000000000001001";
	constant tau_syn_BkC_GrC : STD_LOGIC_VECTOR(31 downto 0)
		:= "11000000000000000000000000000000";

	constant v_rev_BkC_GrC : STD_LOGIC_VECTOR(15 downto 0)
		:= "0000000000000000";

	constant k_inp : STD_LOGIC_VECTOR(31 downto 0)
		:= "00000100011000100011000100011000";
	constant f_lek : STD_LOGIC_VECTOR(31 downto 0)
		:= "00000100011000100011000100011000";
	constant e_lrt    : STD_LOGIC_VECTOR(31 downto 0)
		:= "10111100000000000000000000000000"; -- 32bit(sign1, int7, dec24)
	constant v_thr    : STD_LOGIC_VECTOR(31 downto 0)
		:= "11001011000000000000000000000000"; -- 32bit(sign1, int7, dec24)
	constant v_udr    : STD_LOGIC_VECTOR(31 downto 0)
		:= "10100110000000000000000000000000"; -- 32bit(sign1, int7, dec24)
	constant v_rst    : STD_LOGIC_VECTOR(31 downto 0)
		:= "10110010000000000000000000000000"; -- 32bit(sign1, int7, dec24)

	signal v_end  : STD_LOGIC_VECTOR(31 downto 0); -- 32bit(sign1, int7, dec24)
	signal rand    : STD_LOGIC_VECTOR(31 downto 0);
	constant zeros : STD_LOGIC_VECTOR(31 downto 0) := (others=>'0');

	-- RAM --
	signal READ_g_syn_BkC_GrC  : STD_LOGIC_VECTOR(0 downto 0);
	signal WRITE_g_syn_BkC_GrC : STD_LOGIC_VECTOR(16 downto 0);

	signal READ_v_mb  : STD_LOGIC_VECTOR(0 downto 0);
	signal WRITE_v_mb : STD_LOGIC_VECTOR(16 downto 0);

	signal WRITE_t_spk : STD_LOGIC_VECTOR(1 downto 0);
	signal t_spk_all : STD_LOGIC_VECTOR(24 downto 0);

	COMPONENT MUX_BkC_GrC is
	Port (
		CLK : in  STD_LOGIC;
		RST : in  STD_LOGIC;
		VALID_I : in  STD_LOGIC;
		VALID_O : out STD_LOGIC;
		END_SUM_I : in  STD_LOGIC;
		END_SUM_O : out STD_LOGIC;
		-- Constant --
		weight_mean : in  STD_LOGIC_VECTOR(15 downto 0);
		INIT        : in  STD_LOGIC_VECTOR(31 downto 0);
		-- Input --
		t_spk       : in  STD_LOGIC_VECTOR(4095 downto 0);
		-- Output --
		weight_syn  : out STD_LOGIC_VECTOR(15 downto 0)
	);
	END COMPONENT;

	COMPONENT SYNCND16bit
	Port(
		CLK : in STD_LOGIC;
		RST : in STD_LOGIC;
		VALID_I : in  STD_LOGIC;
		VALID_O : out STD_LOGIC;
		VALID_O_PRE : out STD_LOGIC;
		-- Constant --
		INIT      : in  STD_LOGIC_VECTOR(31 downto 0);
		tau_syn   : in  STD_LOGIC_VECTOR(31 downto 0);
		-- Inputs --
		w_sum	    : in  STD_LOGIC_VECTOR(15 downto 0);
		g_syn_old : in  STD_LOGIC_VECTOR(15 downto 0);
		-- Outputs --
		g_syn_new : out STD_LOGIC_VECTOR(15 downto 0)
	);
	end COMPONENT;

	COMPONENT SYNCUR16bit
	Port (
		CLK : in  STD_LOGIC;
		RST : in  STD_LOGIC;
		VALID_I : in  STD_LOGIC;
		VALID_O : out STD_LOGIC;
		-- Constant --
		v_rev    : in  STD_LOGIC_VECTOR(15 downto 0); -- 16bit(sing1, int5, dec10)
		-- Input --
		g_syn	   : in  STD_LOGIC_VECTOR(15 downto 0);
		v_mb_old : in  STD_LOGIC_VECTOR(15 downto 0);
		-- Output --
		i_syn    : out  STD_LOGIC_VECTOR(15 downto 0) -- 23bit(sing1, int8, dec14)
	);
	END COMPONENT;

	COMPONENT MEMPOT16bit
	Port(
		CLK : in  STD_LOGIC;
		RST : in  STD_LOGIC;
		VALID_I : in  STD_LOGIC;
		VALID_O	: out STD_LOGIC;
		-- Constant --
		INIT      : in  STD_LOGIC_VECTOR(31 downto 0);
		k_inp     : in  STD_LOGIC_VECTOR(31 downto 0); -- gain
		f_lek     : in  STD_LOGIC_VECTOR(31 downto 0); -- 1 / time constant
		e_lrt     : in  STD_LOGIC_VECTOR(31 downto 0); -- leaking resting potential
		v_thr     : in  STD_LOGIC_VECTOR(31 downto 0); -- threshold
		v_end     : in  STD_LOGIC_VECTOR(31 downto 0); -- endogenous
		v_udr     : in  STD_LOGIC_VECTOR(31 downto 0); -- prevent overflow
		v_rst     : in  STD_LOGIC_VECTOR(31 downto 0); -- reset from spike potential
		-- Inputs --
		v_mb_old  : in  STD_LOGIC_VECTOR(15 downto 0);
		i_syn     : in  STD_LOGIC_VECTOR(15 downto 0);
		-- Outputs --
		v_mb_new  : out STD_LOGIC_VECTOR(15 downto 0);
		t_spk_new : out STD_LOGIC
	);
	END COMPONENT;

	COMPONENT FIFO_g_syn_BkC_GrC
	PORT(
		CLK : IN  std_logic;
		RST : IN  std_logic;
		hem   : in  STD_LOGIC;
		READ1  : IN  std_logic_vector(0 downto 0);
		WRITE1 : IN  std_logic_vector(16 downto 0);
		DOUT1  : OUT std_logic_vector(15 downto 0)
	);
	END COMPONENT;

	COMPONENT FIFO_v_mb_BkC
	PORT(
		CLK : IN  std_logic;
		RST : IN  std_logic;
		hem   : in  STD_LOGIC;
		READ1  : IN  std_logic_vector(0 downto 0);
		WRITE1 : IN  std_logic_vector(16 downto 0);
		DOUT1  : OUT std_logic_vector(15 downto 0)
	);
	END COMPONENT;

	COMPONENT FF_t_spk_BkC
	Port (
		CLK : in  STD_LOGIC;
		RST : in  STD_LOGIC;
		hem   : in  STD_LOGIC;
		WRITE1 : in  STD_LOGIC_VECTOR(1 downto 0);
		DOUT1 : out STD_LOGIC_VECTOR(24 downto 0)
	);
	END COMPONENT;

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
  VALID_I_MUX_BkC_GrC <= '1' when VALID_I='1' else '0';

	process(CLK, RST) begin
		if(CLK'event and CLK='1') then
				END_SUM_O_BkC_GrC_delay <= END_SUM_O_BkC_GrC;
		end if;
	end process;

	process(CLK, RST) begin
		if RST='1' then
			VALID_I_SYNCND <= '0';
		elsif(CLK'event and CLK='1') then
			if END_SUM_O_BkC_GrC='1' then
				VALID_I_SYNCND <= '1';
			else
				VALID_I_SYNCND <= '0';
			end if;
		end if;
	end process;

	VALID_I_SYNCUR_BkC_GrC <= '1' when VALID_O_SYNCND_BkC_GrC='1' else '0';

	VALID_REG_SUM <= '1' when(VALID_O_SYNCUR_BkC_GrC='1') else
	                 '0';

	process(CLK, RST) begin
    if RST='1' then
      VALID_I_MEMPOT <= '0';
    elsif(CLK'event and CLK='1') then
				if (VALID_REG_SUM='1') then
	      VALID_I_MEMPOT <= '1';
	    else
	      VALID_I_MEMPOT <= '0';
	    end if;
		end if;
  end process;
-------------------------------------------------------------------------------

--- Initial of LFSR -----------------------------------------------------------
	INIT_Cell <= INIT;
	INIT_g_grc <= (INIT_Cell(17 downto 0) & INIT_Cell(31 downto 18));
-------------------------------------------------------------------------------

--- Calculate MUX -------------------------------------------------------------
	MUX_BkC_GrC_COMP: MUX_BkC_GrC Port MAP(
		CLK => CLK,
		RST => RST_ADDR,
		VALID_I => VALID_I_MUX_BkC_GrC,
		VALID_O => VALID_O_MUX_BkC_GrC,
		END_SUM_I => END_SUM_I_BkC_GrC,
		END_SUM_O => END_SUM_O_BkC_GrC,
		-- Constant --
		weight_mean => weight_mean_BkC_GrC,
		INIT => INIT_Cell,
		-- Input --
		t_spk => t_spk_grc,
		-- Output --
		weight_syn => weight_BkC_GrC
	);
-------------------------------------------------------------------------------

--- Calculate SynapticConductance ---------------------------------------------
	process(CLK, RST) begin
		if(RST='1') then
			weight_sum_BkC_GrC <= (others=>'0');
		elsif(CLK'event and CLK='1') then
			if(VALID_O_MUX_BkC_GrC='1' and END_SUM_O_BkC_GrC_delay='0') then
				if(VALID_I_SYNCND='1') then
					weight_sum_BkC_GrC <= (others=>'0');
				else
					weight_sum_BkC_GrC <=
						weight_sum_BkC_GrC
						+ weight_BkC_GrC;
				end if;
			else
				if(VALID_I_SYNCND='1') then
					weight_sum_BkC_GrC <= (others=>'0');
				end if;
			end if;
		end if;
	end process;

--	process(CLK, RST) begin
--		if(RST='1') then
--			weight_sum_BkC_GrC <= (others=>'0');
--		elsif(CLK'event and CLK='1') then
--			if(VALID_O_MUX_BkC_GrC='1' and END_SUM_O_BkC_GrC_delay='0') then
--				if(VALID_I_SYNCND='1') then
--					weight_sum_BkC_GrC <=
--						weight_BkC_GrC;
--				else
--					weight_sum_BkC_GrC <=
--						weight_sum_BkC_GrC
--						+ weight_BkC_GrC;
--				end if;
--			else
--				if(VALID_I_SYNCND='1') then
--					weight_sum_BkC_GrC <= (others=>'0');
--				end if;
--			end if;
--		end if;
--	end process;

	SYNCND_COMP_BkC_GrC: SYNCND16bit PORT MAP(
		CLK => CLK,
		RST => RST,
		VALID_I => VALID_I_SYNCND,
		VALID_O => VALID_O_SYNCND_BkC_GrC,
		VALID_O_PRE => VALID_O_PRE_SYNCND_BkC_GrC,
		-- Constant --
		INIT => INIT_g_grc,
		tau_syn => tau_syn_BkC_GrC,
		-- Input --
		w_sum => weight_sum_BkC_GrC,
		g_syn_old => g_syn_old_BkC_GrC,
		-- Output --
		g_syn_new => g_syn_new_BkC_GrC
	);
-------------------------------------------------------------------------------

--- Calculate SynapticCurrent -------------------------------------------------
  SYNCUR_COMP_BkC_GrC: SYNCUR16bit PORT MAP(
		CLK => CLK,
		RST => RST,
		VALID_I => VALID_I_SYNCUR_BkC_GrC,
		VALID_O => VALID_O_SYNCUR_BkC_GrC,
		-- Constant --,
		v_rev     => v_rev_BkC_GrC,
		-- Input --
		g_syn     => g_syn_new_BkC_GrC,
		v_mb_old  => v_mb_old,
		-- Output --
		i_syn     => i_syn_BkC_GrC
  );

  process(CLK,RST) begin
		if(RST='1') then
			i_syn <= (others=>'0');
		elsif(CLK'event and CLK = '1') then
			if VALID_REG_SUM='1' then
				i_syn <= i_syn_BkC_GrC;
			else
				i_syn <= (others=>'0');
			end if;
		end if;
	end process;
-------------------------------------------------------------------------------

--- delay ---------------------------------------------------------------------
	process(CLK) begin
		if(CLK'event and CLK='1') then
			v_mb_delay0 <= v_mb_old;
			v_mb_delay1 <= v_mb_delay0;
			v_mb_delay2 <= v_mb_delay1;
			v_mb_delay3 <= v_mb_delay2;
		end if;
	end process;
-------------------------------------------------------------------------------

--- Calculate MembranePotential -----------------------------------------------
  MEMPOT_COMP: MEMPOT16bit PORT MAP(
		CLK => CLK,
		RST => RST,
		VALID_I => VALID_I_MEMPOT,
		VALID_O => VALID_O_MEMPOT,
		-- Constant --
		INIT  => INIT,
		k_inp => k_inp,
		f_lek => f_lek,
		e_lrt => e_lrt,
		v_end => v_end,
		v_thr => v_thr,
		v_udr => v_udr,
		v_rst => v_rst,
		-- Input --
		i_syn     => i_syn,
		v_mb_old  => v_mb_delay3,
		-- Output --
		v_mb_new  => v_mb_new,
		t_spk_new => t_spk_new
  );
-------------------------------------------------------------------------------

--- Flip Flop -----------------------------------------------------------------
	READ_g_syn_BkC_GrC  <=
	 "1" when END_SUM_O_BkC_GrC='1' else
	 "0";
	WRITE_g_syn_BkC_GrC <=
		g_syn_new_BkC_GrC & '1' when VALID_O_SYNCND_BkC_GrC='1' else
		(others=>'0');
	FIFO_g_syn_BkC_GrC_comp: FIFO_g_syn_BkC_GrC PORT MAP(
		CLK => CLK,
		RST => RST_ADDR,
		hem => hem,
		READ1  => READ_g_syn_BkC_GrC,
		WRITE1 => WRITE_g_syn_BkC_GrC,
		DOUT1  => g_syn_old_BkC_GrC
	);

	READ_v_mb  <= "1" when VALID_O_PRE_SYNCND_BkC_GrC='1' else
								"0";
	WRITE_v_mb <= v_mb_new & '1' when VALID_O_MEMPOT='1' else
								(others=>'0');
	FIFO_v_mb_BkC_comp: FIFO_v_mb_BkC PORT MAP(
		CLK => CLK,
		RST => RST_ADDR,
		hem => hem,
		READ1  => READ_v_mb,
		WRITE1 => WRITE_v_mb,
		DOUT1  => v_mb_old
	);

	WRITE_t_spk <= t_spk_new & '1' when VALID_O_MEMPOT='1' else
								 (others=>'0');
	FF_t_spk_BkC_comp: FF_t_spk_BkC PORT MAP(
		CLK => CLK,
		RST => RST_ADDR,
		hem => hem,
		WRITE1 => WRITE_t_spk,
		DOUT1  => t_spk_all
	);
-------------------------------------------------------------------------------

--- endogenous ----------------------------------------------------------------
	uut: LFSR32bit PORT MAP (
		CLK => CLK,
		RST => RST,
		ENA => VALID_REG_SUM,
		INIT => INIT,
		LFSR => rand
	);

	v_end <= zeros(31 downto 25) & rand(24 downto 0); -- v_end = [0, 2]
	-- mean of Vend = Ispont / C = 15.6 pA / 14.6 pF ~ 1
-------------------------------------------------------------------------------

---- Output -------------------------------------------------------------------
	process(CLK, RST) begin
		if RST='1' then
			VALID_O <= '0';
		elsif(CLK'event and CLK='1') then
			if VALID_O_MEMPOT='1' then
				VALID_O <= '1';
			else
				VALID_O <= '0';
			end if;
		end if;
	end process;

  t_spk   <= t_spk_all;
-------------------------------------------------------------------------------

end Behavioral;
