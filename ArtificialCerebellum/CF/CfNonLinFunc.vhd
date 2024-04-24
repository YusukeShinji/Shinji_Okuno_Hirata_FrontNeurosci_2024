--------------------------------------------------------------------------------
-- BSD 3-Clause License
-- Copyright (c) 2024, Yusuke Shinji
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_SIGNED.ALL;

entity CfNonLinFunc is
Port (
  CLK : in  STD_LOGIC;
  RST : in  STD_LOGIC;
  VALID_I : in  STD_LOGIC;
  VALID_O : out  STD_LOGIC;
  VALID_O_PRE : out  STD_LOGIC;
  g_cf    : in STD_LOGIC_VECTOR(15 downto 0);
  dc_cf   : in STD_LOGIC_VECTOR(15 downto 0);
  i_syn_I : in  STD_LOGIC_VECTOR (15 downto 0);
  i_syn_O : out  STD_LOGIC_VECTOR (15 downto 0)
);
end CfNonLinFunc;

architecture Behavioral of CfNonLinFunc is
  -- Pipeline Register --
	signal VALID_REG0_GAIN : STD_LOGIC;
	signal VALID_REG1_BIAS : STD_LOGIC;
	signal VALID_REG2_REVS : STD_LOGIC;
	signal VALID_REG3_RAND : STD_LOGIC;
	signal VALID_REG4_SATU : STD_LOGIC;

  -- Signals --
  signal i_syn_delay : STD_LOGIC_VECTOR(15 downto 0);
  signal i_syn_gain  : STD_LOGIC_VECTOR(31 downto 0);
  signal i_syn_bias  : STD_LOGIC_VECTOR(15 downto 0);
  signal i_syn_mins  : STD_LOGIC_VECTOR(15 downto 0);
  signal i_syn_revs  : STD_LOGIC_VECTOR(15 downto 0);
  signal i_syn_rand  : STD_LOGIC_VECTOR(15 downto 0);
  signal i_syn_satu  : STD_LOGIC_VECTOR(15 downto 0);

	signal logi_sat0_delay0 : boolean;
	signal logi_sat0_delay1 : boolean;
	signal logi_sat0_delay2 : boolean;
	signal logi_sat0_delay3 : boolean;
	signal logi_sat1_delay0 : boolean;
	signal logi_sat1_delay1 : boolean;
	signal logi_sat1_delay2 : boolean;
	signal logi_sat1_delay3 : boolean;

  -- Constants --
  constant sat0 : STD_LOGIC_VECTOR(15 downto 0)
    := "1111111111111111";
  constant sat1 : STD_LOGIC_VECTOR(15 downto 0)
    := "0000000000000000";
