-------------------------------------------------------------------------------
-- BSD 3-Clause License
-- Copyright (c) 2024, Yusuke Shinji
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_SIGNED.ALL;
--use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity CELL_GrC is
Port (
	CLK : in  STD_LOGIC;
	RST : in  STD_LOGIC;
	hem   : in  STD_LOGIC;
	RST_ADDR : in  STD_LOGIC;
	VALID_I : in  STD_LOGIC;
	VALID_O : out STD_LOGIC;
	-- Constant --
	NumProc : in  STD_LOGIC_VECTOR(2 downto 0);
	INIT      : in  STD_LOGIC_VECTOR(31 downto 0);
	-- Input --
	t_spk_mf  : in  STD_LOGIC_VECTOR(245 downto 0);
	t_spk_goc : in  STD_LOGIC_VECTOR(368 downto 0);
	-- Output --
	t_spk   : out STD_LOGIC_VECTOR(1023 downto 0)
);
end CELL_GrC;

architecture Behavioral of CELL_GrC is
	-- Valid --
	signal VALID_I_MUX         : STD_LOGIC;
	signal VALID_O_MUX_GrC_MF  : STD_LOGIC_VECTOR(5 downto 0);
	signal VALID_O_MUX_GrC_GoC : STD_LOGIC_VECTOR(2 downto 0);

--	signal VALID_REG_SUM_GrC_MF : STD_LOGIC;
--	signal VALID_REG_SUM_GrC_GoC : STD_LOGIC;

	signal VALID_I_SYNCND_GrC_MF      : STD_LOGIC;
	signal VALID_O_SYNCND_GrC_MF      : STD_LOGIC;
	signal VALID_O_PRE_SYNCND_GrC_MF  : STD_LOGIC;
	signal VALID_I_SYNCND_GrC_GoC     : STD_LOGIC;
	signal VALID_O_SYNCND_GrC_GoC     : STD_LOGIC;
	signal VALID_O_PRE_SYNCND_GrC_GoC : STD_LOGIC;

	signal VALID_I_SYNCUR_GrC_MF      : STD_LOGIC;
	signal VALID_O_SYNCUR_GrC_MF      : STD_LOGIC;
	signal VALID_I_SYNCUR_GrC_GoC     : STD_LOGIC;
	signal VALID_O_SYNCUR_GrC_GoC     : STD_LOGIC;

	signal VALID_REG_SUM              : STD_LOGIC;

	signal VALID_I_MEMPOT             : STD_LOGIC;
	signal VALID_O_MEMPOT             : STD_LOGIC;

	-- Value --
	signal Num : INTEGER := 0;
	signal INIT_Cell : STD_LOGIC_VECTOR(31 downto 0);
	signal INIT_g_mf : STD_LOGIC_VECTOR(31 downto 0);
	signal INIT_g_goc: STD_LOGIC_VECTOR(31 downto 0);

	type weight_GrC_MF_array is array(5 downto 0) -- Num of Cell
    of STD_LOGIC_VECTOR(15 downto 0);           -- LFSR'range
	signal weight_GrC_MF : weight_GrC_MF_array;

	type weight_GrC_GoC_array is array(2 downto 0) -- Num of Cell
    of STD_LOGIC_VECTOR(15 downto 0);            -- LFSR'range
	signal weight_GrC_GoC : weight_GrC_GoC_array;

	signal weight_GrC_MF_sum0 : STD_LOGIC_VECTOR(15 downto 0);
	signal weight_GrC_MF_sum1 : STD_LOGIC_VECTOR(15 downto 0);
	signal weight_GrC_MF_sum2 : STD_LOGIC_VECTOR(15 downto 0);
	signal weight_sum_GrC_MF  : STD_LOGIC_VECTOR(15 downto 0);
	signal weight_sum_GrC_GoC : STD_LOGIC_VECTOR(15 downto 0);

	signal g_syn_old_GrC_MF  : STD_LOGIC_VECTOR(15 downto 0);
	signal g_syn_old_GrC_GoC : STD_LOGIC_VECTOR(15 downto 0);
	signal g_syn_new_GrC_MF  : STD_LOGIC_VECTOR(15 downto 0);
	signal g_syn_new_GrC_GoC : STD_LOGIC_VECTOR(15 downto 0);

	signal i_syn_GrC_MF  : STD_LOGIC_VECTOR(15 downto 0);
	signal i_syn_GrC_GoC : STD_LOGIC_VECTOR(15 downto 0);
	signal i_syn : STD_LOGIC_VECTOR(15 downto 0);

