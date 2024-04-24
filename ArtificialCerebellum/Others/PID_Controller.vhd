-------------------------------------------------------------------------------
-- BSD 3-Clause License
-- Copyright (c) 2024, Yusuke Shinji
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity PID_Controller is
Port (
  CLK : in  STD_LOGIC;
  RST : in  STD_LOGIC;
  VALID_I : in  STD_LOGIC;
  VALID_O : out STD_LOGIC;
  -- Parametar --
  gain_P : in  STD_LOGIC_VECTOR(15 downto 0);
--  gain_I : in  STD_LOGIC_VECTOR(15 downto 0);
  gain_D : in  STD_LOGIC_VECTOR(15 downto 0);
  -- Input --
--  DSR_pos : in  STD_LOGIC_VECTOR(31 downto 0);
  DSR_vel : in  STD_LOGIC_VECTOR(31 downto 0);
  DSR_acc : in  STD_LOGIC_VECTOR(31 downto 0);
	MSR_vel : in  STD_LOGIC_VECTOR(31 downto 0);
  -- Output --
  COM     : out  STD_LOGIC_VECTOR(31 downto 0);
  MSR_acc : out  STD_LOGIC_VECTOR(31 downto 0);
  ERR_acc : out  STD_LOGIC_VECTOR(31 downto 0);
  ERR_vel : out  STD_LOGIC_VECTOR(31 downto 0)
);
end PID_Controller;

