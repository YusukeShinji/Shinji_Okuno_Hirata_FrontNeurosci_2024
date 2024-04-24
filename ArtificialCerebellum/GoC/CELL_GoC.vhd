-------------------------------------------------------------------------------
-- BSD 3-Clause License
-- Copyright (c) 2024, Yusuke Shinji
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_SIGNED.ALL;
--use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity CELL_GoC is
Port (
	CLK : in  STD_LOGIC;
	RST : in  STD_LOGIC;
	hem : in  STD_LOGIC;
	RST_ADDR : in STD_LOGIC;
	VALID_I : in  STD_LOGIC;
	VALID_O : out STD_LOGIC;
	END_SUM_I_GoC_GrC : in STD_LOGIC;
	END_SUM_I_GoC_MF : in STD_LOGIC;
	-- Constant --
	Num_Cell : in  STD_LOGIC_VECTOR(2 downto 0);
	INIT : in  STD_LOGIC_VECTOR(31 downto 0);
	-- Input --
	t_spk_grc : in  STD_LOGIC_VECTOR(4095 downto 0);
	t_spk_mf  : in  STD_LOGIC_VECTOR(245 downto 0);
	-- Output --
	t_spk : out STD_LOGIC_VECTOR(122 downto 0)
);
end CELL_GoC;

architecture Behavioral of CELL_GoC is
	-- Valid --
	signal VALID_I_MUX_GoC_GrC : STD_LOGIC;
	signal VALID_I_MUX_GoC_MF  : STD_LOGIC;
	signal VALID_O_MUX_GoC_GrC : STD_LOGIC;
	signal VALID_O_MUX_GoC_MF  : STD_LOGIC;
	signal END_SUM_O_GoC_GrC : STD_LOGIC;
	signal END_SUM_O_GoC_MF  : STD_LOGIC;

	signal END_SUM_O_GoC_GrC_delay : STD_LOGIC;
	signal END_SUM_O_GoC_MF_delay : STD_LOGIC;

	signal VALID_I_SYNCND : STD_LOGIC;
	signal VALID_O_SYNCND_GoC_GrC : STD_LOGIC;
	signal VALID_O_SYNCND_GoC_MF  : STD_LOGIC;
	signal VALID_O_PRE_SYNCND_GoC_GrC : STD_LOGIC;
	signal VALID_O_PRE_SYNCND_GoC_MF  : STD_LOGIC;

