-------------------------------------------------------------------------------
-- BSD 3-Clause License
-- Copyright (c) 2024, Yusuke Shinji
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_SIGNED.ALL;
--use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.std_logic_misc.all;

entity CELL_PkC is
Port (
	CLK : in  STD_LOGIC;
	RST : in  STD_LOGIC;
	hem   : in  STD_LOGIC;
	LEARN : in  STD_LOGIC;
	RST_ADDR : in  STD_LOGIC;
	VALID_I : in  STD_LOGIC;
	VALID_O : out STD_LOGIC;
	END_SUM_I_PkC_GrC : in STD_LOGIC;
	END_SUM_I_PkC_BkC : in STD_LOGIC;
	-- Constant --
	t_win     : in  STD_LOGIC_VECTOR(31 downto 0);
	g_LTD     : in  STD_LOGIC_VECTOR(31 downto 0);
	g_LTP     : in  STD_LOGIC_VECTOR(31 downto 0);
	INIT      : in  STD_LOGIC_VECTOR(31 downto 0);
	-- Input --
	addr_cell : in STD_LOGIC_VECTOR(2 downto 0);
	addr_syn  : in  STD_LOGIC_VECTOR(9 downto 0);
	t_spk_grc : in  STD_LOGIC_VECTOR(4095 downto 0);
	t_spk_bkc : in  STD_LOGIC_VECTOR(24 downto 0);
	t_spk_cf  : in  STD_LOGIC_VECTOR(7 downto 0);
	-- Output --
	t_spk : out STD_LOGIC_VECTOR(7 downto 0);
	write_weight_syns : out STD_LOGIC_VECTOR(77 downto 0)
	 -- weight0(16) & weight1(16) & weight2(16) & weight3(16) & addr_cell(10) & ENA(1)
);
end CELL_PkC;

