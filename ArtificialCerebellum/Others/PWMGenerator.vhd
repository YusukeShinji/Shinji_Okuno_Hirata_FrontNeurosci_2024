-------------------------------------------------------------------------------
-- BSD 3-Clause License
-- Copyright (c) 2024, Yusuke Shinji
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_SIGNED.all;

entity PWMGenerator is
Port (
	CLK : in  STD_LOGIC;
	RST : in  STD_LOGIC;
	STR : in  STD_LOGIC;
	ENA_SIM : in  STD_LOGIC;
	-- Parameter --
	gain_COM : in  STD_LOGIC_VECTOR(31 downto 0);
	-- Input --
	MANSIG : in  STD_LOGIC_VECTOR(31 downto 0);
	-- Output --
  CONSIG0 : out STD_LOGIC;
	CONSIG1 : out STD_LOGIC
);
end PWMGenerator;

architecture Behavioral of PWMGenerator is
	-- Control --
		signal sqrwav_del : STD_LOGIC_VECTOR(31 downto 0);
--	constant sqrwav_del : STD_LOGIC_VECTOR(31 downto 0)
--		:= "00000000000000000000000110000000"; -- 0.12 [I18.D14]
--	:= "00000000000000000000000000110000"; -- 0.12 [I18.D14]
--	:= "00000000000000000000000000011110"; -- 0.12 [I18.D14]
--	:= "00000000000000000000000001111010"; -- 0.12 [I18.D14]
--	:= "00000000000000000000011110101110"; -- 0.12 [I18.D14]
--	:= "00000000000000000000000000000101"; -- 0.0003 [I18.D14]
--	:= "00000000000000000000000000001101"; -- = min/2 [I18.D14]
	signal sqrwav_min : STD_LOGIC_VECTOR(31 downto 0);
--	constant sqrwav_min : STD_LOGIC_VECTOR(31 downto 0)
--		:= "11111111111101100110011010000000"; -- = -12.0 [I18.D14]
--	:= "11111111111111101100110011001101"; -- = -12.0 [I18.D14]
--	:= "11111111111111110100000000000000"; -- = -12.0 [I18.D14]
--	:= "11111111111111010000000000000000"; -- = -12.0 [I18.D14]
--	:= "11111111111111110000000000000000"; -- = -4.0 [I18.D14]
--	:= "00000000000000000000000000011011"; -- = max/4000/3 [I18.D14] (3 times in dt)
	signal sqrwav_max : STD_LOGIC_VECTOR(31 downto 0);
--	constant sqrwav_max : STD_LOGIC_VECTOR(31 downto 0)
--		:= "00000000000010011001100110000000"; -- = 12.0 [I18.D14]
--	:= "00000000000000010011001100110011"; -- = 12.0 [I18.D14]
--	:= "00000000000000001100000000000000"; -- = 12.0 [I18.D14]
--	:= "00000000000000110000000000000000"; -- = 12.0 [I18.D14]
--	:= "00000000000000010000000000000000"; -- = 4.0 [I18.D14]
--	:= "00000000000000101000000000000000"; -- = 10 [I18.D14] (Maximum value of the Control Signal)

	signal sqrwav     : STD_LOGIC_VECTOR(31 downto 0) := sqrwav_del;
	signal sqrwav_add : STD_LOGIC_VECTOR(31 downto 0) := sqrwav_del;
	signal COMPAR0 : STD_LOGIC;
	signal COMPAR1 : STD_LOGIC;
	signal COMPAR0_delay : STD_LOGIC;
	signal COMPAR1_delay : STD_LOGIC;

	signal cnt_deadtime : STD_LOGIC_VECTOR(8 downto 0) := (others=>'0');
	constant cnt_deadtime_max : STD_LOGIC_VECTOR(8 downto 0) := "000000110"; -- 60ns dt_clock=25ns
	constant cnt_deadtime_min : STD_LOGIC_VECTOR(8 downto 0) := "000000000";
	signal ENA_DT : STD_LOGIC := '0';

	signal CONSIG0_temp : STD_LOGIC := '0';
	signal CONSIG1_temp : STD_LOGIC := '0';

--	COMPONENT MULT_32_16
--	PORT (
--		clk : IN STD_LOGIC;
--		a : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
--		b : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
--		ce : IN STD_LOGIC;
--		p : OUT STD_LOGIC_VECTOR(47 DOWNTO 0)
--	);
--	END COMPONENT;

	constant zeros : STD_LOGIC_VECTOR(31 downto 0) := (others=>'0');
	constant one   : STD_LOGIC_VECTOR(31 downto 0) := (0=>'1',others=>'0');