--	signal READY_O_SYNCUR : STD_LOGIC;
	signal VALID_I_SYNCUR_GoC_GrC : STD_LOGIC;
	signal VALID_I_SYNCUR_GoC_MF : STD_LOGIC;
	signal VALID_O_SYNCUR_GoC_GrC : STD_LOGIC;
	signal VALID_O_SYNCUR_GoC_MF : STD_LOGIC;

	signal VALID_REG_SUM : STD_LOGIC;
	signal VALID_I_MEMPOT : STD_LOGIC;
	signal VALID_O_MEMPOT : STD_LOGIC;

	-- Value --
	signal Num : INTEGER := 0;
	signal INIT_Cell : STD_LOGIC_VECTOR(31 downto 0);
	signal INIT_g_grc: STD_LOGIC_VECTOR(31 downto 0);
	signal INIT_g_mf : STD_LOGIC_VECTOR(31 downto 0);

	signal weight_GoC_GrC : STD_LOGIC_VECTOR(15 downto 0);
	signal weight_GoC_MF : STD_LOGIC_VECTOR(15 downto 0);

	signal weight_sum_GoC_GrC : STD_LOGIC_VECTOR(15 downto 0) := (others=>'0');
	signal weight_sum_GoC_GrC2 : STD_LOGIC_VECTOR(15 downto 0) := (others=>'0');
	signal weight_sum_GoC_MF : STD_LOGIC_VECTOR(15 downto 0) := (others=>'0');

	signal g_syn_old_GoC_GrC : STD_LOGIC_VECTOR(15 downto 0);
	signal g_syn_old_GoC_MF : STD_LOGIC_VECTOR(15 downto 0);
	signal g_syn_new_GoC_GrC : STD_LOGIC_VECTOR(15 downto 0);
	signal g_syn_new_GoC_MF : STD_LOGIC_VECTOR(15 downto 0);

	signal i_syn_GoC_GrC : STD_LOGIC_VECTOR(15 downto 0);
	signal i_syn_GoC_MF : STD_LOGIC_VECTOR(15 downto 0);
	signal i_syn         : STD_LOGIC_VECTOR(15 downto 0) := (others=>'0');

	signal v_mb_old : STD_LOGIC_VECTOR(15 downto 0);
	signal v_mb_new : STD_LOGIC_VECTOR(15 downto 0);

	signal v_mb_delay0 : STD_LOGIC_VECTOR(15 downto 0);
	signal v_mb_delay1 : STD_LOGIC_VECTOR(15 downto 0);
	signal v_mb_delay2 : STD_LOGIC_VECTOR(15 downto 0);
	signal v_mb_delay3 : STD_LOGIC_VECTOR(15 downto 0);

	signal t_spk_new : STD_LOGIC;

	-- Constant --
	constant zeros8 : STD_LOGIC_VECTOR(7 downto 0) := (others=>'0');
	constant weight_mean_GoC_GrC : STD_LOGIC_VECTOR(15 downto 0)
		:= "0000000000001000";--"0000000000010001";
	constant weight_mean_GoC_MF  : STD_LOGIC_VECTOR(15 downto 0)
		:= "0000000000101100";--"0000000001011001";
	constant tau_syn_GoC_GrC  : STD_LOGIC_VECTOR(31 downto 0)
		:= "11000000000000000000000000000000";
	constant tau_syn_GoC_MF   : STD_LOGIC_VECTOR(31 downto 0)
		:= "11000000000000000000000000000000";

	constant v_rev_GoC_GrC : STD_LOGIC_VECTOR(15 downto 0)
		:= "0000000000000000";
	constant v_rev_GoC_MF  : STD_LOGIC_VECTOR(15 downto 0)
		:= "0000000000000000";

	constant k_inp   : STD_LOGIC_VECTOR(31 downto 0)
		:= "00000000110101111001010000110101";
	constant f_lek : STD_LOGIC_VECTOR(31 downto 0)
		:= "00000011000010000001010110001110";
	constant e_lrt    : STD_LOGIC_VECTOR(31 downto 0)
		:= "10111111000000000000000000000000"; -- 32bit(sign1, int7, dec24)
	constant v_thr    : STD_LOGIC_VECTOR(31 downto 0)
		:= "11001001000000000000000000000000"; -- 32bit(sign1, int7, dec24)
	constant v_udr    : STD_LOGIC_VECTOR(31 downto 0)
		:= "10100110000000000000000000000000"; -- 32bit(sign1, int7, dec24)
	constant v_rst    : STD_LOGIC_VECTOR(31 downto 0)
		:= "10110101000000000000000000000000"; -- 32bit(sign1, int7, dec24)

	signal v_end : STD_LOGIC_VECTOR(31 downto 0);
	signal rand   : STD_LOGIC_VECTOR(31 downto 0);
	constant zeros : STD_LOGIC_VECTOR(31 downto 0) := (others=>'0');

	-- RAM --
	signal READ_g_syn_GoC_GrC  : STD_LOGIC_VECTOR(0 downto 0);
	signal WRITE_g_syn_GoC_GrC : STD_LOGIC_VECTOR(16 downto 0);

	signal READ_g_syn_GoC_MF  : STD_LOGIC_VECTOR(0 downto 0);
	signal WRITE_g_syn_GoC_MF : STD_LOGIC_VECTOR(16 downto 0);

	signal READ_v_mb  : STD_LOGIC_VECTOR(0 downto 0);
	signal WRITE_v_mb : STD_LOGIC_VECTOR(16 downto 0);

	signal WRITE_t_spk : STD_LOGIC_VECTOR(1 downto 0);
	signal t_spk_all : STD_LOGIC_VECTOR(122 downto 0);

	COMPONENT MUX_GoC_GrC is
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
		t_spk    : in  STD_LOGIC_VECTOR(4095 downto 0);
		-- Output --
		weight_syn : out STD_LOGIC_VECTOR(15 downto 0)
	);
	END COMPONENT;

	COMPONENT MUX_GoC_MF is
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
		t_spk      : in  STD_LOGIC_VECTOR(245 downto 0);
		-- Output --
		weight_syn : out STD_LOGIC_VECTOR(15 downto 0)
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

	COMPONENT FIFO_g_syn_GoC_GrC
	PORT(
		CLK : IN  std_logic;
		RST : IN  std_logic;
		hem : in  STD_LOGIC;
		READ1  : IN  std_logic_vector(0 downto 0);
		WRITE1 : IN  std_logic_vector(16 downto 0);
		DOUT1  : OUT std_logic_vector(15 downto 0)
	);
	END COMPONENT;

	COMPONENT FIFO_g_syn_GoC_MF
	PORT(
		CLK : IN  std_logic;
		RST : IN  std_logic;
		hem : in  STD_LOGIC;
		READ1  : IN  std_logic_vector(0 downto 0);
		WRITE1 : IN  std_logic_vector(16 downto 0);
		DOUT1  : OUT std_logic_vector(15 downto 0)
	);
	END COMPONENT;

	COMPONENT FIFO_v_mb_GoC
	PORT(
		CLK : IN  std_logic;
		RST : IN  std_logic;
		hem : in  STD_LOGIC;
		READ1  : IN  std_logic_vector(0 downto 0);
		WRITE1 : IN  std_logic_vector(16 downto 0);
		DOUT1  : OUT std_logic_vector(15 downto 0)
	);
	END COMPONENT;

	COMPONENT FF_t_spk_GoC
	Port (
		CLK : in  STD_LOGIC;
		RST : in  STD_LOGIC;
		hem : in  STD_LOGIC;
		WRITE1 : in  STD_LOGIC_VECTOR(1 downto 0);
		DOUT1  : out STD_LOGIC_VECTOR(122 downto 0)
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
  VALID_I_MUX_GoC_GrC <= '1' when VALID_I='1' else '0';
  VALID_I_MUX_GoC_MF  <= '1' when VALID_I='1' else '0';

	process(CLK, RST) begin
		if(CLK'event and CLK='1') then
				END_SUM_O_GoC_MF_delay <= END_SUM_O_GoC_MF;
				END_SUM_O_GoC_GrC_delay <= END_SUM_O_GoC_GrC;
		end if;
	end process;

	process(CLK, RST) begin
		if(RST='1') then
			VALID_I_SYNCND <= '0';
		elsif(CLK'event and CLK='1') then
			if(END_SUM_O_GoC_GrC='1' and
			   END_SUM_O_GoC_MF='1') then
				VALID_I_SYNCND <= '1';
			else
				VALID_I_SYNCND <= '0';
			end if;
		end if;
	end process;

	VALID_I_SYNCUR_GoC_GrC <= '1' when VALID_O_SYNCND_GoC_GrC='1' else '0';
	VALID_I_SYNCUR_GoC_MF <= '1' when VALID_O_SYNCND_GoC_MF='1' else '0';

	VALID_REG_SUM <= '1' when(VALID_O_SYNCUR_GoC_GrC='1' and
	                          VALID_O_SYNCUR_GoC_MF='1') else
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
	Num <= to_integer(unsigned(Num_Cell));
	INIT_Cell <= INIT(abs(Num) downto 0) & INIT(31 downto abs(Num)+1);
	INIT_g_mf <= (INIT_Cell(17 downto 0) & INIT_Cell(31 downto 18));
	INIT_g_grc <= (INIT_Cell(13 downto 0) & INIT_Cell(31 downto 14));
-------------------------------------------------------------------------------

--- Calculate MUX -------------------------------------------------------------
	MUX_GoC_GrC_COMP: MUX_GoC_GrC Port MAP(
		CLK => CLK,
		RST => RST_ADDR,
		VALID_I => VALID_I_MUX_GoC_GrC,
		VALID_O => VALID_O_MUX_GoC_GrC,
		END_SUM_I => END_SUM_I_GoC_GrC,
		END_SUM_O => END_SUM_O_GoC_GrC,
		-- Constant --
		weight_mean => weight_mean_GoC_GrC,
		INIT        => INIT_Cell,
		-- Input --
		t_spk    => t_spk_grc,
		-- Output --
		weight_syn => weight_GoC_GrC
	);

	MUX_GoC_MF_COMP: MUX_GoC_MF Port MAP(
		CLK => CLK,
		RST => RST_ADDR,
		VALID_I => VALID_I_MUX_GoC_MF,
		VALID_O => VALID_O_MUX_GoC_MF,
		END_SUM_I => END_SUM_I_GoC_MF,
		END_SUM_O => END_SUM_O_GoC_MF,
		-- Constant --
		weight_mean => weight_mean_GoC_MF,
		INIT        => INIT_Cell,
		-- Input --
		t_spk    => t_spk_mf,
		-- Output --
		weight_syn => weight_GoC_MF
	);
-------------------------------------------------------------------------------

--- Calculate SynapticConductance ---------------------------------------------
	process(CLK, RST) begin
		if(RST='1') then
			weight_sum_GoC_GrC <= (others=>'0');
		elsif(CLK'event and CLK='1') then
			if(VALID_O_MUX_GoC_GrC='1' and END_SUM_O_GoC_GrC_delay='0') then
				if(VALID_I_SYNCND='1') then
					weight_sum_GoC_GrC <= (others=>'0');
				else
					weight_sum_GoC_GrC <=
						weight_sum_GoC_GrC
						+ weight_GoC_GrC;
				end if;
			else
				if(VALID_I_SYNCND='1') then
					weight_sum_GoC_GrC <= (others=>'0');
				end if;
			end if;
		end if;
	end process;

	process(CLK, RST) begin
		if(RST='1') then
			weight_sum_GoC_MF <= (others=>'0');
		elsif(CLK'event and CLK='1') then
			if(VALID_O_MUX_GoC_MF='1' and END_SUM_O_GoC_MF_delay='0') then
				if(VALID_I_SYNCND='1') then
					weight_sum_GoC_MF <= (others=>'0');
				else
					weight_sum_GoC_MF <=
						weight_sum_GoC_MF
						+ weight_GoC_MF;
				end if;
			else
				if(VALID_I_SYNCND='1') then
					weight_sum_GoC_MF <= (others=>'0');
				end if;
			end if;
		end if;
	end process;

--	process(CLK, RST) begin
--		if(RST='1') then
--			weight_sum_GoC_GrC <= (others=>'0');
--		elsif(CLK'event and CLK='1') then
--			if(VALID_O_MUX_GoC_GrC='1' and END_SUM_O_GoC_GrC_delay='0') then
--				if(VALID_I_SYNCND='1') then
--					weight_sum_GoC_GrC <=
--						weight_GoC_GrC;
--				else
--					weight_sum_GoC_GrC <=
--						weight_sum_GoC_GrC
--						+ weight_GoC_GrC;
--				end if;
--			else
--				if(VALID_I_SYNCND='1') then
--					weight_sum_GoC_GrC <= (others=>'0');
--				end if;
--			end if;
--		end if;
--	end process;
--
--	process(CLK, RST) begin
--		if(RST='1') then
--			weight_sum_GoC_MF <= (others=>'0');
--		elsif(CLK'event and CLK='1') then
--			if(VALID_O_MUX_GoC_MF='1' and END_SUM_O_GoC_MF_delay='0') then
--				if(VALID_I_SYNCND='1') then
--					weight_sum_GoC_MF <=
--						weight_GoC_MF;
--				else
--					weight_sum_GoC_MF <=
--						weight_sum_GoC_MF
--						+ weight_GoC_MF;
--				end if;
--			else
--				if(VALID_I_SYNCND='1') then
--					weight_sum_GoC_MF <= (others=>'0');
--				end if;
--			end if;
--		end if;
--	end process;

--	weight_sum_GoC_GrC2 <= "00000000"&weight_sum_GoC_GrC(15 downto 8);
	SYNCND_COMP_GoC_GrC: SYNCND16bit PORT MAP(
		CLK => CLK,
		RST => RST,
		VALID_I => VALID_I_SYNCND,
		VALID_O => VALID_O_SYNCND_GoC_GrC,
		VALID_O_PRE => VALID_O_PRE_SYNCND_GoC_GrC,
		-- Constant --
		INIT => INIT_g_grc,
		tau_syn => tau_syn_GoC_GrC,
		-- Input --
		w_sum => weight_sum_GoC_GrC,
		g_syn_old => g_syn_old_GoC_GrC,
		-- Output --
		g_syn_new => g_syn_new_GoC_GrC
	);

	SYNCND_COMP_GoC_MF: SYNCND16bit PORT MAP(
		CLK => CLK,
		RST => RST,
		VALID_I => VALID_I_SYNCND,
		VALID_O => VALID_O_SYNCND_GoC_MF,
		VALID_O_PRE => VALID_O_PRE_SYNCND_GoC_MF,
		-- Constant --
		INIT => INIT_g_mf,
		tau_syn => tau_syn_GoC_MF,
		-- Input --
		w_sum => weight_sum_GoC_MF,
		g_syn_old => g_syn_old_GoC_MF,
		-- Output --
		g_syn_new => g_syn_new_GoC_MF
	);
-------------------------------------------------------------------------------

--- Calculate SynapticCurrent -------------------------------------------------
  SYNCUR_COMP_GoC_GrC: SYNCUR16bit PORT MAP(
		CLK => CLK,
		RST => RST,
		VALID_I => VALID_I_SYNCUR_GoC_GrC,
		VALID_O => VALID_O_SYNCUR_GoC_GrC,
		-- Constant --,
		v_rev     => v_rev_GoC_GrC,
		-- Input --
		g_syn     => g_syn_new_GoC_GrC,
		v_mb_old  => v_mb_old,
		-- Output --
		i_syn     => i_syn_GoC_GrC
  );

  SYNCUR_COMP_GoC_MF: SYNCUR16bit PORT MAP(
		CLK => CLK,
		RST => RST,
		VALID_I => VALID_I_SYNCUR_GoC_MF,
		VALID_O => VALID_O_SYNCUR_GoC_MF,
		-- Constant --
		v_rev     => v_rev_GoC_MF,
		-- Input --
		g_syn     => g_syn_new_GoC_MF,
		v_mb_old  => v_mb_old,
		-- Output --
		i_syn     => i_syn_GoC_MF
  );

  process(CLK,RST) begin
		if(RST='1') then
			i_syn <= (others=>'0');
		elsif(CLK'event and CLK = '1') then
			if VALID_REG_SUM='1' then
				i_syn <= i_syn_GoC_GrC + i_syn_GoC_MF;
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
	READ_g_syn_GoC_GrC <=
		"1" when (END_SUM_O_GoC_GrC='1' and
		          END_SUM_O_GoC_MF='1') else
		"0";
	WRITE_g_syn_GoC_GrC <=
		g_syn_new_GoC_GrC & '1' when VALID_O_SYNCND_GoC_GrC='1' else
		(others=>'0');
	FIFO_g_syn_GoC_GrC_comp: FIFO_g_syn_GoC_GrC PORT MAP(
		CLK => CLK,
		RST => RST_ADDR,
		hem => hem,
		READ1  => READ_g_syn_GoC_GrC,
		WRITE1 => WRITE_g_syn_GoC_GrC,
		DOUT1  => g_syn_old_GoC_GrC
	);

	READ_g_syn_GoC_MF <=
		"1" when (END_SUM_O_GoC_GrC='1' and
		          END_SUM_O_GoC_MF='1') else
		"0";
	WRITE_g_syn_GoC_MF <=
		g_syn_new_GoC_MF & '1' when VALID_O_SYNCND_GoC_MF='1' else
		(others=>'0');
	FIFO_g_syn_GoC_MF_comp: FIFO_g_syn_GoC_MF PORT MAP(
		CLK => CLK,
		RST => RST_ADDR,
		hem => hem,
		READ1  => READ_g_syn_GoC_MF,
		WRITE1 => WRITE_g_syn_GoC_MF,
		DOUT1  => g_syn_old_GoC_MF
	);

	READ_v_mb  <=
		"1" when (VALID_O_PRE_SYNCND_GoC_GrC='1' and
	            VALID_O_PRE_SYNCND_GoC_MF='1') else
		"0";
	WRITE_v_mb <=
		v_mb_new & '1' when VALID_O_MEMPOT='1' else
		(others=>'0');
	FIFO_v_mb_GoC_comp: FIFO_v_mb_GoC PORT MAP(
		CLK => CLK,
		RST => RST_ADDR,
		hem => hem,
		READ1  => READ_v_mb,
		WRITE1 => WRITE_v_mb,
		DOUT1  => v_mb_old
	);

	WRITE_t_spk <=
		t_spk_new & '1' when VALID_O_MEMPOT='1' else
	  (others=>'0');
	FF_t_spk_GoC_comp: FF_t_spk_GoC PORT MAP(
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

	v_end <= zeros(31 downto 24) & rand(23 downto 0); -- v_end = [0, 1]
	-- mean of Vend = Ispont / C = 36.8 pA / 76.0 pF ~ 0.5
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