architecture Behavioral of CELL_PkC is
	-- Valid --
	signal VALID_I_MUX_PkC_GrC : STD_LOGIC;
	signal VALID_I_MUX_PkC_BkC : STD_LOGIC;
	signal VALID_O_MUX_PkC_GrC : STD_LOGIC_VECTOR(3 downto 0);
	signal VALID_O_MUX_PkC_BkC : STD_LOGIC;
	signal END_SUM_O_PkC_GrC : STD_LOGIC_VECTOR(3 downto 0);
	signal END_SUM_O_PkC_BkC : STD_LOGIC;

	signal END_SUM_O_PkC_GrC_delay : STD_LOGIC;
	signal END_SUM_O_PkC_BkC_delay : STD_LOGIC;

	signal VALID_I_SYNCND : STD_LOGIC;
	signal VALID_O_SYNCND_PkC_GrC : STD_LOGIC;
	signal VALID_O_SYNCND_PkC_BkC : STD_LOGIC;
	signal VALID_O_PRE_SYNCND_PkC_GrC : STD_LOGIC;
	signal VALID_O_PRE_SYNCND_PkC_BkC :STD_LOGIC;

	signal VALID_I_SYNCUR_PkC_GrC : STD_LOGIC;
	signal VALID_O_SYNCUR_PkC_GrC : STD_LOGIC;
	signal VALID_I_SYNCUR_PkC_BkC : STD_LOGIC;
	signal VALID_O_SYNCUR_PkC_BkC : STD_LOGIC;

	signal VALID_REG_SUM : STD_LOGIC;
	signal VALID_I_MEMPOT : STD_LOGIC;
	signal VALID_O_MEMPOT : STD_LOGIC;

	-- Value --
	signal INIT_Cell : STD_LOGIC_VECTOR(31 downto 0);
	signal INIT_g_grc: STD_LOGIC_VECTOR(31 downto 0);
	signal INIT_g_bkc: STD_LOGIC_VECTOR(31 downto 0);

	signal weight_PkC_GrC_0 : STD_LOGIC_VECTOR(15 downto 0);
	signal weight_PkC_GrC_1 : STD_LOGIC_VECTOR(15 downto 0);
	signal weight_PkC_GrC_2 : STD_LOGIC_VECTOR(15 downto 0);
	signal weight_PkC_GrC_3 : STD_LOGIC_VECTOR(15 downto 0);
	signal weight_PkC_BkC : STD_LOGIC_VECTOR(15 downto 0);

	signal WRITE_weight_usb_0 : STD_LOGIC_VECTOR(29 downto 0);
	signal WRITE_weight_usb_1 : STD_LOGIC_VECTOR(29 downto 0);
	signal WRITE_weight_usb_2 : STD_LOGIC_VECTOR(29 downto 0);
	signal WRITE_weight_usb_3 : STD_LOGIC_VECTOR(29 downto 0);

	signal write_weight_0 : STD_LOGIC_VECTOR(26 downto 0);
	signal write_weight_1 : STD_LOGIC_VECTOR(26 downto 0);
	signal write_weight_2 : STD_LOGIC_VECTOR(26 downto 0);
	signal write_weight_3 : STD_LOGIC_VECTOR(26 downto 0);

	signal weight_sum_PkC_GrC_0 : STD_LOGIC_VECTOR(25 downto 0);
	signal weight_sum_PkC_GrC_1 : STD_LOGIC_VECTOR(25 downto 0);
	signal weight_sum_PkC_GrC : STD_LOGIC_VECTOR(25 downto 0) := (others=>'0');
	signal weight_sum_PkC_BkC : STD_LOGIC_VECTOR(15 downto 0) := (others=>'0');

	signal g_syn_old_PkC_GrC : STD_LOGIC_VECTOR(15 downto 0);
	signal g_syn_old_PkC_BkC : STD_LOGIC_VECTOR(15 downto 0);
	signal g_syn_new_PkC_GrC  : STD_LOGIC_VECTOR(15 downto 0);
	signal g_syn_new_PkC_BkC : STD_LOGIC_VECTOR(15 downto 0);

	signal i_syn_PkC_GrC : STD_LOGIC_VECTOR(15 downto 0);
	signal i_syn_PkC_BkC : STD_LOGIC_VECTOR(15 downto 0);
	signal i_syn         : STD_LOGIC_VECTOR(15 downto 0) := (others=>'0');

	signal v_mb_old : STD_LOGIC_VECTOR(15 downto 0);
	signal v_mb_new : STD_LOGIC_VECTOR(15 downto 0);

	signal v_mb_delay0 : STD_LOGIC_VECTOR(15 downto 0);
	signal v_mb_delay1 : STD_LOGIC_VECTOR(15 downto 0);
	signal v_mb_delay2 : STD_LOGIC_VECTOR(15 downto 0);
	signal v_mb_delay3 : STD_LOGIC_VECTOR(15 downto 0);

	signal t_spk_new : STD_LOGIC;

	-- Constant --
	constant weight_mean_PkC_BkC : STD_LOGIC_VECTOR(15 downto 0)
		:= "0000000000000001";
		 --"0000000001000111";
		 --"0000000000010001";
		 --"1111111111101110";
		 --"1111111101111110";
		 --"1111011111101001";
		 --"0000000000010100";
	constant tau_syn_PkC_GrC  : STD_LOGIC_VECTOR(31 downto 0)
		:= "11000000000000000000000000000000";
	constant tau_syn_PkC_BkC  : STD_LOGIC_VECTOR(31 downto 0)
		:= "11011000000000000000000000000000";

	signal gum_LTD : STD_LOGIC_VECTOR(31 downto 0);
	signal gum_LTP : STD_LOGIC_VECTOR(31 downto 0);
--	constant g_LTD : STD_LOGIC_VECTOR(31 downto 0) := "11111111101001000011111111111111"; -- "11111111101001000011111111111111";
--	constant g_LTP : STD_LOGIC_VECTOR(31 downto 0) := "00000000000000000000000000110111";

