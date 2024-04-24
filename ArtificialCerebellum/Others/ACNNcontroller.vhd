-------------------------------------------------------------------------------
-- BSD 3-Clause License
-- Copyright (c) 2024, Yusuke Shinji
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_SIGNED.all;
use IEEE.std_logic_misc.all;

entity ACNNcontroller is
Port(
	CLK   : in  STD_LOGIC;
	START : in  STD_LOGIC;
	RST   : in  STD_LOGIC;
	-- DIP --
	ENA_DSR        : in  STD_LOGIC_VECTOR(3 downto 0);
	ENA_LEARN      : in  STD_LOGIC;
	ENA_cerebellum : in  STD_LOGIC;
	ENA_PID        : in  STD_LOGIC;
	ENA_LOAD       : in  STD_LOGIC;
	-- Parametar Output --
	LEARN          : out STD_LOGIC;
	START_SIM      : out STD_LOGIC;
	RST_NET        : out STD_LOGIC;
	hem_out        : out STD_LOGIC;
	LOAD           : out STD_LOGIC;
	ENA_SIM_ALL    : out STD_LOGIC;
	-- from Cerebellum --
	VALID_O_PkC    : in  STD_LOGIC;
	spk_pkc        : in  STD_LOGIC_VECTOR(7 downto 0);
	-- from Senser --
	CONMSR         : in  STD_LOGIC_VECTOR(31 downto 0);
	-- from USB --
	freq           : in  STD_LOGIC_VECTOR(15 downto 0);
	amp            : in  STD_LOGIC_VECTOR(15 downto 0);
	g_P            : in  STD_LOGIC_VECTOR(15 downto 0);
	g_D            : in  STD_LOGIC_VECTOR(15 downto 0);
	tau_PkC_LPF    : in  STD_LOGIC_VECTOR(15 downto 0);
	gain_PkC_LPF   : in  STD_LOGIC_VECTOR(15 downto 0);
	-- To Cerebellum --
	wave_MF0       : out STD_LOGIC_VECTOR(15 downto 0);
	wave_MF1       : out STD_LOGIC_VECTOR(15 downto 0);
	wave_MF2       : out STD_LOGIC_VECTOR(15 downto 0);
	wave_MF3       : out STD_LOGIC_VECTOR(15 downto 0);
	wave_MF4       : out STD_LOGIC_VECTOR(15 downto 0);
	wave_CF0       : out STD_LOGIC_VECTOR(15 downto 0);
	-- To USB --
	time_sim_out   : out std_logic_vector(31 downto 0);
	wave_DSR       : out STD_LOGIC_VECTOR(31 downto 0);
	wave_PID       : out STD_LOGIC_VECTOR(31 downto 0);
	wave_ERR       : out STD_LOGIC_VECTOR(31 downto 0);
	wave_spkmean_L : out STD_LOGIC_VECTOR(31 downto 0);
	wave_spkmean_R : out STD_LOGIC_VECTOR(31 downto 0);
	wave_COM       : out STD_LOGIC_VECTOR(31 downto 0)
);
end ACNNcontroller;

