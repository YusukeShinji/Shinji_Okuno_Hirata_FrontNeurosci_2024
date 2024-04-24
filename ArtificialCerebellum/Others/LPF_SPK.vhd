-------------------------------------------------------------------------------
-- BSD 3-Clause License
-- Copyright (c) 2024, Yusuke Shinji
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_SIGNED.all;

entity LPF_SPK is
Port(
	CLK : in  STD_LOGIC;
	RST : in  STD_LOGIC;
	VALID_I : in  STD_LOGIC;
	VALID_O : out STD_LOGIC;
	-- Parameter --
	hem      : in  STD_LOGIC;
	tau_mean : in  std_logic_vector(15 downto 0);
	g_mean   : in  std_logic_vector(15 downto 0);
	-- Spike --
	spk       : in  STD_LOGIC_VECTOR(7 downto 0);
	spkmean_L : out STD_LOGIC_VECTOR(31 downto 0);
	spkmean_R : out STD_LOGIC_VECTOR(31 downto 0)
);
end LPF_SPK;

architecture Behavioral of LPF_SPK is
	signal STATE : std_logic_vector(2 downto 0) := (others=>'0');
	constant IDLE : std_logic_vector(STATE'range) := "000";
	constant SUM  : std_logic_vector(STATE'range) := "001";
	constant MUL  : std_logic_vector(STATE'range) := "010";
	constant DIF  : std_logic_vector(STATE'range) := "011";
	constant HLD  : std_logic_vector(STATE'range) := "100";

	signal ENA_MUL : std_logic;

	signal hem_delay0 : std_logic;
	signal hem_delay1 : std_logic;
	signal hem_delay2 : std_logic;
	signal hem_delay3 : std_logic;

	-- Spk --
	signal sum_0       : std_logic_vector(4 downto 0);
	signal sum_1       : std_logic_vector(4 downto 0);
	signal sum_2       : std_logic_vector(4 downto 0);
	signal sum_3       : std_logic_vector(4 downto 0);
	signal spksum      : std_logic_vector(4 downto 0) := (others=>'0');
	signal spkshift    : std_logic_vector(31 downto 0);
	constant zeros     : std_logic_vector(31 downto 0) := (others=>'0');

	signal tau_spk     : std_logic_vector(47 downto 0) := (others=>'0');
	signal g_spk       : std_logic_vector(47 downto 0) := (others=>'0');

	signal rand        : std_logic_vector(31 downto 0);

	signal spkmean_new   : std_logic_vector(31 downto 0) := (others=>'0');
	signal spkmean_old   : std_logic_vector(31 downto 0);
	signal spkmean_old_delay0   : std_logic_vector(31 downto 0) := (others=>'0');
	signal spkmean_old_L : std_logic_vector(31 downto 0) := (others=>'0');
	signal spkmean_old_R : std_logic_vector(31 downto 0) := (others=>'0');
	signal spkmean_rnd   : std_logic_vector(31 downto 0) := (others=>'0');

	-- Constant --
	constant INIT     : std_logic_vector(31 downto 0) := "11110101101001011110111100100011";
	-- constant tau_mean : std_logic_vector(15 downto 0) := "0000000010100011"; -- "0000000101000111"; -- I4.D12 0000111111100100
	-- constant g_mean   : std_logic_vector(15 downto 0) := "0000000010100011"; -- "0000001010001110"; -- I4.D12 Only cerebellum --0000000111111011

	COMPONENT LFSR32bit
	PORT(
		CLK : IN  STD_LOGIC;
		RST : IN  STD_LOGIC;
		ENA : IN  STD_LOGIC;
		INIT : IN  STD_LOGIC_VECTOR(31 downto 0);
		LFSR : OUT STD_LOGIC_VECTOR(31 downto 0)
	);
	END COMPONENT;

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
--- State -----------------------------------------------
	process(CLK, RST) begin
		if RST='1' then
			STATE <= IDLE;
		elsif rising_edge(CLK) then
			case STATE is

				-- Idling
				when IDLE =>
					if VALID_I='1' then
						STATE <= SUM;
					end if;

				-- Low pass filter
				when SUM =>
					STATE <= MUL;
				when MUL =>
					STATE <= DIF;
				when DIF =>
					STATE <= HLD;
				when HLD =>
					STATE <= IDLE;

				-- Exception
				when others =>
					STATE <= IDLE;

			end case;
		end if;
	end process;

	process(CLK, RST) begin
		if rising_edge(CLK) then
			hem_delay0 <= hem;
			hem_delay1 <= hem_delay0;
			hem_delay2 <= hem_delay1;
			hem_delay3 <= hem_delay2;
		end if;
	end process;

--------------------------------------------------------

--- Sum ------------------------------------------------
	sum_0 <= ("0000"&spk(0)) + ("0000"&spk(1));
	sum_1 <= ("0000"&spk(2)) + ("0000"&spk(3));
	sum_2 <= ("0000"&spk(4)) + ("0000"&spk(5));
	sum_3 <= ("0000"&spk(6)) + ("0000"&spk(7));

	process(CLK, RST) begin
		if(RST='1') then
			spksum <= (others=>'0');
		elsif(CLK'event and CLK='1') then
			if(state=SUM) then
				spksum <=  sum_0 + sum_1 + sum_2 + sum_3;
			end if;
		end if;
	end process;

	spkshift <= zeros(10 downto 0) & spksum & zeros(15 downto 0);
--	spkshift <= zeros(11 downto 0) & spksum & zeros(14 downto 0); -- I4.D12
-------------------------------------------------------

--- Mult ----------------------------------------------
	ENA_MUL <= '1' when state=MUL else '0';
	spkmean_old <= spkmean_old_L when hem_delay1='0' else
	               spkmean_old_R when hem_delay1='1' else
	               (others=>'0');

	MULT_32_16_COMP1 : MULT_32_16
	PORT MAP (
		clk => clk,
		a => spkshift,
		b => g_mean,
		ce => ENA_MUL,
		p => g_spk
	);
	MULT_32_16_COMP2 : MULT_32_16
	PORT MAP (
		clk => clk,
		a => spkmean_old,
		b => tau_mean,
		ce => ENA_MUL,
		p => tau_spk
	);

	uut : LFSR32bit
	PORT MAP (
    CLK => CLK,
    RST => RST,
    ENA => ENA_MUL,
    INIT => INIT,
    LFSR => rand
  );

	process(CLK, RST) begin
		if rising_edge(CLK) then
			spkmean_old_delay0 <= spkmean_old;
		end if;
	end process;
----------------------------------------------------

--- Diff -------------------------------------------
	process(CLK, RST) begin
		if RST='1' then
			spkmean_rnd <= (others=>'0');
		elsif rising_edge(CLK) then
			if state=DIF then
				if (('0'&rand(13 downto 0)) <  ('0'&tau_spk(13 downto 0))) =
				   (('1'&rand(13 downto 0)) >= ('1'&g_spk(13 downto 0))) then
					spkmean_rnd <= (0=>'1',others=>'0');
				else
					spkmean_rnd <= (others=>'0');
				end if;
			else
				spkmean_rnd <= (others=>'0');
			end if;
		end if;
	end process;

	process(CLK, RST) begin
		if(RST='1') then
			spkmean_new <= (others=>'0');
		elsif(CLK'event and CLK='1') then
			if(state<=DIF) then
				spkmean_new <= g_spk(45 downto 14) - tau_spk(45 downto 14) + spkmean_old_delay0;
			end if;
		end if;
	end process;
----------------------------------------------------

--- Hold -------------------------------------------
	process(CLK, RST) begin
		if(RST='1') then
			spkmean_old_L <= (others=>'0');
		elsif(CLK'event and CLK='1') then
			if(state<=HLD) then
				if(hem_delay3='0') then
					spkmean_old_L <= spkmean_new + spkmean_rnd;
				end if;
			end if;
		end if;
	end process;

	process(CLK, RST) begin
		if(RST='1') then
			spkmean_old_R <= (others=>'0');
		elsif(CLK'event and CLK='1') then
			if(state<=HLD) then
				if(hem_delay3='1') then
					spkmean_old_R <= spkmean_new + spkmean_rnd;
				end if;
			end if;
		end if;
	end process;
----------------------------------------------------

--- Output -----------------------------------------
	process(CLK, RST) begin
		if(RST='1') then
			VALID_O <= '0';
		elsif(CLK'event and CLK='1') then
			if(state<=HLD) then
				VALID_O <= '1';
			else
				VALID_O <= '0';
			end if;
		end if;
	end process;

	spkmean_L <= spkmean_old_L;
	spkmean_R <= spkmean_old_R;
----------------------------------------------------
end Behavioral;
