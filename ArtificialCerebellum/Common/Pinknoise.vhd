-------------------------------------------------------------------------------
-- BSD 3-Clause License
-- Copyright (c) 2024, Yusuke Shinji
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_SIGNED.all;

entity Pinknoise is
Port(
	CLK : in  STD_LOGIC;
	RST : in  STD_LOGIC;
	-- Parameter --
	INIT : in  STD_LOGIC_VECTOR(31 downto 0);
	-- Output --
	dout : out STD_LOGIC_VECTOR(22 downto 0)
);
end Pinknoise;

architecture Behavioral of Pinknoise is
	signal ENA_LFSR   : std_logic;
	signal ENA_MULT   : std_logic;
	signal STATE  : std_logic_vector(1 downto 0);
	constant INVALID : std_logic_vector(STATE'range) := "00";
	constant MULT : std_logic_vector(STATE'range) := "01";
	constant ADD  : std_logic_vector(STATE'range) := "10";
	constant HLD  : std_logic_vector(STATE'range) := "11";

	-- LFSR --
	signal INIT_2 : std_logic_vector(31 downto 0);
	signal rand   : std_logic_vector(31 downto 0);
	signal rand_2 : std_logic_vector(31 downto 0);

	-- 1/f --
	signal rand_sign : std_logic_vector(15 downto 0);
	signal data_sign : std_logic_vector(15 downto 0);
	signal data_old  : std_logic_vector(15 downto 0) := (others=>'0');
	signal data_old_delay : std_logic_vector(15 downto 0) := (others=>'0');
	signal data_old_minu  : std_logic_vector(15 downto 0) := (others=>'0');
	signal data_plus : std_logic_vector(31 downto 0) := (others=>'0');
	signal data_minu : std_logic_vector(31 downto 0) := (others=>'0');
	signal data_rnd  : std_logic_vector(15 downto 0) := (others=>'0');
	signal data_new  : std_logic_vector(15 downto 0) := (others=>'0');
	signal zeros     : std_logic_vector(15 downto 0) := (others=>'0');

	constant tau : std_logic_vector(15 downto 0) := "0000000000000001"; --0000000010100011

	COMPONENT LFSR32bit
	PORT(
		CLK : IN  STD_LOGIC;
		RST : IN  STD_LOGIC;
		ENA : IN  STD_LOGIC;
		INIT : IN  STD_LOGIC_VECTOR(31 downto 0);
		LFSR : OUT STD_LOGIC_VECTOR(31 downto 0)
	);
	END COMPONENT;

	COMPONENT MULT_16_16_NoneDSP
	PORT (
		clk : IN STD_LOGIC;
		a   : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		b   : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		ce  : IN STD_LOGIC;
		p   : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
	);
	END COMPONENT;

begin
--- LFSR ----------------------------------------------
	ENA_LFSR <= not(RST);

	uut0 : LFSR32bit
	PORT MAP (
		CLK => CLK,
		RST => RST,
		ENA => ENA_LFSR,
		INIT => INIT,
		LFSR => rand
	);

	INIT_2 <= INIT(15 downto 0) & INIT(31 downto 16);
	uut1 : LFSR32bit
	PORT MAP (
		CLK => CLK,
		RST => RST,
		ENA => ENA_LFSR,
		INIT => INIT_2,
		LFSR => rand_2
	);
-------------------------------------------------------

--- STATE ---------------------------------------------
	process(CLK,RST) begin
		if(RST='1') then
			state <= INVALID;
		elsif(CLK'event and CLK = '1') then
			case state is
				when INVALID =>
					if ENA_LFSR='1' then
						state <= MULT;
					end if;

				when MULT =>
					state <= ADD;

				when ADD =>
					state <= HLD;

				when HLD =>
					state <= INVALID;

				when others =>
					state <= INVALID;
			end case;
		end if;
	end process;
-------------------------------------------------------

--- MULT ----------------------------------------------
	rand_sign <= (others=>rand(15));
	data_sign <= (others=>data_old(15));

	ENA_MULT <= '1' when state=MULT else '0';

	MULT_16_16_NoneDSP_COMP0 : MULT_16_16_NoneDSP
	PORT MAP (
		clk => clk,
		a   => rand(15 downto 0),
		b   => tau,
		ce  => ENA_MULT,
		p   => data_plus
	);

	data_old_minu <= -data_old;
	MULT_16_16_NoneDSP_COMP1 : MULT_16_16_NoneDSP
	PORT MAP (
		clk => clk,
		a   => data_old_minu,
		b   => tau,
		ce  => ENA_MULT,
		p   => data_minu
	);

	process(CLK, RST) begin
		if RST='1' then
			data_old_delay <= (others=>'0');
		elsif rising_edge(CLK) then
			if state=MULT then
				data_old_delay <=	data_old;
			end if;
		end if;
	end process;
-------------------------------------------------------

--- ADD -----------------------------------------------
	process(CLK, RST) begin
		if RST='1' then
			data_new <= (others=>'0');
		elsif rising_edge(CLK) then
			if state=ADD then
				data_new <=
					data_old_delay
					+ data_plus(29 downto 14)
					+ data_minu(29 downto 14);
			end if;
		end if;
	end process;

	process(CLK, RST) begin
		if RST='1' then
			data_rnd <= (others=>'0');
		elsif rising_edge(CLK) then
			if state=ADD then
				if ((('0'&rand(13 downto 0)) <  ('0'&data_plus(13 downto 0))) =
				    (('1'&rand(13 downto 0)) >= ('1'&data_minu(13 downto 0)))) then
					data_rnd <= (0=>'1',others=>'0');
				else
					data_rnd <= (others=>'0');
				end if;
			else
				data_rnd <= (others=>'0');
			end if;
		end if;
	end process;
----------------------------------------------------

--- Hold -------------------------------------------
	process(CLK, RST) begin
		if(RST='1') then
			data_old <= (others=>'0');
		elsif(CLK'event and CLK='1') then
			if(state=HLD) then
				data_old <= data_new + data_rnd;
			end if;
		end if;
	end process;
----------------------------------------------------

--- Output -----------------------------------------
	dout <= data_sign(1 downto 0) & data_old(15 downto 0) & data_sign(4 downto 0);
----------------------------------------------------
end Behavioral;