--  constant gain0 : STD_LOGIC_VECTOR(15 downto 0)
--    := "0000000000000000";
  constant bias0 : STD_LOGIC_VECTOR(15 downto 0)
    := "1111111111011011";

  -- LFSR --
	signal rand   : STD_LOGIC_VECTOR(31 downto 0);
	constant INIT : STD_LOGIC_VECTOR(31 downto 0)
		:= "10111101001011101100010011111100";


	COMPONENT MULT_16_16
  PORT (
    clk : IN STD_LOGIC;
    a   : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    b   : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    ce  : IN STD_LOGIC;
    p   : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
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
	VALID_REG0_GAIN <= '1' when VALID_I='1' else
						         '0';

	process(CLK, RST) begin
		if RST='1' then
			VALID_REG1_BIAS <= '0';
		elsif(CLK'event and CLK='1') then
			if VALID_REG0_GAIN='1' then
				VALID_REG1_BIAS <= '1';
			else
				VALID_REG1_BIAS <= '0';
			end if;
		end if;
	end process;

	process(CLK, RST) begin
		if RST='1' then
			VALID_REG2_REVS <= '0';
		elsif(CLK'event and CLK='1') then
			if VALID_REG1_BIAS='1' then
				VALID_REG2_REVS <= '1';
			else
				VALID_REG2_REVS <= '0';
			end if;
		end if;
	end process;

  process(CLK, RST) begin
    if RST='1' then
      VALID_REG3_RAND <= '0';
    elsif(CLK'event and CLK='1') then
      if VALID_REG2_REVS='1' then
        VALID_REG3_RAND <= '1';
      else
        VALID_REG3_RAND <= '0';
      end if;
    end if;
  end process;

  process(CLK, RST) begin
    if RST='1' then
      VALID_REG4_SATU <= '0';
    elsif(CLK'event and CLK='1') then
      if VALID_REG3_RAND='1' then
        VALID_REG4_SATU <= '1';
      else
        VALID_REG4_SATU <= '0';
      end if;
    end if;
  end process;
-------------------------------------------------------------------------------

--- Delay ---------------------------------------------------------------------
  process(CLK, RST) begin
    if rising_edge(CLK) then
      logi_sat0_delay0 <= (i_syn_I <= sat0);
			logi_sat0_delay1 <= logi_sat0_delay0;
			logi_sat0_delay2 <= logi_sat0_delay1;
			logi_sat0_delay3 <= logi_sat0_delay2;
      logi_sat1_delay0 <= (i_syn_I <= sat1);
			logi_sat1_delay1 <= logi_sat1_delay0;
			logi_sat1_delay2 <= logi_sat1_delay1;
			logi_sat1_delay3 <= logi_sat1_delay2;
    end if;
  end process;
-------------------------------------------------------------------------------

--- Gain  ---------------------------------------------------------------------
  MULT_16_16_COMP1 : MULT_16_16
  PORT MAP (
    clk => clk,
    a => i_syn_I,
    b => g_cf,
    ce => VALID_REG0_GAIN,
    p => i_syn_gain
  );
-------------------------------------------------------------------------------

--- Bias ----------------------------------------------------------------------
	process(CLK, RST) begin
		if RST='1' then
			i_syn_bias <= (others=>'0');
		elsif rising_edge(CLK) then
			if VALID_REG1_BIAS='1' then
				i_syn_bias <= i_syn_gain(31 downto 16) + dc_cf;
			end if;
		end if;
	end process;
-------------------------------------------------------------------------------

--- Reverse -------------------------------------------------------------------
	i_syn_mins <= - i_syn_bias;

	process(CLK, RST) begin
		if RST='1' then
			i_syn_revs <= (others=>'0');
		elsif rising_edge(CLK) then
			if VALID_REG2_REVS='1' then
				if i_syn_bias(15)='1' then
					i_syn_revs <= (i_syn_mins(15) & i_syn_mins(15 downto 1));
        else
          i_syn_revs <= i_syn_bias;
        end if;
			end if;
		end if;
	end process;
-------------------------------------------------------------------------------

--- Random sampling -----------------------------------------------------------
	uut: LFSR32bit PORT MAP (
		CLK => CLK,
		RST => RST,
		ENA => VALID_REG3_RAND,
		INIT => INIT,
		LFSR => rand
	);

	i_syn_rand <= "0010010110000000" when ('0'&rand(14 downto 0)) < i_syn_revs else
	         (others=>'0');
-------------------------------------------------------------------------------

--- Saturation ----------------------------------------------------------------
	process(CLK, RST) begin
		if RST='1' then
			i_syn_satu <= (others=>'0');
		elsif rising_edge(CLK) then
			if VALID_REG4_SATU='1' then
				if logi_sat0_delay3 then
					i_syn_satu <= bias0;
				elsif logi_sat1_delay3 then
					i_syn_satu <= (others=>'0');
        else
          i_syn_satu <= i_syn_rand;
        end if;
			end if;
		end if;
	end process;
-------------------------------------------------------------------------------

--- Output --------------------------------------------------------------------
  process(CLK, RST) begin
    if RST='1' then
      VALID_O <= '0';
    elsif(CLK'event and CLK='1') then
      if VALID_REG4_SATU='1' then
        VALID_O <= '1';
      else
        VALID_O <= '0';
      end if;
    end if;
  end process;

  VALID_O_PRE <= VALID_REG4_SATU;

	i_syn_O <= i_syn_satu;
-------------------------------------------------------------------------------
end Behavioral;
