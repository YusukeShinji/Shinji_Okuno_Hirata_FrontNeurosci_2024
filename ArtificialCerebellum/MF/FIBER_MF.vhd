-------------------------------------------------------------------------------
-- BSD 3-Clause License
-- Copyright (c) 2024, Yusuke Shinji
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_SIGNED.ALL;
--use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity FIBER_MF is
Port (
	CLK : in  STD_LOGIC;
	RST : in  STD_LOGIC;
	hem      : in STD_LOGIC;
	RST_ADDR : in  STD_LOGIC;
	VALID_I : in  STD_LOGIC;
	VALID_O : out STD_LOGIC;
	-- Input --
	INIT     : in  STD_LOGIC_VECTOR(31 downto 0);
	i_stim_0 : in  STD_LOGIC_VECTOR(15 downto 0);
	i_stim_1 : in  STD_LOGIC_VECTOR(15 downto 0);
	i_stim_2 : in  STD_LOGIC_VECTOR(15 downto 0);
	i_stim_3 : in  STD_LOGIC_VECTOR(15 downto 0);
	i_stim_4 : in  STD_LOGIC_VECTOR(15 downto 0);
	-- Output --
	t_spk : out STD_LOGIC_VECTOR(245 downto 0)
);
end FIBER_MF;

architecture Behavioral of FIBER_MF is
	-- Valid --
	signal VALID_I_MUX : STD_LOGIC;
	signal VALID_O_MUX : STD_LOGIC;
	signal VALID_O_MUX_PRE : STD_LOGIC;
	signal VALID_I_MEMPOT : STD_LOGIC;
	signal VALID_O_MEMPOT : STD_LOGIC;

	-- Value --
	signal i_syn     : STD_LOGIC_VECTOR(15 downto 0);
	signal v_mb_old  : STD_LOGIC_VECTOR(15 downto 0);
	signal v_mb_new  : STD_LOGIC_VECTOR(15 downto 0);
	signal t_spk_new : STD_LOGIC;

	signal INIT_MUX : STD_LOGIC_VECTOR(31 downto 0);

	-- Constant --
	constant k_inp   : STD_LOGIC_VECTOR(31 downto 0)
		:= "01000000000000000000000000000000";
	constant f_lek : STD_LOGIC_VECTOR(31 downto 0)
		:= "00000001111010111000010100011110";
	constant e_lrt    : STD_LOGIC_VECTOR(31 downto 0)
		:= "10111010000000000000000000000000"; -- 32bit(sign1, int7, dec24)
	constant v_thr    : STD_LOGIC_VECTOR(31 downto 0)
		:= "11001001000000000000000000000000";
	constant v_udr    : STD_LOGIC_VECTOR(31 downto 0)
		:= "10100110000000000000000000000000";
	constant v_rst    : STD_LOGIC_VECTOR(31 downto 0)
		:= "10110000000000000000000000000000";

	signal v_end : STD_LOGIC_VECTOR(31 downto 0);
	signal rand   : STD_LOGIC_VECTOR(31 downto 0);
	constant spont : STD_LOGIC_VECTOR(31 downto 0)
	 := "10000101000111101011100001010010"; -- 20 Hz
	constant zeros : STD_LOGIC_VECTOR(31 downto 0) := (others=>'0');

	-- FIFO --
	signal READ_v_mb  : STD_LOGIC_VECTOR(0 downto 0);
	signal WRITE_v_mb : STD_LOGIC_VECTOR(16 downto 0);

	signal WRITE_t_spk : STD_LOGIC_VECTOR(1 downto 0);
	signal t_spk_all   : STD_LOGIC_VECTOR(245 downto 0);

	COMPONENT MUX_MF
	Port (
		CLK : in  STD_LOGIC;
		RST : in  STD_LOGIC;
		VALID_I : in  STD_LOGIC;
		VALID_O : out STD_LOGIC;
		VALID_O_PRE : out STD_LOGIC;
		-- Constant --
		INIT        : in  STD_LOGIC_VECTOR(31 downto 0);
		-- Input --
		i_stim_0 : in  STD_LOGIC_VECTOR(15 downto 0);
		i_stim_1 : in  STD_LOGIC_VECTOR(15 downto 0);
		i_stim_2 : in  STD_LOGIC_VECTOR(15 downto 0);
		i_stim_3 : in  STD_LOGIC_VECTOR(15 downto 0);
		i_stim_4 : in  STD_LOGIC_VECTOR(15 downto 0);
		-- Output --
		i_syn : out STD_LOGIC_VECTOR(15 downto 0)
	);
	end COMPONENT;

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

	COMPONENT FF_t_spk_MF
	PORT(
		CLK : IN  std_logic;
		RST : IN  std_logic;
		hem    : in STD_LOGIC;
		WRITE1 : IN  std_logic_vector(1 downto 0);
		DOUT1  : OUT std_logic_vector(245 downto 0)
	);
	END COMPONENT;

	COMPONENT FIFO_v_mb_MF
	PORT(
		CLK : IN  std_logic;
		RST : IN  std_logic;
		hem : IN STD_LOGIC;
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
--- Valid Process -------------------------------------------------------------
	VALID_I_MUX <= '1' when VALID_I='1' else
	               '0';
	VALID_I_MEMPOT <= '1' when VALID_O_MUX='1' else
                     '0';
-------------------------------------------------------------------------------

--- Calculate MUX -------------------------------------------------------------
	INIT_MUX <= (INIT(7 downto 0) & INIT(31 downto 8));

	MUX_COMP: MUX_MF Port MAP(
		CLK => CLK,
		RST => RST_ADDR,
		VALID_I => VALID_I_MUX,
		VALID_O => VALID_O_MUX,
		VALID_O_PRE => VALID_O_MUX_PRE,
		-- Constant --
		INIT  => INIT_MUX,
		-- Input --
		i_stim_0 => i_stim_0,
		i_stim_1 => i_stim_1,
		i_stim_2 => i_stim_2,
		i_stim_3 => i_stim_3,
		i_stim_4 => i_stim_4,
		-- Output --
		i_syn => i_syn
	);
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
		v_mb_old  => v_mb_old,
		-- Output --
		v_mb_new  => v_mb_new,
		t_spk_new => t_spk_new
	);
