-------------------------------------------------------------------------------
-- BSD 3-Clause License
-- Copyright (c) 2024, Yusuke Shinji
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_SIGNED.all;

entity RotaryEncoder5a2 is
Port (
	CLK : in  STD_LOGIC;
	RST : in  STD_LOGIC;
	STR : in  STD_LOGIC;
	hem : in  STD_LOGIC;
	ENA_SIM : in  STD_LOGIC;
	-- Constant --
	tau_MSR  : in  STD_LOGIC_VECTOR(31 downto 0);
	gain_MSR : in  STD_LOGIC_VECTOR(31 downto 0);
	-- Input --
	HALL0  : in  STD_LOGIC;
  HALL1  : in  STD_LOGIC;
  HALL2  : in  STD_LOGIC;
	-- Output --
	CONMSR  : out STD_LOGIC_VECTOR(31 downto 0)
);
end RotaryEncoder5a2;

architecture Behavioral of RotaryEncoder5a2 is
	-- Enable --
	signal ENA          : STD_LOGIC := '0';
	signal STR_delay    : STD_LOGIC := '0';

	-- Cut noise --
	signal HALL0_delay0  : STD_LOGIC;
	signal HALL1_delay0  : STD_LOGIC;
	signal HALL0_delay1  : STD_LOGIC;
	signal HALL1_delay1  : STD_LOGIC;

	-- Rotation --
	signal logi_cw  : boolean;
	signal logi_ccw : boolean;
	signal logi_trn : boolean;

	signal rot0_lock : std_logic;
	signal rot1_lock : std_logic;

	signal rot_dt  : STD_LOGIC_VECTOR(31 downto 0) := (others=>'0'); --
	signal rot     : STD_LOGIC_VECTOR(31 downto 0) := (others=>'0'); -- (S:31, I:30-17, D:16-0)
	signal one_m : STD_LOGIC_VECTOR(31 downto 0);
--	constant one_m : STD_LOGIC_VECTOR(31 downto 0)
--		:= "11111111111111111111010111000100";
--	   "11111111111111111111100110011010";
--	   "11111111111111111111100101001001";
	signal one_p : STD_LOGIC_VECTOR(31 downto 0);
--	constant one_p : STD_LOGIC_VECTOR(31 downto 0)
--		:= "00000000000000000000101000111100";
--	   "00000000000000000000011001100110";
--	   "00000000000000000000011010110111";
--	   "11111111111111110000000000000000"; == -1
--	   "00000000000000010000000000000000"; ==  1 -- True 1/tau_MSR, Now 1*2/80

	signal rot_hold   : std_logic_vector(31 downto 0) := (others=>'0');

	constant zeros : STD_LOGIC_VECTOR(31 downto 0) := (others=>'0');
	constant ones : STD_LOGIC_VECTOR(31 downto 0) := (others=>'1');

	signal logi : STD_LOGIC_VECTOR(2 downto 0);
	constant trn0 : STD_LOGIC_VECTOR(2 downto 0) := "011";
	constant trn1 : STD_LOGIC_VECTOR(2 downto 0) := "101";

	-- Low path Filter
	signal ENA_LPF : STD_LOGIC;
	signal ENA_delay : STD_LOGIC;
	signal rot_old : STD_LOGIC_VECTOR(31 downto 0) := (others=>'0');
	signal rot_delay : STD_LOGIC_VECTOR(31 downto 0);
	signal rot_tau : STD_LOGIC_VECTOR(47 downto 0);

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
	process(CLK, RST) begin
		if RST='1' then
			one_p <= (others=>'0');
		elsif(CLK'event and CLK='1') then
			--if ENA_SIM='0' then
				one_p <= std_logic_vector(signed(gain_MSR));
			--end if;
		end if;
	end process;

	process(CLK, RST) begin
		if RST='1' then
			one_m <= (others=>'0');
		elsif(CLK'event and CLK='1') then
			--if ENA_SIM='0' then
				one_m <= std_logic_vector(-signed(gain_MSR));
			--end if;
		end if;
	end process;

--- Enable ---------------------------------------------------------------------
	process(CLK, RST) begin
		if RST='1' then
			ENA <= '0';
		elsif(CLK'event and CLK='1') then
			if (STR='1') and (hem='1') then
				ENA <= '0';
			else
				ENA <= '1';
			end if;
		end if;
	end process;
--------------------------------------------------------------------------------

--- Counter of Hall Sensor Signal ----------------------------------------------
	process(CLK) begin
		if(CLK'event and CLK='1') then
			HALL0_delay0 <= HALL0;
			HALL1_delay0 <= HALL1;
			HALL0_delay1 <= HALL0_delay0;
			HALL1_delay1 <= HALL1_delay0;
		end if;
	end process;

	logi_cw  <= (HALL0_delay1='1') and (HALL0_delay0='0') and (HALL1_delay0='1');
	logi_ccw <= (HALL1_delay1='1') and (HALL0_delay0='1') and (HALL1_delay0='0');
	logi_trn <= (HALL0_delay0='0') and (HALL1_delay0='0') and (HALL0_delay1='1' or HALL1_delay1='1');

	process(CLK, RST) begin
		if RST='1' then
			rot0_lock <= '0';
		elsif(CLK'event and CLK='1') then
			if logi_cw then
				rot0_lock <= '1';
			elsif logi_trn then
				rot0_lock <= '0';
			end if;
		end if;
	end process;

	process(CLK, RST) begin
		if RST='1' then
			rot1_lock <= '0';
		elsif(CLK'event and CLK='1') then
			if logi_ccw then
				rot1_lock <= '1';
			elsif logi_trn then
				rot1_lock <= '0';
			end if;
		end if;
	end process;

	logi <= (rot1_lock & rot0_lock & '1') when logi_trn else
	        (rot1_lock & rot0_lock & '0');
	process(CLK, RST) begin
		if RST='1' then
			rot <= (others=>'0');
		elsif(CLK'event and CLK='1') then
			if(ENA='1') then
				case logi is
					when trn0 => rot <= rot + one_p;
					when trn1 => rot <= rot + one_m;
					when others => null;
				end case;
			else
				rot <= (others=>'0'); -- Reset to 0 rpm
			end if;
		end if;
	end process;
--------------------------------------------------------------------------------

--- Low path filter ------------------------------------------------------------
	ENA_LPF <= '1' when(ENA='0') else '0';
	MULT_32_16_COMP1 : MULT_32_16
	PORT MAP (
		clk => clk,
		a => rot_old,
		b => tau_MSR(15 downto 0),
		ce => ENA_LPF,
		p => rot_tau
	);

	process(CLK, RST) begin
		if RST='1' then
			rot_old <= (others=>'0');
		elsif(CLK'event and CLK='1') then
			if ENA_delay='0' then
				rot_old <= rot_hold;
			end if;
		end if;
	end process;

	process(CLK, RST) begin
		if(CLK'event and CLK='1') then
			rot_delay <= rot;
			ENA_delay <= ENA;
		end if;
	end process;
--------------------------------------------------------------------------------

--- Output ---------------------------------------------------------------------
	process(CLK, RST) begin
		if RST='1' then
			rot_hold <= (others=>'0');
		elsif(CLK'event and CLK='1') then
			if ENA_delay='0' then
				rot_hold <= rot_delay + rot_tau(45 downto 14);
			end if;
		end if;
	end process;

	CONMSR <= rot_hold;
--------------------------------------------------------------------------------
end Behavioral;
