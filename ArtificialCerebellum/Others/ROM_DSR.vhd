-------------------------------------------------------------------------------
-- BSD 3-Clause License
-- Copyright (c) 2024, Yusuke Shinji
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity ROM_DSR is
Port (
	CLK : in  STD_LOGIC;
	RST : in  STD_LOGIC;
	ENA_DSR  : in  STD_LOGIC_VECTOR(3 downto 0);
	VALID_O  : out STD_LOGIC;
	-- Input --
	amp      : in  STD_LOGIC_VECTOR(15 downto 0);
	time_wav : in  STD_LOGIC_VECTOR(15 downto 0);
	-- Output --
	DSR0      : out STD_LOGIC_VECTOR(31 downto 0); --   0[deg] vel
	DSR1      : out STD_LOGIC_VECTOR(31 downto 0); --  90[deg] pos
	DSR2      : out STD_LOGIC_VECTOR(31 downto 0)  -- -90[deg] acc
);
end ROM_DSR;

architecture Behavioral of ROM_DSR is
	-- state --
	signal state_phase : std_logic_vector(2 downto 0) := (others=>'0');
	signal state_phase_delay0 : std_logic_vector(state_phase'range) := (others=>'0');
	signal state_phase_delay1 : std_logic_vector(state_phase'range) := (others=>'0');
	signal state_phase_delay2 : std_logic_vector(state_phase'range) := (others=>'0');
	signal state_phase_delay3 : std_logic_vector(state_phase'range) := (others=>'0');
	signal state_phase_delay4 : std_logic_vector(state_phase'range) := (others=>'0');
	constant IDLE_phase : std_logic_vector(state_phase'range) := "000";
	constant phase0     : std_logic_vector(state_phase'range) := "001";
	constant phase1     : std_logic_vector(state_phase'range) := "010";
	constant phase2     : std_logic_vector(state_phase'range) := "011";
	constant phase3     : std_logic_vector(state_phase'range) := "100";
	constant END_FLAG   : std_logic_vector(state_phase'range) := "101";

	-- Phase --
	constant period_wav  : std_logic_vector(time_wav'range) := "0010000000000000"; -- 360 deg
	constant time_phase1 : std_logic_vector(time_wav'range) := "0000100000000000"; -- 120 deg
	constant time_phase2 : std_logic_vector(time_wav'range) := "0001000000000000"; -- 240 deg
	-- dec2bin( period_wav / 4, 16, 0) = 90 [deg]
	constant time_wav_phase1 : std_logic_vector(time_wav'range) := period_wav - time_phase1;
	constant time_wav_phase2 : std_logic_vector(time_wav'range) := period_wav - time_phase2;

  -- ROM --
	signal time_ADDR : STD_LOGIC_VECTOR(time_wav'range);
	signal BRAM1_EN_R_sin	: std_logic;	-- enb = R_Enable %% write enable
	signal BRAM1_EN_R_sqr	: std_logic;	-- enb = R_Enable %% write enable
	signal BRAM1_EN_R_tri	: std_logic;	-- enb = R_Enable %% write enable
	signal BRAM1_ADDR	    : std_logic_vector(12 downto 0);	-- addra = R_ADDR	%% read  addres

	signal DOUT1_DSR_sin      : std_logic_vector(22 downto 0) := (others=>'0');
	signal DOUT1_DSR_sqr      : std_logic_vector(22 downto 0) := (others=>'0');
	signal DOUT1_DSR_tri      : std_logic_vector(22 downto 0) := (others=>'0');
	signal DOUT1_DSR_pnk      : std_logic_vector(22 downto 0) := (others=>'0');

	signal DOUT1_DSR_sin_e    : std_logic_vector(22 downto 0) := (others=>'0');
	signal DOUT1_DSR_sqr_e    : std_logic_vector(22 downto 0) := (others=>'0');
	signal DOUT1_DSR_tri_e    : std_logic_vector(22 downto 0) := (others=>'0');
	signal DOUT1_DSR_pnk_e    : std_logic_vector(22 downto 0) := (others=>'0');

	signal DOUT1_DSR          : std_logic_vector(22 downto 0) := (others=>'0');

	-- Mult --
	signal ENA_DSR_MULT : std_logic;
	signal DSR_amp      : std_logic_vector(38 downto 0);
	signal DSR_amp_sign : std_logic_vector(31 downto 0);

  -- Constant --
	constant INIT_pnk  : std_logic_vector(31 downto 0) := "00011100001110110000011110011100";


  component rom_single_wave_sin
	port (
		clka  : IN std_logic;
		ena   : IN std_logic;
		addra : IN std_logic_VECTOR(BRAM1_ADDR'range);
		douta : OUT std_logic_VECTOR(22 downto 0)
	);
	end component;

	component rom_single_wave_sqr
	port (
		clka  : IN std_logic;
		ena   : IN std_logic;
		addra : IN std_logic_VECTOR(BRAM1_ADDR'range);
		douta : OUT std_logic_VECTOR(22 downto 0)
	);
	end component;

	component rom_single_wave_tri
	port (
		clka  : IN std_logic;
		ena   : IN std_logic;
		addra : IN std_logic_VECTOR(BRAM1_ADDR'range);
		douta : OUT std_logic_VECTOR(22 downto 0)
	);
	end component;

	component Pinknoise
	port (
		CLK  : IN std_logic;
	  RST  : IN std_logic;
		INIT : IN std_logic_vector(31 downto 0);
		dout : OUT std_logic_vector(22 downto 0)
	);
	end component;

	COMPONENT MULT_23_16
	PORT (
		clk : IN STD_LOGIC;
		a   : IN STD_LOGIC_VECTOR(22 DOWNTO 0);
		b   : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		ce  : IN STD_LOGIC;
		p   : OUT STD_LOGIC_VECTOR(38 DOWNTO 0)
	);
	END COMPONENT;

begin
--- State ---------------------------------------------------------------------
	process(CLK, RST) begin
		if RST='1' then
			state_phase <= IDLE_phase;
		elsif(CLK'event and CLK='1') then
			case state_phase is
				when IDLE_phase =>
					--if((ENA_DSR(3) or ENA_DSR(2) or ENA_DSR(1) or ENA_DSR(0)) = '1') then
						state_phase <= phase0;
					--end if;
				when phase0 => state_phase <= phase1;
				when phase1 => state_phase <= phase2;
				when phase2 => state_phase <= phase3;
				when phase3 => state_phase <= END_FLAG;
				when END_FLAG => state_phase <= IDLE_phase;
				when others => state_phase <= IDLE_phase;
			end case;
		end if;
	end process;

	process(CLK, RST) begin
		if(CLK'event and CLK='1') then
			state_phase_delay0 <= state_phase;
			state_phase_delay1 <= state_phase_delay0;
			state_phase_delay2 <= state_phase_delay1;
			state_phase_delay3 <= state_phase_delay2;
			state_phase_delay4 <= state_phase_delay3;
		end if;
	end process;
-------------------------------------------------------------------------------

--- Enable --------------------------------------------------------------------
	BRAM1_EN_R_sin <= '1' when (ENA_DSR(3)='1') else '0';
  BRAM1_EN_R_sqr <= '1' when (ENA_DSR(2)='1') else '0';
  BRAM1_EN_R_tri <= '1' when (ENA_DSR(1)='1') else '0';
-------------------------------------------------------------------------------

--- Address -------------------------------------------------------------------
	process(CLK, RST) begin
		if RST='1' then
			time_ADDR <= (others=>'0');
		elsif(CLK'event and CLK='1') then
			case state_phase is
				when phase0 => time_ADDR <= time_wav;
				when phase1 =>
					if(time_wav > time_wav_phase1) then
						time_ADDR <= time_wav - time_wav_phase1;
					else
						time_ADDR <= time_wav + time_phase1;
					end if;
				when phase2 =>
					if(time_wav > time_wav_phase2) then
						time_ADDR <= time_wav - time_wav_phase2;
					else
						time_ADDR <= time_wav + time_phase2;
					end if;
				when others => time_ADDR <= (others=>'0');
			end case;
		end if;
	end process;

	BRAM1_ADDR <=	time_ADDR(12 downto 0);
-------------------------------------------------------------------------------

--- RAM & noise ---------------------------------------------------------------
	ROM_DSR_sin : rom_single_wave_sin
	port map (
		clka => CLK,
		ena => BRAM1_EN_R_sin,
		addra => BRAM1_ADDR,
		douta => DOUT1_DSR_sin
	);

	ROM_DSR_sqr : rom_single_wave_sqr
	port map (
		clka => CLK,
		ena => BRAM1_EN_R_sqr,
		addra => BRAM1_ADDR,
		douta => DOUT1_DSR_sqr
	);

	ROM_DSR_tri : rom_single_wave_tri
	port map (
		clka => CLK,
		ena => BRAM1_EN_R_tri,
		addra => BRAM1_ADDR,
		douta => DOUT1_DSR_tri
	);

	Pinknoise_uut : Pinknoise
	port map (
		CLK => CLK,
		RST => RST,
		INIT => INIT_pnk,
		dout => DOUT1_DSR_pnk
	);
-------------------------------------------------------------------------------

--- Summation -----------------------------------------------------------------
	DOUT1_DSR_sin_e <= DOUT1_DSR_sin when BRAM1_EN_R_sin='1' else (others=>'0');
	DOUT1_DSR_sqr_e <= DOUT1_DSR_sqr when BRAM1_EN_R_sqr='1' else (others=>'0');
	DOUT1_DSR_tri_e <= DOUT1_DSR_tri when BRAM1_EN_R_tri='1' else (others=>'0');
	DOUT1_DSR_pnk_e <= DOUT1_DSR_pnk when ENA_DSR(0)='1' else (others=>'0');

	process(CLK, RST) begin
		if(RST='1') then
			DOUT1_DSR <= (others=>'0');
		elsif(CLK'event and CLK='1') then
			if state_phase_delay1/=IDLE_phase then
				DOUT1_DSR <= DOUT1_DSR_sin_e + DOUT1_DSR_sqr_e + DOUT1_DSR_tri_e + DOUT1_DSR_pnk_e;
			end if;
		end if;
	end process;
-------------------------------------------------------------------------------

--- Mult ----------------------------------------------------------------------
	ENA_DSR_MULT <= '1' when (state_phase_delay2/=IDLE_phase) else '0';
	MULT_23_16_COMP0 : MULT_23_16
	PORT MAP (
		clk => clk,
		a   => DOUT1_DSR,
		b   => amp,
		ce  => ENA_DSR_MULT,
		p   => DSR_amp
	);
	DSR_amp_sign  <= (others=>DSR_amp(38));
-------------------------------------------------------------------------------

--- Output --------------------------------------------------------------------
	process(CLK, RST) begin
		if(RST='1') then
			DSR0 <= (others=>'0');
		elsif(CLK'event and CLK='1') then
			if state_phase_delay3=phase0 then
				DSR0 <= DSR_amp_sign(0 downto 0) & DSR_amp(38 downto 8);
			end if;
		end if;
	end process;

	process(CLK, RST) begin
		if(RST='1') then
			DSR1 <= (others=>'0');
		elsif(CLK'event and CLK='1') then
			if state_phase_delay3=phase1 then
				DSR1 <= DSR_amp_sign(0 downto 0) & DSR_amp(38 downto 8);
			end if;
		end if;
	end process;

	process(CLK, RST) begin
		if(RST='1') then
			DSR2 <= (others=>'0');
		elsif(CLK'event and CLK='1') then
			if state_phase_delay3=phase2 then
				DSR2 <= DSR_amp_sign(0 downto 0) & DSR_amp(38 downto 8);
			end if;
		end if;
	end process;

	process(CLK, RST) begin
		if(RST='1') then
			VALID_O <= '0';
		elsif(CLK'event and CLK='1') then
			if state_phase_delay3=phase2 then
				VALID_O <= '1';
			else
				VALID_O <= '0';
			end if;
		end if;
	end process;
-------------------------------------------------------------------------------
end Behavioral;