begin
	process(CLK, RST) begin
		if RST='1' then
			sqrwav_max <= (others=>'0');
		elsif(CLK'event and CLK='1') then
--			if ENA_SIM='0' then
				sqrwav_max <= std_logic_vector(signed(gain_COM));
--			end if;
		end if;
	end process;

	process(CLK, RST) begin
		if RST='1' then
			sqrwav_min <= (others=>'0');
		elsif(CLK'event and CLK='1') then
--			if ENA_SIM='0' then
				sqrwav_min <= std_logic_vector(-signed(gain_COM));
--			end if;
		end if;
	end process;

	process(CLK, RST) begin
		if RST='1' then
			sqrwav_del <= (others=>'0');
		elsif(CLK'event and CLK='1') then
--			if ENA_SIM='0' then
				sqrwav_del <= (zeros(11 downto 0) & std_logic_vector(signed(gain_COM(31 downto 12)))) + one;
--			end if;
		end if;
	end process;

--- Make Squre Wave ------------------------------------------------------------
	process(CLK, RST) begin
		if RST='1' then
			sqrwav <= (others=>'0');
		elsif(CLK'event and CLK='1') then
			sqrwav <= sqrwav + sqrwav_add;
		end if;
	end process;

	process(CLK, RST) begin
		if RST='1' then
			sqrwav_add <= (others=>'0');
		elsif(CLK'event and CLK='1') then
			if sqrwav>sqrwav_max then
				sqrwav_add <= -sqrwav_del;
			elsif sqrwav<sqrwav_min then
				sqrwav_add <=  sqrwav_del;
			end if;
		end if;
	end process;
-------------------------------------------------------------------------------

--- Comparator of square wave and control signal ------------------------------
	process(CLK, RST) begin
		if RST='1' then
			COMPAR0 <= '0';
		elsif(CLK'event and CLK='1') then
			if ((MANSIG     < sqrwav) and
			    (MANSIG(31) = '1')) then
				COMPAR0 <= '1';
			else
				COMPAR0 <= '0';
			end if;
		end if;
	end process;

	process(CLK, RST) begin
		if RST='1' then
			COMPAR1 <= '0';
		elsif(CLK'event and CLK='1') then
			if ((MANSIG     > sqrwav) and
			    (MANSIG(31) = '0')) then
				COMPAR1 <= '1';
			else
				COMPAR1 <= '0';
			end if;
		end if;
	end process;

	process(CLK) begin
		if(CLK'event and CLK='1') then
			COMPAR0_delay <= COMPAR0;
			COMPAR1_delay <= COMPAR1;
		end if;
	end process;
-------------------------------------------------------------------------------

--- Counter of Dead Time ------------------------------------------------------
	process(CLK, RST) begin
		if RST='1' then
			ENA_DT <= '0';
		elsif(CLK'event and CLK='1') then
			if((COMPAR0='1' and CONSIG1_temp='1') or
				 (COMPAR1='1' and CONSIG0_temp='1')) then
				ENA_DT <= '1';
			elsif(cnt_deadtime>=cnt_deadtime_max) then
				ENA_DT <= '0';
			end if;
		end if;
	end process;

	process(CLK, RST) begin
		if RST='1' then
			cnt_deadtime <= (others=>'0');
		elsif(CLK'event and CLK='1') then
			if(ENA_DT='1') then
				cnt_deadtime <= cnt_deadtime + 1;
			else
				cnt_deadtime <= (others=>'0');
			end if;
		end if;
	end process;
-------------------------------------------------------------------------------

--- Output to Inverter --------------------------------------------------------
	process(CLK, RST) begin
		if RST='1' then
			CONSIG0_temp <= '0';
		elsif(CLK'event and CLK='1') then
			if(ENA_SIM='1') then
				if(ENA_DT='1') then
					CONSIG0_temp <= '0';
				else
					CONSIG0_temp <= COMPAR0_delay;
				end if;
			else
				CONSIG0_temp <= '0';
			end if;
		end if;
	end process;

	process(CLK, RST) begin
		if RST='1' then
			CONSIG1_temp <= '0';
		elsif(CLK'event and CLK='1') then
			if(ENA_SIM='1') then
				if(ENA_DT='1') then
					CONSIG1_temp <= '0';
				else
					CONSIG1_temp <= COMPAR1_delay;
				end if;
			else
				CONSIG1_temp <= '0';
			end if;
		end if;
	end process;

	CONSIG0 <= '1' when CONSIG0_temp='1' else '0';
	CONSIG1 <= '1' when CONSIG1_temp='1' else '0';
--	CONSIG0 <= 'Z' when CONSIG0_temp='1' else '0';
--	CONSIG1 <= 'Z' when CONSIG1_temp='1' else '0';
-------------------------------------------------------------------------------
end Behavioral;