-------------------------------------------------------------------------------

--- Flip Flop -----------------------------------------------------------------
	READ_v_mb  <= "1" when VALID_O_MUX_PRE='1' else
	              "0";
	WRITE_v_mb <= v_mb_new & '1' when VALID_O_MEMPOT='1' else
	              (others=>'0');
	FIFO_v_mb_MF_comp: FIFO_v_mb_MF PORT MAP(
		CLK => CLK,
		RST => RST_ADDR,
		hem   => hem,
		READ1  => READ_v_mb,
		WRITE1 => WRITE_v_mb,
		DOUT1  => v_mb_old
	);

	WRITE_t_spk <= t_spk_new & '1' when VALID_O_MEMPOT='1' else
	               (others=>'0');
	FF_t_spk_MF_comp: FF_t_spk_MF PORT MAP(
		CLK => CLK,
		RST => RST_ADDR,
		hem   => hem,
		WRITE1 => WRITE_t_spk,
		DOUT1  => t_spk_all
	);
-------------------------------------------------------------------------------

--- endogenous ----------------------------------------------------------------
	uut: LFSR32bit PORT MAP (
		CLK => CLK,
		RST => RST,
		ENA => VALID_O_MUX_PRE,
		INIT => INIT,
		LFSR => rand
	);

	v_end <= "00100101100000000000000000000000" when rand < spont else
	         (others=>'0'); --"00000010000001111011011111101001"
	 -- Mf spontfreq = 20 Hz
-------------------------------------------------------------------------------

--- Output --------------------------------------------------------------------
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
