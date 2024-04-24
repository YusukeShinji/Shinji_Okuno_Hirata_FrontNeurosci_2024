--------------------------------------------------------------------------------
-- BSD 3-Clause License
-- Copyright (c) 2024, Hirotsugu Okuno
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
--use work.MYPACK.ALL;

entity Timing_Generator_LVDS is
	port(
		CLK40M			: in std_logic;
		RESET			: in std_logic;
		LVDS_RX_ACT		: in std_logic;
		USB_START		: out std_logic;
		STATE			: out std_logic_vector(1 downto 0);
		TIME_COUNT		: out std_logic_vector(15 downto 0);
		FRAME_COUNT		: out std_logic_vector(7 downto 0)
	);
end Timing_Generator_LVDS;

architecture Behavioral of Timing_Generator_LVDS is

	signal rx_act_dly		: std_logic;
	signal rx_act_down		: std_logic;
	signal state_chg		: std_logic;

	-- Counters -------------------------------------------------------------
	signal cnt_base			: std_logic_vector(11 downto 0);
	signal cnt_5us			: std_logic_vector(15 downto 0);
	signal cnt_frame		: std_logic_vector(7 downto 0);

	-- Count limits ----------------------------------------------------------
	constant cnt_base_end	: integer := 200;   -- 5 us
	constant cnt_5us_end	: integer := 200;  -- 1 ms
--	constant cnt_5us_end	: integer := 1600;  -- 8 ms
--	constant cnt_5us_end	: integer := 20000; -- 100 ms
--	constant cnt_base_end	: integer := 10;	-- for debugging
--	constant cnt_5us_end	: integer := 20;	-- for debugging

	-- state -----------------------------------------------------------------
	constant INTERNAL		: STD_LOGIC_VECTOR (1 downto 0) := "00";
	constant EXTERNAL		: STD_LOGIC_VECTOR (1 downto 0) := "01";
	signal state_timing		: STD_LOGIC_VECTOR (1 downto 0);
	signal state_timing_dly	: STD_LOGIC_VECTOR (1 downto 0);

begin

--- state machine ------------------------------------------------------------
	process(CLK40M, RESET) begin
		if(RESET = '1') then
			state_timing <= INTERNAL;
		elsif(rising_edge(CLK40M)) then
			case state_timing is
				when INTERNAL =>
					if(rx_act_down = '1') then
						state_timing <= EXTERNAL;
					end if;
				when EXTERNAL =>
					if(cnt_base = cnt_base_end - 1
					and cnt_5us = cnt_5us_end - 1) then
						state_timing <= INTERNAL;
					end if;
				when others =>
					state_timing <= INTERNAL;
			end case;
		end if;
	end process;
	STATE <= state_timing;

	process(CLK40M) begin
		if(rising_edge(CLK40M))then
			state_timing_dly <= state_timing;
		end if;
	end process;
	state_chg <= '1' when state_timing /= state_timing_dly else '0';

	process(CLK40M) begin
		if(rising_edge(CLK40M))then
			rx_act_dly <= LVDS_RX_ACT;
		end if;
	end process;
	rx_act_down <= not LVDS_RX_ACT and rx_act_dly;

	USB_START <= '1' when ((state_timing = EXTERNAL and rx_act_down = '1')
					or (cnt_base = cnt_base_end - 1 and cnt_5us = cnt_5us_end - 1))
					else '0';
------------------------------------------------------------------------------

--- counters -----------------------------------------------------------------
	process(CLK40M, RESET) begin
		if(RESET = '1') then
			cnt_base <= (others => '0');
		elsif(rising_edge(CLK40M)) then
			if(state_timing = EXTERNAL) then
				if(cnt_base = cnt_base_end - 1 or state_chg = '1'
				or rx_act_down = '1') then
					cnt_base <= (others => '0');
				else
					cnt_base <= cnt_base + 1;
				end if;
			else
				if(cnt_base = cnt_base_end - 1 or state_chg = '1')	then
					cnt_base <= (others => '0');
				else
					cnt_base <= cnt_base + 1;
				end if;
			end if;
		end if;
	end process;

	process(CLK40M, RESET) begin
		if(RESET = '1') then
			cnt_5us <= (others => '0');
		elsif(rising_edge(CLK40M)) then
			if(state_timing = EXTERNAL) then
				if(state_chg = '1' or rx_act_down = '1') then
					cnt_5us <= (others => '0');
				elsif(cnt_base = cnt_base_end - 1) then
					cnt_5us <= cnt_5us + 1;
				end if;
			else
				if(state_chg = '1')	then
					cnt_5us <= (others => '0');
				elsif(cnt_base = cnt_base_end - 1)	then
					if(cnt_5us = cnt_5us_end - 1) then
						cnt_5us <= (others => '0');
					else
						cnt_5us <= cnt_5us + 1;
					end if;
				end if;
			end if;
		end if;
	end process;
	TIME_COUNT <= cnt_5us;

	process(CLK40M, RESET) begin
		if(RESET = '1') then
			cnt_frame <= (others => '0');
		elsif(rising_edge(CLK40M)) then
			if((cnt_base = cnt_base_end -1 and cnt_5us = cnt_5us_end -1)
			or rx_act_down = '1') then
				cnt_frame <= cnt_frame + 1;
			end if;
		end if;
	end process;
	FRAME_COUNT <= cnt_frame;
------------------------------------------------------------------------------

end Behavioral;