--	signal INIT_MEMPOT : STD_LOGIC_VECTOR(31 downto 0);
	signal v_mb_old : STD_LOGIC_VECTOR(15 downto 0);
	signal v_mb_new : STD_LOGIC_VECTOR(15 downto 0);

	signal v_mb_delay0 : STD_LOGIC_VECTOR(15 downto 0);
	signal v_mb_delay1 : STD_LOGIC_VECTOR(15 downto 0);
	signal v_mb_delay2 : STD_LOGIC_VECTOR(15 downto 0);
	signal v_mb_delay3 : STD_LOGIC_VECTOR(15 downto 0);

	signal t_spk_new : STD_LOGIC;

	-- Constant --
	constant weight_ampl_GrC_MF  : STD_LOGIC_VECTOR(15 downto 0)
		:= "0000000000000101"; --"0000000000000101"; -- 15bit(sign1, int1, dec14)
	constant weight_mean_GrC_MF  : STD_LOGIC_VECTOR(15 downto 0)
		:= "0000000000101010"; --"0000000000101010"; -- 15bit(sign1, int1, dec14)
	constant weight_mean_GrC_GoC : STD_LOGIC_VECTOR(15 downto 0)
		   := "0000000000000001";
		-- := "0000000000000011"; -- 15bit(sign1, int1, dec14)
		-- := "1111111111111100";
		-- := "1111111111000101";
	constant tau_syn_GrC_MF  : STD_LOGIC_VECTOR(31 downto 0)
		:= "11000000000000000000000000000000"; -- 32bit(sign1, int1, dec30)
	constant tau_syn_GrC_GoC : STD_LOGIC_VECTOR(31 downto 0)
		:= "11111001100110011001100110011010"; -- 32bit(sign1, int1, dec30)

	constant v_rev_GrC_MF  : STD_LOGIC_VECTOR(15 downto 0)
		:= "0000000000000000"; -- 16bit(sign1, int7, dec8)
	constant v_rev_GrC_GoC : STD_LOGIC_VECTOR(15 downto 0)
		:= "1011101000000000"; -- 16bit(sign1, int7, dec8)

	constant k_inp   : STD_LOGIC_VECTOR(31 downto 0)
		:= "00010101010101010101010101010101"; -- 32bit(sign1, int1, dec30)
	constant f_lek : STD_LOGIC_VECTOR(31 downto 0)
		:= "00100000000000000000000000000000"; -- 32bit(sign1, int1, dec30)
	constant e_lrt    : STD_LOGIC_VECTOR(31 downto 0)
		:= "10110110000000000000000000000000"; -- 32bit(sign1, int7, dec24)
	constant v_thr    : STD_LOGIC_VECTOR(31 downto 0)
		:= "11010110000000000000000000000000"; -- 32bit(sign1, int7, dec24)
	constant v_udr    : STD_LOGIC_VECTOR(31 downto 0)
		:= "10100110000000000000000000000000"; -- 32bit(sign1, int7, dec24)
	constant v_rst    : STD_LOGIC_VECTOR(31 downto 0)
		:= "10101100000000000000000000000000"; -- 32bit(sign1, int7, dec24)

	signal v_end  : STD_LOGIC_VECTOR(31 downto 0); -- 32bit(sign1, int7, dec24)
	signal rand    : STD_LOGIC_VECTOR(31 downto 0);
	constant zeros : STD_LOGIC_VECTOR(31 downto 0) := (others=>'0');

	-- FIFO --
	signal READ_g_syn_GrC_MF  : STD_LOGIC_VECTOR(0 downto 0);
	signal WRITE_g_syn_GrC_MF : STD_LOGIC_VECTOR(16 downto 0);

	signal READ_g_syn_GrC_GoC  : STD_LOGIC_VECTOR(0 downto 0);
	signal WRITE_g_syn_GrC_GoC : STD_LOGIC_VECTOR(16 downto 0);

	signal READ_v_mb  : STD_LOGIC_VECTOR(0 downto 0);
	signal WRITE_v_mb : STD_LOGIC_VECTOR(16 downto 0);

	signal WRITE_t_spk : STD_LOGIC_VECTOR(1 downto 0);
	signal t_spk_all   : STD_LOGIC_VECTOR(1023 downto 0);

	-- Component --
  COMPONENT MUX_GrC_MF
	Port (
		CLK : in  STD_LOGIC;
		RST : in  STD_LOGIC;
		VALID_I : in  STD_LOGIC;
		VALID_O : out STD_LOGIC;
		-- Constant --
		Num_MUX : STD_LOGIC_VECTOR(2 downto 0);
		weight_ampl : in  STD_LOGIC_VECTOR(15 downto 0);
		weight_mean : in  STD_LOGIC_VECTOR(15 downto 0);
		INIT    : in  STD_LOGIC_VECTOR(31 downto 0);
		-- Input --
		t_spk   : in  STD_LOGIC_VECTOR(245 downto 0);
		-- Output --
		weight_syn : out STD_LOGIC_VECTOR(15 downto 0)
	);
  END COMPONENT;

  COMPONENT MUX_GrC_GoC
	Port (
		CLK : in  STD_LOGIC;
		RST : in  STD_LOGIC;
		VALID_I : in  STD_LOGIC;
		VALID_O : out  STD_LOGIC;
		-- Constant --
		Num_MUX : STD_LOGIC_VECTOR(2 downto 0);
		weight_mean : in  STD_LOGIC_VECTOR(15 downto 0);
		INIT    : in  STD_LOGIC_VECTOR(31 downto 0);
		-- Input --
		t_spk   : in  STD_LOGIC_VECTOR(368 downto 0);
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
		VALID_O_PRE : OUT STD_LOGIC;
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
		v_rev    : in  STD_LOGIC_VECTOR(15 downto 0);
		-- Input --
		g_syn	   : in  STD_LOGIC_VECTOR(15 downto 0);
		v_mb_old : in  STD_LOGIC_VECTOR(15 downto 0);
		-- Output --
		i_syn    : out  STD_LOGIC_VECTOR(15 downto 0)
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
		i_syn     : in  STD_LOGIC_VECTOR(15 downto 0);
		v_mb_old  : in  STD_LOGIC_VECTOR(15 downto 0);
		-- Outputs --
		v_mb_new  : out STD_LOGIC_VECTOR(15 downto 0);
		t_spk_new : out STD_LOGIC
	);
	END COMPONENT;

	COMPONENT FIFO_g_syn_GrC_MF
	PORT(
		CLK : IN  std_logic;
		RST : IN  std_logic;
		hem   : in  STD_LOGIC;
		READ1  : IN  std_logic_vector(0 downto 0);
		WRITE1 : IN  std_logic_vector(16 downto 0);
		DOUT1  : OUT std_logic_vector(15 downto 0)
	);
	END COMPONENT;

	COMPONENT FIFO_g_syn_GrC_GoC
	PORT(
		CLK : IN  std_logic;
		RST : IN  std_logic;
		hem   : in  STD_LOGIC;
		READ1  : IN  std_logic_vector(0 downto 0);
		WRITE1 : IN  std_logic_vector(16 downto 0);
		DOUT1  : OUT std_logic_vector(15 downto 0)
	);
	END COMPONENT;

  COMPONENT FF_t_spk_GrC
	PORT(
		CLK : IN  std_logic;
		RST : IN  std_logic;
		hem   : in  STD_LOGIC;
		WRITE1 : IN  std_logic_vector(1 downto 0);
		DOUT1  : OUT std_logic_vector(1023 downto 0)
	);
	END COMPONENT;

  COMPONENT FIFO_v_mb_GrC
	PORT(
		CLK : IN  std_logic;
		RST : IN  std_logic;
		hem   : in  STD_LOGIC;
		READ1  : IN  std_logic_vector(0 downto 0);
		WRITE1 : IN  std_logic_vector(16 downto 0);
		DOUT1  : OUT std_logic_vector(15 downto 0)
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
--- State Machine -------------------------------------------------------------
	VALID_I_MUX <= '1' when VALID_I='1' else '0';

	process(CLK, RST) begin
		if(RST='1') then
			VALID_I_SYNCND_GrC_MF <= '0';
		elsif(CLK'event and CLK='1') then
			if(VALID_O_MUX_GrC_MF="111111") then
				VALID_I_SYNCND_GrC_MF <= '1';
			else
				VALID_I_SYNCND_GrC_MF <= '0';
			end if;
		end if;
	end process;

	process(CLK, RST) begin
		if(RST='1') then
			VALID_I_SYNCND_GrC_GoC <= '0';
		elsif(CLK'event and CLK='1') then
			if(VALID_O_MUX_GrC_GoC="111") then
				VALID_I_SYNCND_GrC_GoC <= '1';
			else
				VALID_I_SYNCND_GrC_GoC <= '0';
			end if;
		end if;
	end process;

	VALID_I_SYNCUR_GrC_MF  <= '1' when(VALID_O_SYNCND_GrC_MF='1') else '0';
	VALID_I_SYNCUR_GrC_GoC <= '1' when(VALID_O_SYNCND_GrC_GoC='1') else '0';

	VALID_REG_SUM <= '1' when(VALID_O_SYNCUR_GrC_MF='1' and
	                          VALID_O_SYNCUR_GrC_GoC='1') else '0';

	process(CLK, RST) begin
		if(RST='1') then
			VALID_I_MEMPOT <= '0';
		elsif(CLK'event and CLK='1') then
			if(VALID_REG_SUM='1') then
				VALID_I_MEMPOT <= '1';
			else
				VALID_I_MEMPOT <= '0';
			end if;
		end if;
	end process;
-------------------------------------------------------------------------------

--- Initial of LFSR -----------------------------------------------------------
	Num <= to_integer(unsigned(NumProc));
  INIT_Cell  <= (INIT( abs(Num) downto 0) & INIT(31 downto abs(Num)+1));
  INIT_g_mf  <= (INIT_Cell(17 downto 0)   & INIT_Cell(31 downto 18));
	INIT_g_goc <= (INIT_Cell(13 downto 0)   & INIT_Cell(31 downto 14));
-------------------------------------------------------------------------------

--- Calculate MUX -------------------------------------------------------------
	MUX6 : for i in 0 to 5 generate
		MUX_GrC_MF_COMP: MUX_GrC_MF Port MAP(
			CLK => CLK,
			RST => RST_ADDR,
			VALID_I => VALID_I_MUX,
			VALID_O => VALID_O_MUX_GrC_MF(i),
			-- Constant --
			Num_MUX => std_logic_vector(to_unsigned(i,3)),
			weight_ampl => weight_ampl_GrC_MF,
			weight_mean => weight_mean_GrC_MF,
			INIT  => INIT_Cell,
			-- Input --
			t_spk => t_spk_mf,
			-- Output --
			weight_syn => weight_GrC_MF(i)
		);
	end generate MUX6;

	MUX3 : for i in 0 to 2 generate
	  MUX_GrC_GoC_COMP: MUX_GrC_GoC Port MAP(
			CLK => CLK,
			RST => RST_ADDR,
			VALID_I => VALID_I_MUX,
			VALID_O => VALID_O_MUX_GrC_GoC(i),
			-- Constant --
			Num_MUX => std_logic_vector(to_unsigned(i,3)),
			weight_mean => weight_mean_GrC_GoC,
			INIT  => INIT_Cell,
			-- Input --
			t_spk => t_spk_goc,
			-- Output --
			weight_syn => weight_GrC_GoC(i)
	  );
	end generate MUX3;
-------------------------------------------------------------------------------

--- Calculate SynapticConductance ---------------------------------------------
	weight_GrC_MF_sum0 <= weight_GrC_MF(0) + weight_GrC_MF(1);
	weight_GrC_MF_sum1 <= weight_GrC_MF(2) + weight_GrC_MF(3);
	weight_GrC_MF_sum2 <= weight_GrC_MF(4) + weight_GrC_MF(5);

	process(CLK, RST) begin
		if(RST='1') then
			weight_sum_GrC_MF <= (others=>'0');
		elsif(CLK'event and CLK='1') then
			if(VALID_O_MUX_GrC_MF="111111") then
				weight_sum_GrC_MF <=
					+ weight_GrC_MF_sum0
					+ weight_GrC_MF_sum1
					+ weight_GrC_MF_sum2;
			else
				weight_sum_GrC_MF <= (others=>'0');
			end if;
		end if;
	end process;

	process(CLK, RST) begin
		if(RST='1') then
			weight_sum_GrC_GoC <= (others=>'0');
		elsif(CLK'event and CLK='1') then
			if(VALID_O_MUX_GrC_GoC="111") then
				weight_sum_GrC_GoC <=
					weight_GrC_GoC(0)
					+ weight_GrC_GoC(1)
					+ weight_GrC_GoC(2);
			else
				weight_sum_GrC_GoC <= (others=>'0');
			end if;
		end if;
	end process;

	SYNCND_COMP_GrC_MF: SYNCND16bit PORT MAP(
		CLK => CLK,
		RST => RST,
		VALID_I => VALID_I_SYNCND_GrC_MF,
		VALID_O => VALID_O_SYNCND_GrC_MF,
		VALID_O_PRE => VALID_O_PRE_SYNCND_GrC_MF,
		-- Constant --
		tau_syn => tau_syn_GrC_MF,
		-- Input --
		INIT => INIT_g_mf,
		w_sum => weight_sum_GrC_MF,
		g_syn_old => g_syn_old_GrC_MF,
		-- Output --
		g_syn_new => g_syn_new_GrC_MF
	);

	SYNCND_COMP_GrC_GoC: SYNCND16bit PORT MAP(
		CLK => CLK,
		RST => RST,
		VALID_I => VALID_I_SYNCND_GrC_GoC,
		VALID_O => VALID_O_SYNCND_GrC_GoC,
		VALID_O_PRE => VALID_O_PRE_SYNCND_GrC_GoC,
		-- Constant --
		INIT => INIT_g_goc,
		tau_syn => tau_syn_GrC_GoC,
		-- Input --
		w_sum => weight_sum_GrC_GoC,
		g_syn_old => g_syn_old_GrC_GoC,
		-- Output --
		g_syn_new => g_syn_new_GrC_GoC
	);
-------------------------------------------------------------------------------

--- Calculate SynapticCurrent -------------------------------------------------
  SYNCUR_COMP_GrC_MF: SYNCUR16bit PORT MAP(
    CLK => CLK,
    RST => RST,
    VALID_I => VALID_I_SYNCUR_GrC_MF,
    VALID_O => VALID_O_SYNCUR_GrC_MF,
		-- Constant --
		v_rev     => v_rev_GrC_MF,
		-- Input --
    g_syn     => g_syn_new_GrC_MF,
    v_mb_old  => v_mb_old,
    -- Output --
    i_syn     => i_syn_GrC_MF
  );

  SYNCUR_COMP_GrC_GoC: SYNCUR16bit PORT MAP(
    CLK => CLK,
    RST => RST,
		VALID_I => VALID_I_SYNCUR_GrC_GoC,
    VALID_O => VALID_O_SYNCUR_GrC_GoC,
		-- Constant --
		v_rev     => v_rev_GrC_GoC,
		-- Input --
		g_syn     => g_syn_new_GrC_GoC,
		v_mb_old  => v_mb_old,
		-- Output --
		i_syn     => i_syn_GrC_GoC
  );

  process(CLK,RST) begin
		if(RST='1') then
			i_syn <= (others=>'0');
		elsif(CLK'event and CLK = '1') then
			if VALID_REG_SUM='1' then
				i_syn <= i_syn_GrC_MF + i_syn_GrC_GoC;
			end if;
		end if;
	end process;
-------------------------------------------------------------------------------

--- delay to MEMPOT from SYNCUR -----------------------------------------------
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
  MEMPOT_GrC_COMP: MEMPOT16bit PORT MAP(
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

--- Access to FIFO ------------------------------------------------------------
	READ_g_syn_GrC_MF <=
		"1" when VALID_O_MUX_GrC_MF="111111" else
		"0";
	WRITE_g_syn_GrC_MF <=
		g_syn_new_GrC_MF & '1' when VALID_O_SYNCND_GrC_MF='1' else
		(others=>'0');
	FIFO_g_syn_GrC_MF_comp: FIFO_g_syn_GrC_MF PORT MAP(
		CLK => CLK,
		RST => RST_ADDR,
		hem => hem,
		READ1  => READ_g_syn_GrC_MF,
		WRITE1 => WRITE_g_syn_GrC_MF,
		DOUT1  => g_syn_old_GrC_MF
	);

	READ_g_syn_GrC_GoC <=
		"1" when VALID_O_MUX_GrC_GoC="111" else
		"0";
	WRITE_g_syn_GrC_GoC <=
		g_syn_new_GrC_GoC & '1' when VALID_O_SYNCND_GrC_GoC='1' else
		(others=>'0');
	FIFO_g_syn_GrC_GoC_comp: FIFO_g_syn_GrC_GoC PORT MAP(
		CLK => CLK,
		RST => RST_ADDR,
		hem => hem,
		READ1  => READ_g_syn_GrC_GoC,
		WRITE1 => WRITE_g_syn_GrC_GoC,
		DOUT1  => g_syn_old_GrC_GoC
	);

  READ_v_mb  <= "1" when (VALID_O_PRE_SYNCND_GrC_MF='1' and
                          VALID_O_PRE_SYNCND_GrC_GoC='1') else
                "0";
  WRITE_v_mb <= v_mb_new & '1' when VALID_O_MEMPOT='1' else
                (others=>'0');
	FIFO_v_mb_grc_comp: FIFO_v_mb_GrC PORT MAP(
		CLK => CLK,
		RST => RST_ADDR,
		hem => hem,
		READ1  => READ_v_mb,
		WRITE1 => WRITE_v_mb,
		DOUT1  => v_mb_old
	);

  WRITE_t_spk <= t_spk_new & '1' when VALID_O_MEMPOT='1' else
                 (others=>'0');
	FF_t_spk_grc_comp: FF_t_spk_GrC PORT MAP(
		CLK => CLK,
		RST => RST_ADDR,
		hem => hem,
		WRITE1 => WRITE_t_spk,
		DOUT1  => t_spk_all
	);
-------------------------------------------------------------------------------

--- endogenous ----------------------------------------------------------------
--	uut: LFSR32bit PORT MAP (
--		CLK => CLK,
--		RST => RST,
--		ENA => VALID_O_MUX_PRE,
--		INIT => INIT,
--		LFSR => rand
--	);

--	v_end <= zeros(31 downto 9) & rand(8 downto 0);
	v_end <= zeros(31 downto 0);
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