--	constant g_LTD : STD_LOGIC_VECTOR(31 downto 0) := "11111111111110100100001111111111"; --sqr
--	constant g_LTP : STD_LOGIC_VECTOR(31 downto 0) := "00000000000000000011011111100000"; --sin & sqr

	signal t_win_LTD : STD_LOGIC_VECTOR(31 downto 0);-- := "00110010";

	constant v_rev_PkC_GrC : STD_LOGIC_VECTOR(15 downto 0)
		:= "0000000000000000";
	constant v_rev_PkC_BkC : STD_LOGIC_VECTOR(15 downto 0)
		:= "1011101000000000";

	constant k_inp   : STD_LOGIC_VECTOR(31 downto 0)
		:= "00000000000110100110110100000001";
	constant f_lek : STD_LOGIC_VECTOR(31 downto 0)
		:= "00000000101110001111101100001011";
	constant e_lrt    : STD_LOGIC_VECTOR(31 downto 0)
		:= "11000010000000000000000000000000"; -- 32bit(sign1, int7, dec24)
	constant v_thr    : STD_LOGIC_VECTOR(31 downto 0)
		:= "11010001000000000000000000000000"; -- 32bit(sign1, int7, dec24)
	constant v_udr    : STD_LOGIC_VECTOR(31 downto 0)
		:= "10100110000000000000000000000000"; -- 32bit(sign1, int7, dec24)
	constant v_rst    : STD_LOGIC_VECTOR(31 downto 0)
		:= "10111000000000000000000000000000"; -- 32bit(sign1, int7, dec24)

	signal v_end  : STD_LOGIC_VECTOR(31 downto 0); -- 32bit(sign1, int7, dec24)
	signal rand    : STD_LOGIC_VECTOR(31 downto 0);
	constant zeros : STD_LOGIC_VECTOR(31 downto 0) := (others=>'0');

	-- RAM --
	signal READ_g_syn_PkC_GrC  : STD_LOGIC_VECTOR(0 downto 0);
	signal WRITE_g_syn_PkC_GrC : STD_LOGIC_VECTOR(16 downto 0);

	signal READ_g_syn_PkC_BkC  : STD_LOGIC_VECTOR(0 downto 0);
	signal WRITE_g_syn_PkC_BkC : STD_LOGIC_VECTOR(16 downto 0);

	signal READ_v_mb  : STD_LOGIC_VECTOR(0 downto 0);
	signal WRITE_v_mb : STD_LOGIC_VECTOR(16 downto 0);

	signal WRITE_t_spk : STD_LOGIC_VECTOR(1 downto 0);
	signal t_spk_all : STD_LOGIC_VECTOR(7 downto 0);

	COMPONENT MUX_PkC_GrC_0 is
	Port (
		CLK : in  STD_LOGIC;
		RST : in  STD_LOGIC;
		hem   : in  STD_LOGIC;
		VALID_I : in  STD_LOGIC;
		VALID_O : out STD_LOGIC;
		END_SUM_I : in  STD_LOGIC;
		END_SUM_O : out STD_LOGIC;
		-- Constant --
		Num_MUX : STD_LOGIC_VECTOR(2 downto 0);
--		weight_mean : in  STD_LOGIC_VECTOR(15 downto 0);
		gum_LTD   : in  STD_LOGIC_VECTOR(31 downto 0);
		gum_LTP   : in  STD_LOGIC_VECTOR(31 downto 0);
		t_win     : in  STD_LOGIC_VECTOR(31 downto 0);
		INIT      : in  STD_LOGIC_VECTOR(31 downto 0);
		-- Input --
		addr_cf   : in  STD_LOGIC_VECTOR(2 downto 0);
		addr_grc  : in  STD_LOGIC_VECTOR(9 downto 0);
		spk_grc : in  STD_LOGIC_VECTOR(1023 downto 0);
		spk_cf  : in  STD_LOGIC_VECTOR(7 downto 0);
		-- Output --
		weight_syn : out STD_LOGIC_VECTOR(15 downto 0);
		WRITE_weight_usb : out STD_LOGIC_VECTOR(29 downto 0)
	);
	END COMPONENT;

	COMPONENT MUX_PkC_GrC_1 is
	Port (
		CLK : in  STD_LOGIC;
		RST : in  STD_LOGIC;
		hem   : in  STD_LOGIC;
		VALID_I : in  STD_LOGIC;
		VALID_O : out STD_LOGIC;
		END_SUM_I : in  STD_LOGIC;
		END_SUM_O : out STD_LOGIC;
		-- Constant --
		Num_MUX : STD_LOGIC_VECTOR(2 downto 0);
--		weight_mean : in  STD_LOGIC_VECTOR(15 downto 0);
		gum_LTD   : in  STD_LOGIC_VECTOR(31 downto 0);
		gum_LTP   : in  STD_LOGIC_VECTOR(31 downto 0);
		t_win     : in  STD_LOGIC_VECTOR(31 downto 0);
		INIT      : in  STD_LOGIC_VECTOR(31 downto 0);
		-- Input --
		addr_cf   : in  STD_LOGIC_VECTOR(2 downto 0);
		addr_grc  : in  STD_LOGIC_VECTOR(9 downto 0);
		spk_grc : in  STD_LOGIC_VECTOR(1023 downto 0);
		spk_cf  : in  STD_LOGIC_VECTOR(7 downto 0);
		-- Output --
		weight_syn : out STD_LOGIC_VECTOR(15 downto 0);
		WRITE_weight_usb : out STD_LOGIC_VECTOR(29 downto 0)
	);
	END COMPONENT;

	COMPONENT MUX_PkC_GrC_2 is
	Port (
		CLK : in  STD_LOGIC;
		RST : in  STD_LOGIC;
		hem   : in  STD_LOGIC;
		VALID_I : in  STD_LOGIC;
		VALID_O : out STD_LOGIC;
		END_SUM_I : in  STD_LOGIC;
		END_SUM_O : out STD_LOGIC;
		-- Constant --
		Num_MUX : STD_LOGIC_VECTOR(2 downto 0);
--		weight_mean : in  STD_LOGIC_VECTOR(15 downto 0);
		gum_LTD   : in  STD_LOGIC_VECTOR(31 downto 0);
		gum_LTP   : in  STD_LOGIC_VECTOR(31 downto 0);
		t_win     : in  STD_LOGIC_VECTOR(31 downto 0);
		INIT      : in  STD_LOGIC_VECTOR(31 downto 0);
		-- Input --
		addr_cf   : in  STD_LOGIC_VECTOR(2 downto 0);
		addr_grc  : in  STD_LOGIC_VECTOR(9 downto 0);
		spk_grc : in  STD_LOGIC_VECTOR(1023 downto 0);
		spk_cf  : in  STD_LOGIC_VECTOR(7 downto 0);
		-- Output --
		weight_syn : out STD_LOGIC_VECTOR(15 downto 0);
		WRITE_weight_usb : out STD_LOGIC_VECTOR(29 downto 0)
	);
	END COMPONENT;

	COMPONENT MUX_PkC_GrC_3 is
	Port (
		CLK : in  STD_LOGIC;
		RST : in  STD_LOGIC;
		hem   : in  STD_LOGIC;
		VALID_I : in  STD_LOGIC;
		VALID_O : out STD_LOGIC;
		END_SUM_I : in  STD_LOGIC;
		END_SUM_O : out STD_LOGIC;
		-- Constant --
		Num_MUX : STD_LOGIC_VECTOR(2 downto 0);
--		weight_mean : in  STD_LOGIC_VECTOR(15 downto 0);
		gum_LTD   : in  STD_LOGIC_VECTOR(31 downto 0);
		gum_LTP   : in  STD_LOGIC_VECTOR(31 downto 0);
		t_win     : in  STD_LOGIC_VECTOR(31 downto 0);
		INIT      : in  STD_LOGIC_VECTOR(31 downto 0);
		-- Input --
		addr_cf   : in  STD_LOGIC_VECTOR(2 downto 0);
		addr_grc  : in  STD_LOGIC_VECTOR(9 downto 0);
		spk_grc : in  STD_LOGIC_VECTOR(1023 downto 0);
		spk_cf  : in  STD_LOGIC_VECTOR(7 downto 0);
		-- Output --
		weight_syn : out STD_LOGIC_VECTOR(15 downto 0);
		WRITE_weight_usb : out STD_LOGIC_VECTOR(29 downto 0)
	);
	END COMPONENT;

	COMPONENT MUX_PkC_BkC is
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
		t_spk      : in  STD_LOGIC_VECTOR(24 downto 0);
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

	COMPONENT FIFO_g_syn_PkC_GrC
	PORT(
		CLK : IN  std_logic;
		RST : IN  std_logic;
		hem : IN  std_logic;
		READ1  : IN  std_logic_vector(0 downto 0);
		WRITE1 : IN  std_logic_vector(16 downto 0);
		DOUT1  : OUT std_logic_vector(15 downto 0)
	);
	END COMPONENT;

	COMPONENT FIFO_g_syn_PkC_BkC
	PORT(
		CLK : IN  std_logic;
		RST : IN  std_logic;
		hem : IN  std_logic;
		READ1  : IN  std_logic_vector(0 downto 0);
		WRITE1 : IN  std_logic_vector(16 downto 0);
		DOUT1  : OUT std_logic_vector(15 downto 0)
	);
	END COMPONENT;

	COMPONENT FIFO_v_mb_PkC
	PORT(
		CLK : IN  std_logic;
		RST : IN  std_logic;
		hem : IN  std_logic;
		READ1  : IN  std_logic_vector(0 downto 0);
		WRITE1 : IN  std_logic_vector(16 downto 0);
		DOUT1  : OUT std_logic_vector(15 downto 0)
	);
	END COMPONENT;

	COMPONENT FF_t_spk_PkC
	Port (
	  CLK : in  STD_LOGIC;
	  RST : in  STD_LOGIC;
		hem : in  STD_LOGIC;
	  WRITE1 : in  STD_LOGIC_VECTOR(1 downto 0);
	  DOUT1  : out STD_LOGIC_VECTOR(7 downto 0)
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
--- Parameter -----------------------------------------------------------------
	t_win_LTD <= t_win;
-------------------------------------------------------------------------------

--- Valid  protocol -----------------------------------------------------------
  VALID_I_MUX_PkC_GrC <= '1' when VALID_I='1' else '0';
  VALID_I_MUX_PkC_BkC <= '1' when VALID_I='1' else '0';

	process(CLK, RST) begin
		if(CLK'event and CLK='1') then
				END_SUM_O_PkC_GrC_delay <= and_reduce(END_SUM_O_PkC_GrC);
				END_SUM_O_PkC_BkC_delay <= END_SUM_O_PkC_BkC;
		end if;
	end process;

	process(CLK, RST) begin
    if RST='1' then
      VALID_I_SYNCND <= '0';
    elsif(CLK'event and CLK='1') then
			if( and_reduce(END_SUM_O_PkC_GrC)='1' and
			    END_SUM_O_PkC_BkC='1') then
	      VALID_I_SYNCND <= '1';
				-- Run for only 1 clock
	    else
	      VALID_I_SYNCND <= '0';
	    end if;
		end if;
  end process;

	VALID_I_SYNCUR_PkC_GrC <= '1' when VALID_O_SYNCND_PkC_GrC='1' else '0';
	VALID_I_SYNCUR_PkC_BkC <= '1' when VALID_O_SYNCND_PkC_BkC='1' else '0';

	VALID_REG_SUM <= '1' when(VALID_O_SYNCUR_PkC_GrC='1' and
	                          VALID_O_SYNCUR_PkC_BkC='1') else
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
	INIT_g_bkc <= (INIT_Cell(13 downto 0) & INIT_Cell(31 downto 14));
	gum_LTD <= g_LTD when LEARN='1' else (others=>'0');
	gum_LTP <= g_LTP when LEARN='1' else (others=>'0');
-------------------------------------------------------------------------------

--- Calculate MUX -------------------------------------------------------------
	MUX_PkC_GrC_COMP_0: MUX_PkC_GrC_0 Port MAP(
		CLK => CLK,
		RST => RST_ADDR,
		hem => hem,
		VALID_I => VALID_I_MUX_PkC_GrC,
		VALID_O => VALID_O_MUX_PkC_GrC(0),
		END_SUM_I => END_SUM_I_PkC_GrC,
		END_SUM_O => END_SUM_O_PkC_GrC(0),
		-- Constant --
		INIT    => INIT_Cell,
		Num_MUX => "001",
--		weight_mean => weight_mean_PkC_GrC,
		gum_LTD => gum_LTD,
		gum_LTP => gum_LTP,
		t_win   => t_win_LTD,
		-- Input --
		addr_cf  => addr_cell,
		addr_grc => addr_syn,
		spk_grc => t_spk_grc(1023 downto 0),
		spk_cf  => t_spk_cf,
		-- Output --
		weight_syn => weight_PkC_GrC_0,
		WRITE_weight_usb => WRITE_weight_usb_0
	);

	MUX_PkC_GrC_COMP_1: MUX_PkC_GrC_1 Port MAP(
		CLK => CLK,
		RST => RST_ADDR,
		hem => hem,
		VALID_I => VALID_I_MUX_PkC_GrC,
		VALID_O => VALID_O_MUX_PkC_GrC(1),
		END_SUM_I => END_SUM_I_PkC_GrC,
		END_SUM_O => END_SUM_O_PkC_GrC(1),
		-- Constant --
		INIT    => INIT_Cell,
		Num_MUX => "010",
--		weight_mean => weight_mean_PkC_GrC,
		gum_LTD => gum_LTD,
		gum_LTP => gum_LTP,
		t_win   => t_win_LTD,
		-- Input --
		addr_cf  => addr_cell,
		addr_grc => addr_syn,
		spk_grc => t_spk_grc(2047 downto 1024),
		spk_cf  => t_spk_cf,
		-- Output --
		weight_syn => weight_PkC_GrC_1,
		WRITE_weight_usb => WRITE_weight_usb_1
	);

	MUX_PkC_GrC_COMP_2: MUX_PkC_GrC_2 Port MAP(
		CLK => CLK,
		RST => RST_ADDR,
		hem => hem,
		VALID_I => VALID_I_MUX_PkC_GrC,
		VALID_O => VALID_O_MUX_PkC_GrC(2),
		END_SUM_I => END_SUM_I_PkC_GrC,
		END_SUM_O => END_SUM_O_PkC_GrC(2),
		-- Constant --
		INIT    => INIT_Cell,
		Num_MUX => "011",
--		weight_mean => weight_mean_PkC_GrC,
		gum_LTD => gum_LTD,
		gum_LTP => gum_LTP,
		t_win   => t_win_LTD,
		-- Input --
		addr_cf  => addr_cell,
		addr_grc => addr_syn,
		spk_grc => t_spk_grc(3071 downto 2048),
		spk_cf  => t_spk_cf,
		-- Output --
		weight_syn => weight_PkC_GrC_2,
		WRITE_weight_usb => WRITE_weight_usb_2
	);

	MUX_PkC_GrC_COMP_3: MUX_PkC_GrC_3 Port MAP(
		CLK => CLK,
		RST => RST_ADDR,
		hem => hem,
		VALID_I => VALID_I_MUX_PkC_GrC,
		VALID_O => VALID_O_MUX_PkC_GrC(3),
		END_SUM_I => END_SUM_I_PkC_GrC,
		END_SUM_O => END_SUM_O_PkC_GrC(3),
		-- Constant --
		INIT    => INIT_Cell,
		Num_MUX => "100",
--		weight_mean => weight_mean_PkC_GrC,
		gum_LTD => gum_LTD,
		gum_LTP => gum_LTP,
		t_win   => t_win_LTD,
		-- Input --
		addr_cf  => addr_cell,
		addr_grc => addr_syn,
		spk_grc => t_spk_grc(4095 downto 3072),
		spk_cf  => t_spk_cf,
		-- Output --
		weight_syn => weight_PkC_GrC_3,
		WRITE_weight_usb => WRITE_weight_usb_3
	);

	write_weight_syns <= WRITE_weight_usb_0(29 downto 14) &
	                     WRITE_weight_usb_1(29 downto 14) &
											 WRITE_weight_usb_2(29 downto 14) &
											 WRITE_weight_usb_3(29 downto 14) &
											 WRITE_weight_usb_0(13 downto 11) &
											 WRITE_weight_usb_0(10 downto 1) &
											 (WRITE_weight_usb_0(0) and
											  WRITE_weight_usb_1(0) and
												WRITE_weight_usb_2(0) and
												WRITE_weight_usb_3(0));

	MUX_PkC_BkC_COMP: MUX_PkC_BkC Port MAP(
		CLK => CLK,
		RST => RST_ADDR,
		VALID_I => VALID_I_MUX_PkC_BkC,
		VALID_O => VALID_O_MUX_PkC_BkC,
		END_SUM_I => END_SUM_I_PkC_BkC,
		END_SUM_O => END_SUM_O_PkC_BkC,
		-- Constant --
		weight_mean => weight_mean_PkC_BkC,
		INIT        => INIT_Cell,
		-- Input --
		t_spk    => t_spk_bkc,
		-- Output --
		weight_syn => weight_PkC_BkC
	);
-------------------------------------------------------------------------------

--- Calculate SynapticConductance ---------------------------------------------
	weight_sum_PkC_GrC_0 <= (zeros(9 downto 0)&weight_PkC_GrC_0) + (zeros(9 downto 0)&weight_PkC_GrC_1);
	weight_sum_PkC_GrC_1 <= (zeros(9 downto 0)&weight_PkC_GrC_2) + (zeros(9 downto 0)&weight_PkC_GrC_3);
	process(CLK, RST) begin
		if(RST='1') then
			weight_sum_PkC_GrC <= (others=>'0');
		elsif(CLK'event and CLK='1') then
			if(and_reduce(VALID_O_MUX_PkC_GrC)='1' and END_SUM_O_PkC_GrC_delay='0') then
				if(VALID_I_SYNCND='1') then
					weight_sum_PkC_GrC <= (others=>'0');
				else
					weight_sum_PkC_GrC <=
						weight_sum_PkC_GrC
						+ weight_sum_PkC_GrC_0
						+ weight_sum_PkC_GrC_1;
				end if;
			else
				if(VALID_I_SYNCND='1') then
					weight_sum_PkC_GrC <= (others=>'0');
				end if;
			end if;
		end if;
	end process;

	process(CLK, RST) begin
		if(RST='1') then
			weight_sum_PkC_BkC <= (others=>'0');
		elsif(CLK'event and CLK='1') then
			if(VALID_O_MUX_PkC_BkC='1' and END_SUM_O_PkC_BkC_delay='0') then
				if(VALID_I_SYNCND='1') then
					weight_sum_PkC_BkC <= (others=>'0');
				else
					weight_sum_PkC_BkC <=
						weight_sum_PkC_BkC
						+ weight_PkC_BkC;
				end if;
			else
				if(VALID_I_SYNCND='1') then
					weight_sum_PkC_BkC <= (others=>'0');
				end if;
			end if;
		end if;
	end process;

--	process(CLK, RST) begin
--		if(RST='1') then
--			weight_sum_PkC_GrC <= (others=>'0');
--		elsif(CLK'event and CLK='1') then
--			if(and_reduce(VALID_O_MUX_PkC_GrC)='1' and END_SUM_O_PkC_GrC_delay='0') then
--				if(VALID_I_SYNCND='1') then
--					weight_sum_PkC_GrC <=
--						weight_sum_PkC_GrC_0
--						+ weight_sum_PkC_GrC_1;
--				else
--					weight_sum_PkC_GrC <=
--						weight_sum_PkC_GrC
--						+ weight_sum_PkC_GrC_0
--						+ weight_sum_PkC_GrC_1;
--				end if;
--			else
--				if(VALID_I_SYNCND='1') then
--					weight_sum_PkC_GrC <= (others=>'0');
--				end if;
--			end if;
--		end if;
--	end process;
--
--	process(CLK, RST) begin
--		if(RST='1') then
--			weight_sum_PkC_BkC <= (others=>'0');
--		elsif(CLK'event and CLK='1') then
--			if(VALID_O_MUX_PkC_BkC='1' and END_SUM_O_PkC_BkC_delay='0') then
--				if(VALID_I_SYNCND='1') then
--					weight_sum_PkC_BkC <=
--						weight_PkC_BkC;
--				else
--					weight_sum_PkC_BkC <=
--						weight_sum_PkC_BkC
--						+ weight_PkC_BkC;
--				end if;
--			else
--				if(VALID_I_SYNCND='1') then
--					weight_sum_PkC_BkC <= (others=>'0');
--				end if;
--			end if;
--		end if;
--	end process;

	SYNCND_COMP_PkC_GrC: SYNCND16bit PORT MAP(
		CLK => CLK,
		RST => RST,
		VALID_I => VALID_I_SYNCND,
		VALID_O => VALID_O_SYNCND_PkC_GrC,
		VALID_O_PRE => VALID_O_PRE_SYNCND_PkC_GrC,
		-- Constant --
		INIT => INIT_g_grc,
		tau_syn => tau_syn_PkC_GrC,
		-- Input --
		w_sum => weight_sum_PkC_GrC(15 downto 0),
		--w_sum => weight_sum_PkC_GrC(19 downto 4),
		--w_sum => weight_sum_PkC_GrC(25 downto 10),
		g_syn_old => g_syn_old_PkC_GrC,
		-- Output --
		g_syn_new => g_syn_new_PkC_GrC
	);

	SYNCND_COMP_PkC_BkC: SYNCND16bit PORT MAP(
		CLK => CLK,
		RST => RST,
		VALID_I => VALID_I_SYNCND,
		VALID_O => VALID_O_SYNCND_PkC_BkC,
		VALID_O_PRE => VALID_O_PRE_SYNCND_PkC_BkC,
		-- Constant --
		INIT => INIT_g_bkc,
		tau_syn => tau_syn_PkC_BkC,
		-- Input --
		w_sum => weight_sum_PkC_BkC,
		g_syn_old => g_syn_old_PkC_BkC,
		-- Output --
		g_syn_new => g_syn_new_PkC_BkC
	);
-------------------------------------------------------------------------------

--- Calculate SynapticCurrent -------------------------------------------------
  SYNCUR_COMP_PkC_GrC: SYNCUR16bit PORT MAP(
		CLK => CLK,
		RST => RST,
		VALID_I => VALID_I_SYNCUR_PkC_GrC,
		VALID_O => VALID_O_SYNCUR_PkC_GrC,
		-- Constant --
		v_rev     => v_rev_PkC_GrC,
		-- Input --
		g_syn     => g_syn_new_PkC_GrC,
		v_mb_old  => v_mb_old,
		-- Output --
		i_syn     => i_syn_PkC_GrC
  );

  SYNCUR_COMP_PkC_BkC: SYNCUR16bit PORT MAP(
    CLK => CLK,
    RST => RST,
		VALID_I => VALID_I_SYNCUR_PkC_BkC,
    VALID_O => VALID_O_SYNCUR_PkC_BkC,
		-- Constant --
		v_rev     => v_rev_PkC_BkC,
		-- Input --
		g_syn     => g_syn_new_PkC_BkC,
		v_mb_old  => v_mb_old,
		-- Output --
		i_syn     => i_syn_PkC_BkC
  );

  process(CLK,RST) begin
		if(RST='1') then
			i_syn <= (others=>'0');
		elsif(CLK'event and CLK = '1') then
			if VALID_REG_SUM='1' then
				i_syn <= i_syn_PkC_GrC + i_syn_PkC_BkC;
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

--- Access to FIFO ------------------------------------------------------------
	READ_g_syn_PkC_GrC <=
		"1" when (and_reduce(END_SUM_O_PkC_GrC)='1' and
				      END_SUM_O_PkC_BkC='1') else
		"0";
	WRITE_g_syn_PkC_GrC <=
		g_syn_new_PkC_GrC & '1' when VALID_O_SYNCND_PkC_GrC='1' else
		(others=>'0');
	FIFO_g_syn_PkC_GrC_comp: FIFO_g_syn_PkC_GrC PORT MAP(
		CLK => CLK,
		RST => RST_ADDR,
		hem => hem,
		READ1  => READ_g_syn_PkC_GrC,
		WRITE1 => WRITE_g_syn_PkC_GrC,
		DOUT1  => g_syn_old_PkC_GrC
	);

	READ_g_syn_PkC_BkC <=
		"1" when (and_reduce(END_SUM_O_PkC_GrC)='1' and
				      END_SUM_O_PkC_BkC='1') else
		"0";
	WRITE_g_syn_PkC_BkC <=
		g_syn_new_PkC_BkC & '1' when VALID_O_SYNCND_PkC_BkC='1' else
		(others=>'0');
	FIFO_g_syn_PkC_BkC_comp: FIFO_g_syn_PkC_BkC PORT MAP(
		CLK => CLK,
		RST => RST_ADDR,
		hem => hem,
		READ1  => READ_g_syn_PkC_BkC,
		WRITE1 => WRITE_g_syn_PkC_BkC,
		DOUT1  => g_syn_old_PkC_BkC
	);

  READ_v_mb  <=
		"1" when (VALID_O_PRE_SYNCND_PkC_GrC='1' and
		          VALID_O_PRE_SYNCND_PkC_BkC='1') else
		"0";
  WRITE_v_mb <=
		v_mb_new & '1' when VALID_O_MEMPOT='1' else
		(others=>'0');
  FIFO_v_mb_PkC_comp: FIFO_v_mb_PkC PORT MAP(
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
  FF_t_spk_PkC_comp: FF_t_spk_PkC PORT MAP(
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
	-- mean of Vend = Ispont / C = 600 pA / 620 pF ~ 1
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