architecture Behavioral of ACNNcontroller is
	signal STATE : std_logic_vector(3 downto 0) := (others=>'0');
	constant IDLE     : std_logic_vector(STATE'range) := "0000";
	constant RST_TIME : std_logic_vector(STATE'range) := "0001";
	constant CNT_1ms  : std_logic_vector(STATE'range) := "0010";
	constant CNT_wave : std_logic_vector(STATE'range) := "0011";
	constant STR_COM  : std_logic_vector(STATE'range) := "0100";
	constant STR_SIM  : std_logic_vector(STATE'range) := "1010";
	constant READ_DS  : std_logic_vector(STATE'range) := "1011";

	signal hem       : std_logic := '0';
	signal time_str     : std_logic_vector(31 downto 0) := (others=>'0');
	signal time_str_max : std_logic_vector(31 downto 0) := "00111011100110101100101000000000";
	signal ENA_time_str : std_logic :='0';
	signal ENA_SIM      : std_logic :='0';
	signal LOAD_tmp     : std_logic;

	-- Time Count --
	signal time_1ms  : std_logic_vector(17 downto 0) := (others=>'0');
	signal time_wav  : std_logic_vector(15 downto 0) := (others=>'0');
	signal time_ADDR : std_logic_vector(11 downto 0) := (others=>'0');
	signal time_sim  : std_logic_vector(31 downto 0) := (others=>'0');
	constant period_40kHz : std_logic_vector(time_1ms'range)
	--	:= "011000011010100000"; -- 100,000 clock, clock = 10 ns
		:= "001001110000111111"; -- 40,000 clock, clock = 25 ns
	constant period_80kHz : std_logic_vector(time_1ms'range)
		:= "000100111000011111";
	constant period_wav   : std_logic_vector(time_wav'range)
		:= "0010000000000000"; -- 2**13 ms = 0.12 Hz
--		:= "0010011100010000"; -- 10000 ms = 0.1 Hz
--		:= "0000011111001111"; -- 1/(0.5 Hz) [ms]
	constant start_learn : std_logic_vector(time_sim'range)
			:= (others=>'0');
--		:= "00000000000000000000111010100110"; -- 3.75 s
--		:= "00000000000000001110101001100000"; -- 1 min
	constant start_load : std_logic_vector(time_sim'range)
		:= "00000000000000111010100110000000"; -- 4 min
--		:= "00000000000000101011111100100000"; -- 3 min
--		:= "00000000000000011101010011000000"; -- 2 min
--	constant freq  : STD_LOGIC_VECTOR(15 downto 0) := "0000000000000001";
	constant end_load : std_logic_vector(time_sim'range)
		:= "00000000000001110101001100000000"; -- 8 min
	constant start_load2 : std_logic_vector(time_sim'range)
		:= "00000000000010010010011111000000"; -- 10 min
	constant zeros : std_logic_vector(31 downto 0) := (others=>'0');
	constant ones  : STD_LOGIC_VECTOR(31 downto 0) := (others=>'1');

	-- Desired Value --
	signal ENA_ROM_DSR : STD_LOGIC_VECTOR(3 downto 0);
	signal DSR_vel     : std_logic_vector(31 downto 0) := (others=>'0');
	signal DSR_pos     : std_logic_vector(31 downto 0) := (others=>'0');
	signal DSR_acc     : std_logic_vector(31 downto 0) := (others=>'0');
	signal DSR_amp     : STD_LOGIC_VECTOR(47 downto 0) := (others=>'0');
	signal VALID_O_DSR  : STD_LOGIC;

	-- Spike Mean --
	signal VALID_I_LPF : std_logic;
	signal VALID_O_LPF : std_logic;
	signal spkmean_L : std_logic_vector(31 downto 0);
	signal spkmean_R : std_logic_vector(31 downto 0);

	-- PID --
	signal VALID_I_PID : STD_LOGIC;
	signal VALID_O_PID : STD_LOGIC;
	signal COM_PID : STD_LOGIC_VECTOR(31 downto 0) := (others=>'0');
	signal MSR_acc : STD_LOGIC_VECTOR(31 downto 0) := (others=>'0');
	signal ERR_acc : STD_LOGIC_VECTOR(31 downto 0) := (others=>'0');
	signal ERR_vel : STD_LOGIC_VECTOR(31 downto 0) := (others=>'0');
--	constant g_P     : std_logic_vector(15 downto 0) := "0010100000000000"; --"0000000100000010"; -- I4.D12 --0.06
--	constant g_D     : std_logic_vector(15 downto 0) := "0000000001111101"; --"0000001111101000"; -- I4.D12 --0.06

	-- Command --
	signal DSR_sign  : STD_LOGIC_VECTOR(8 downto 0);
	signal ERR_sign  : STD_LOGIC_VECTOR(8 downto 0);
	signal COM_sign  : STD_LOGIC_VECTOR(8 downto 0);
	signal ERR       : std_logic_vector(31 downto 0) := (others=>'0');
	signal sig_PID_tmp   : std_logic_vector(31 downto 0);
	signal sig_PID   : std_logic_vector(31 downto 0);
	signal sig_CEL   : std_logic_vector(31 downto 0);
	signal COM       : std_logic_vector(31 downto 0) := (others=>'0');

	COMPONENT MULT_32_16
	PORT (
		clk : IN STD_LOGIC;
		a   : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
		b   : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		ce  : IN STD_LOGIC;
		p   : OUT STD_LOGIC_VECTOR(47 DOWNTO 0)
	);
	END COMPONENT;

	COMPONENT ROM_DSR
	Port (
		CLK : in  STD_LOGIC;
		RST : in  STD_LOGIC;
		ENA_DSR  : in  STD_LOGIC_VECTOR(3 downto 0);
		VALID_O  : out STD_LOGIC;
		-- Input --
		amp      : in  STD_LOGIC_VECTOR(15 downto 0);
		time_wav : in  STD_LOGIC_VECTOR(15 downto 0);
		-- Output --
		DSR0     : out STD_LOGIC_VECTOR(31 downto 0);
		DSR1     : out STD_LOGIC_VECTOR(31 downto 0);
		DSR2     : out STD_LOGIC_VECTOR(31 downto 0)
	);
	END COMPONENT;

	COMPONENT LPF_SPK
	PORT(
		CLK : in  STD_LOGIC;
		RST : in  STD_LOGIC;
		VALID_I : in  STD_LOGIC;
		VALID_O : out STD_LOGIC;
		-- Parameter --
		hem       : in  STD_LOGIC;
		tau_mean  : in  STD_LOGIC_VECTOR(15 downto 0);
		g_mean : in  STD_LOGIC_VECTOR(15 downto 0);
		-- Spike --
		spk       : in  STD_LOGIC_VECTOR(7 downto 0);
		spkmean_L : out STD_LOGIC_VECTOR(31 downto 0);
		spkmean_R : out STD_LOGIC_VECTOR(31 downto 0)
	);
	END COMPONENT;

	COMPONENT PID_Controller
	Port (
	  CLK : in  STD_LOGIC;
	  RST : in  STD_LOGIC;
	  VALID_I : in  STD_LOGIC;
	  VALID_O : out STD_LOGIC;
	  -- Parametar --
	  gain_P : in  STD_LOGIC_VECTOR(15 downto 0);
--	  gain_I : in  STD_LOGIC_VECTOR(15 downto 0);
	  gain_D : in  STD_LOGIC_VECTOR(15 downto 0);
	  -- Input --
--	  DSR_pos : in  STD_LOGIC_VECTOR(31 downto 0);
	  DSR_vel : in  STD_LOGIC_VECTOR(31 downto 0);
	  DSR_acc : in  STD_LOGIC_VECTOR(31 downto 0);
	  MSR_vel : in  STD_LOGIC_VECTOR(31 downto 0);
	  -- Output --
	  COM     : out  STD_LOGIC_VECTOR(31 downto 0);
	  MSR_acc : out  STD_LOGIC_VECTOR(31 downto 0);
	  ERR_acc : inout  STD_LOGIC_VECTOR(31 downto 0);
	  ERR_vel : inout  STD_LOGIC_VECTOR(31 downto 0)
	);
	END COMPONENT;

begin
---- Initalization & Learn Mode -----------------------------------------------
	process(CLK, RST) begin
		if(RST='1') then
			RST_NET <= '1';
		elsif(CLK'event and CLK='1') then
			if START='1' then
				RST_NET <= '0';
			end if;
		end if;
	end process;

	process(CLK, RST) begin
		if RST='1' then
			LEARN <= '0';
		elsif(CLK'event and CLK='1') then
			if(time_sim>start_learn and ENA_LEARN='1') then
				LEARN <= '1';
			else
				LEARN <= '0';
			end if;
		end if;
	end process;

	process(CLK, RST) begin
		if RST='1' then
			LOAD <= '0';
		elsif(CLK'event and CLK='1') then
			if(time_sim>start_load2) or
			  ((end_LOAD>=time_sim) and
				 (time_sim>start_LOAD)) then
				if (ENA_LOAD='1') then
					LOAD <= '0';
				else
					LOAD <= '1';
				end if;
			else
				if (ENA_LOAD='1') then
					LOAD <= '1';
				else
					LOAD <= '0';
				end if;
			end if;
		end if;
	end process;

	process(CLK, RST) begin
		if RST='1' then
			ENA_time_str <= '1';
		elsif(CLK'event and CLK='1') then
			if(START='1') then
				ENA_time_str <= '1';
			end if;
		end if;
	end process;

	process(CLK, RST) begin
		if RST='1' then
			time_str <= (others=>'0');
		elsif(CLK'event and CLK='1') then
			if(ENA_time_str='1') then
				time_str <= time_str + 1;
			end if;
		end if;
	end process;

	process(CLK, RST) begin
		if RST='1' then
			ENA_SIM <= '0';
		elsif(CLK'event and CLK='1') then
			if(time_str>=time_str_max) then
				ENA_SIM <= '1';
			end if;
		end if;
	end process;

	ENA_SIM_ALL <= ENA_SIM;
-------------------------------------------------------------------------------

---- State Machne -------------------------------------------------------------
	process(CLK, RST) begin
		if RST='1' then
			STATE <= IDLE;
		elsif rising_edge(CLK) then
			case STATE is

				-- Idling
				when IDLE =>
					if (START='1') and (ENA_SIM='1') then
						STATE <= RST_TIME;
					end if;

				-- Count up Simulation Time
				when RST_TIME =>
					STATE <= READ_DS; -- RST 1ms Time
				when CNT_wave =>
					STATE <= READ_DS; -- Count Wave Time

				-- Error & PID
				when READ_DS =>
					if (VALID_O_DSR='1') then
						STATE <= STR_COM;
					end if;

				-- Command
				when STR_COM =>
					if(VALID_O_PID='1') then
						STATE <= STR_SIM;
					end if;

				-- Count Time to 1 period
				when STR_SIM =>
					STATE <= CNT_1ms;

				-- Count Time to 1ms
				when CNT_1ms =>
					if time_1ms>=period_40kHz then
						if time_wav>=(period_wav - freq) then
							STATE <= RST_TIME;
						else
							STATE <= CNT_wave;
						end if;
					else
						if time_1ms=period_80kHz then
							STATE <= STR_SIM;
						end if;
					end if;

				-- Exception
				when others =>
					STATE <= IDLE;

			end case;
		end if;
	end process;
-------------------------------------------------------------------------------

---- Counter ------------------------------------------------------------------
	process(CLK, RST) begin
		if RST='1' then
			hem <= '0';
		elsif(CLK'event and CLK='1') then
			if time_1ms>=period_40kHz then
				hem <= '0';
			elsif time_1ms=period_80kHz then
				hem <= '1';
			end if;
		end if;
	end process;
--	process(CLK, RST) begin
--		if RST='1' then
--			hem <= '0';
--		elsif(CLK'event and CLK='1') then
--			if STATE=CNT_wave or STATE=RST_TIME then
--				hem <= '0';
--			elsif VALID_O_PkC='1' then
--				hem <= '1';
--			end if;
--		end if;
--	end process;

	process(CLK, RST) begin
		if RST='1' then
			time_1ms <= (others=>'0');
		elsif(CLK'event and CLK='1') then
			case STATE is
				when IDLE     => time_1ms <= (others=>'0');
				when RST_TIME => time_1ms <= (others=>'0');
				when CNT_wave => time_1ms <= (others=>'0');
				when others   => time_1ms <= time_1ms + 1;
			end case;
		end if;
	end process;

	process(CLK, RST) begin
		if RST='1' then
			time_wav <= (others=>'0');
		elsif(CLK'event and CLK='1') then
			case STATE is
				when IDLE     => time_wav <= (others=>'0');
				when RST_TIME => time_wav <= (others=>'0'); --time_wav + freq(15 downto 0) - period_wav;
				when CNT_wave => time_wav <= time_wav + freq(15 downto 0); -- [Hz] = freq / period[ms]/1000
				when others   => null;
			end case;
		end if;
	end process;

	process(CLK, RST) begin
		if RST='1' then
			time_sim <= (others=>'0');
		elsif(CLK'event and CLK='1') then
			case STATE is
				when IDLE     => time_sim <= (others=>'0');
				when RST_TIME => time_sim <= time_sim + 1;
				when CNT_wave => time_sim <= time_sim + 1;
				when others   => null;
			end case;
		end if;
	end process;
-------------------------------------------------------------------------------

--- RAM of desired values -----------------------------------------------------
	process(CLK, RST) begin
		if RST='1' then
			ENA_ROM_DSR <= (others=>'0');
		elsif(CLK'event and CLK='1') then
--			if (STATE=IDLE) or (STATE=RST_TIME) then
--				ENA_ROM_DSR <= (others=>'0');
--			else
				ENA_ROM_DSR <= ENA_DSR;
--			end if;
		end if;
	end process;

	ROM_DSR_comp : ROM_DSR
	port map (
		CLK => CLK,
		RST => RST,
		ENA_DSR  => ENA_ROM_DSR,
		VALID_O  => VALID_O_DSR,
		-- Input --
		amp      => amp,
		time_wav => time_wav,
		-- Output --
		DSR0     => DSR_vel,
		DSR1     => DSR_pos,
		DSR2     => DSR_acc
	);
-------------------------------------------------------------------------------

--- Low pass filter -----------------------------------------------------------
	VALID_I_LPF <= '1' when (ENA_cerebellum='1') and (VALID_O_PkC='1') else '0';
	SPK_PkC_LPF : LPF_SPK
	port map (
		CLK => CLK,
		RST => RST,
		VALID_I => VALID_I_LPF,
		VALID_O => VALID_O_LPF,
		-- Parameter --
		hem       => hem,
		tau_mean  => tau_PkC_LPF,
		g_mean => gain_PkC_LPF,
		-- Spike --
		spk      => spk_pkc,
		spkmean_L => spkmean_L,
		spkmean_R => spkmean_R
	);
-------------------------------------------------------------------------------

--- PID -----------------------------------------------------------------------
	VALID_I_PID <= '1' when STATE=STR_COM else '0';
	PID_Controller_COMP : PID_Controller
	port map (
		CLK => CLK,
		RST => RST,
		VALID_I => VALID_I_PID,
		VALID_O => VALID_O_PID,
		-- Parametar --
		gain_P => g_P,
--		gain_I => open,
		gain_D => g_D,
		-- Input --
		DSR_vel => DSR_vel,
		DSR_acc => DSR_acc,
		MSR_vel => CONMSR,
		-- Output --
		COM     => sig_PID_tmp,
		MSR_acc => MSR_acc,
		ERR_acc => ERR_acc,
		ERR_vel => ERR_vel
	);

	sig_PID <= sig_PID_tmp when ENA_PID='1' else (others=>'0');

--	sig_CEL <= spkmean_L -spkmean_R when ENA_cerebellum ='1' else (others=>'0');
	sig_CEL <= spkmean_L -spkmean_R when ENA_cerebellum ='1' else (others=>'0');

	process(CLK, RST) begin
		if(RST='1') then
			COM <= (others=>'0');
		elsif(CLK'event and CLK='1') then
			if(VALID_O_PID='1') then
				COM <= sig_PID + sig_CEL;
			end if;
		end if;
	end process;
-------------------------------------------------------------------------------

---- Output -------------------------------------------------------------------
	START_SIM <= '1' when STATE=STR_SIM else
	             '0';
	hem_out <= hem;

	-- Output to Cerebellum --
	-- for DCmotor
		-- v9
--	wave_MF0 <= (-DSR_vel(22 downto 7)) when hem='1' else ( DSR_vel(22 downto 7));
--	wave_MF4 <= (-DSR_acc(22 downto 7)) when hem='1' else ( DSR_acc(22 downto 7));
--	wave_MF1 <= (-ERR_vel(21 downto 6)) when hem='1' else ( ERR_vel(21 downto 6));
--	wave_MF3 <= (-ERR_acc(23 downto 8)) when hem='1' else ( ERR_acc(23 downto 8));
--	wave_MF2 <= (-COM(22 downto 7)    ) when hem='1' else ( COM(22 downto 7));
--	wave_CF0 <= ( ERR_vel(21 downto 6)) when hem='1' else (-ERR_vel(21 downto 6));

		-- v8
	wave_MF0 <= (-DSR_vel(24 downto 9) ) when hem='1' else ( DSR_vel(24 downto 9));
	wave_MF4 <= (-DSR_acc(24 downto 9) ) when hem='1' else ( DSR_acc(24 downto 9));
	wave_MF1 <= (-ERR_vel(20 downto 5) ) when hem='1' else ( ERR_vel(20 downto 5));
	wave_MF3 <= (-ERR_acc(24 downto 9) ) when hem='1' else ( ERR_acc(24 downto 9));
	wave_MF2 <= (-COM(24 downto 9)     ) when hem='1' else ( COM(24 downto 9));
	wave_CF0 <= ( ERR_vel(27 downto 12)) when hem='1' else (-ERR_vel(27 downto 12));

	-- for OrientalMotor 30W
--	wave_MF0 <=   DSR_vel(27 downto 12)  when hem='0' else (-DSR_vel(27 downto 12));
--	wave_MF4 <=   DSR_acc(27 downto 12)  when hem='0' else (-DSR_acc(27 downto 12));
--	wave_MF1 <=   ERR_vel(27 downto 12)  when hem='0' else (-ERR_vel(27 downto 12));
--	wave_MF3 <=   ERR_acc(27 downto 12)  when hem='0' else (-ERR_acc(27 downto 12));
--	wave_MF2 <=   COM(27 downto 12)      when hem='0' else (-COM(27 downto 12)    );
--	wave_CF0 <= (-ERR_vel(27 downto 12)) when hem='0' else ( ERR_vel(27 downto 12));

	-- Output to USB --
	time_sim_out   <= time_sim;
	wave_DSR       <= DSR_vel;
	wave_PID       <= sig_PID;
	wave_ERR       <= ERR_vel;
	wave_spkmean_L <= spkmean_L;
	wave_spkmean_R <= spkmean_R;
	wave_COM       <= COM;
-------------------------------------------------------------------------------
end Behavioral;