architecture Behavioral of PID_Controller is
  signal STATE : STD_LOGIC_VECTOR(2 downto 0);
  constant IDLE          : STD_LOGIC_VECTOR(STATE'range) := "000";
  constant ERR_DIF       : STD_LOGIC_VECTOR(STATE'range) := "001";
  constant GAIN_MUL0     : STD_LOGIC_VECTOR(STATE'range) := "010";
  constant GAIN_MUL1     : STD_LOGIC_VECTOR(STATE'range) := "011";
  constant GAIN_MUL_HOLD : STD_LOGIC_VECTOR(STATE'range) := "100";
  constant COM_ADD       : STD_LOGIC_VECTOR(STATE'range) := "101";
  constant END_FLAG      : STD_LOGIC_VECTOR(STATE'range) := "110";

  signal ERR_vel_temp  : std_logic_vector(31 downto 0) := (others=>'0');
--  signal ERR_pos_temp  : std_logic_vector(31 downto 0) := (others=>'0');
  signal ERR_acc_temp  : std_logic_vector(31 downto 0) := (others=>'0');
  signal MSR_delay : std_logic_vector(31 downto 0) := (others=>'0');
  signal MSR_diff  : std_logic_vector(31 downto 0) := (others=>'0');

  signal ENA_PID_MULT0 : std_logic;
	signal ENA_PID_MULT1 : std_logic;
	signal ENA_PID_MULT0_delay : std_logic;
	signal ENA_PID_MULT1_delay : std_logic;

	signal mul_a   : std_logic_vector(31 downto 0);
	signal mul_b   : std_logic_vector(15 downto 0);
	signal mul_ce  : std_logic;
	signal mul_p   : std_logic_vector(47 downto 0);

  signal sig_P     : std_logic_vector(47 downto 0) := (others=>'0');
  signal sig_D     : std_logic_vector(47 downto 0) := (others=>'0');

  COMPONENT MULT_32_16
  PORT (
    clk : IN STD_LOGIC;
    a   : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    b   : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    ce  : IN STD_LOGIC;
    p   : OUT STD_LOGIC_VECTOR(47 DOWNTO 0)
  );
  END COMPONENT;

begin
---- State Machne -------------------------------------------------------------
	process(CLK, RST) begin
		if RST='1' then
			STATE <= IDLE;
		elsif rising_edge(CLK) then
			case STATE is

				-- Idling
				when IDLE =>
					if VALID_I='1' then
						STATE <= ERR_DIF;
					end if;
				when ERR_DIF =>
					STATE <= GAIN_MUL0;
				when GAIN_MUL0 =>
					STATE <= GAIN_MUL1;
				when GAIN_MUL1 =>
					STATE <= GAIN_MUL_HOLD;
				when GAIN_MUL_HOLD =>
					STATE <= COM_ADD;
				when COM_ADD =>
					STATE <= END_FLAG;
				when END_FLAG =>
					STATE <= IDLE;

				-- Exception
				when others =>
					STATE <= IDLE;

			end case;
		end if;
	end process;
-------------------------------------------------------------------------------

--- Error ---------------------------------------------------------------------
	process(CLK, RST) begin
		if(RST='1') then
			ERR_vel_temp <= (others=>'0');
		elsif(CLK'event and CLK='1') then
			if(state=ERR_DIF) then
				ERR_vel_temp <=  DSR_vel - MSR_vel;
			end if;
		end if;
	end process;

	ERR_vel <= ERR_vel_temp;

  process(CLK, RST) begin
    if(RST='1') then
      ERR_acc_temp <= (others=>'0');
    elsif(CLK'event and CLK='1') then
      if(state=ERR_DIF) then
        ERR_acc_temp <=  DSR_acc - MSR_diff;
      end if;
    end if;
  end process;

	ERR_acc <= ERR_acc_temp;
-------------------------------------------------------------------------------

--- MSR_acc -------------------------------------------------------------------
	process(CLK, RST) begin
		if(RST='1') then
			MSR_delay <= (others=>'0');
		elsif(CLK'event and CLK='1') then
			if(state=ERR_DIF) then
				MSR_delay <=  MSR_vel;
			end if;
		end if;
	end process;

	process(CLK, RST) begin
		if(RST='1') then
			MSR_diff <= (others=>'0');
		elsif(CLK'event and CLK='1') then
			if(state=ERR_DIF) then
				MSR_diff <=  MSR_vel - MSR_delay;
			end if;
		end if;
	end process;

  MSR_acc <= MSR_diff;
-------------------------------------------------------------------------------

--- PID  ----------------------------------------------------------------------
  ENA_PID_MULT0 <= '1' when state=GAIN_MUL0 else '0';
  ENA_PID_MULT1 <= '1' when state=GAIN_MUL1 else '0';

  mul_a    <= ERR_vel_temp when ENA_PID_MULT0='1' else ERR_acc_temp;
  mul_b    <= gain_P       when ENA_PID_MULT0='1' else gain_D;
  mul_ce   <= '1'          when (ENA_PID_MULT0='1') or (ENA_PID_MULT1='1') else '0';

  MULT_32_16_COMP1 : MULT_32_16
  PORT MAP (
    clk => clk,
    a => mul_a,
    b => mul_b,
    ce => mul_ce,
    p => mul_p
  );

  process(CLK, RST) begin
    if(CLK'event and CLK='1') then
      ENA_PID_MULT0_delay <= ENA_PID_MULT0;
      ENA_PID_MULT1_delay <= ENA_PID_MULT1;
    end if;
  end process;

  process(CLK, RST) begin
    if(RST='1') then
      sig_P <= (others=>'0');
    elsif(CLK'event and CLK='1') then
      if(ENA_PID_MULT0_delay='1') then
        sig_P <= mul_p;
      end if;
    end if;
  end process;
  process(CLK, RST) begin
    if(RST='1') then
      sig_D <= (others=>'0');
    elsif(CLK'event and CLK='1') then
      if(ENA_PID_MULT1_delay='1') then
        sig_D <= mul_p;
      end if;
    end if;
  end process;


--	ENA_PID_MULT <= '1' when state<=GAIN_MUL else
--	                '0';
--	MULT_32_16_COMP5 : MULT_32_16_NoneDSP
--	PORT MAP (
--		clk => clk,
--		a   => ERR_vel,
--		b   => gain_P,
--		ce  => ENA_PID_MULT,
--		p   => sig_P
--	);
--	MULT_32_16_COMP6 : MULT_32_16_NoneDSP
--	PORT MAP (
--		clk => clk,
--		a   => ERR_acc,
--		b   => gain_D,
--		ce  => ENA_PID_MULT,
--		p   => sig_D
--	);
-------------------------------------------------------------------------------

--- command signal ------------------------------------------------------------
	process(CLK, RST) begin
		if(RST='1') then
			COM <= (others=>'0');
		elsif(CLK'event and CLK='1') then
			if(STATE=COM_ADD) then
				COM <= sig_P(43 downto 12) + sig_D(43 downto 12);
			end if;
		end if;
	end process;

  process(CLK, RST) begin
		if(CLK'event and CLK='1') then
			if(STATE=COM_ADD) then
				VALID_O <= '1';
      else
        VALID_O <= '0';
			end if;
		end if;
	end process;
-------------------------------------------------------------------------------
end Behavioral;
