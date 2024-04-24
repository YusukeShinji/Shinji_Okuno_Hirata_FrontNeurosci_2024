-------------------------------------------------------------------------------
-- BSD 3-Clause License
-- Copyright (c) 2024, Yusuke Shinji
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
--library UNISIM;
--use UNISIM.VComponents.all;
use ieee.std_logic_signed.all;
use IEEE.std_logic_misc.all;

entity Selector_stim is
Port (
	CLK : in STD_LOGIC;
	RST : in STD_LOGIC;
	-- Sim Data --
	hem         : in  STD_LOGIC;
	START_SIM   : in  STD_LOGIC;
	time_sim    : in  STD_LOGIC_VECTOR(31 downto 0);
	CONMSR      : in  STD_LOGIC_VECTOR(31 downto 0);
	COM         : in  STD_LOGIC_VECTOR(31 downto 0);
	ERR         : in  STD_LOGIC_VECTOR(31 downto 0);
	DSR         : in  STD_LOGIC_VECTOR(31 downto 0);
	PID         : in  STD_LOGIC_VECTOR(31 downto 0);
	spkmean_L   : in  STD_LOGIC_VECTOR(31 downto 0);
	spkmean_R   : in  STD_LOGIC_VECTOR(31 downto 0);
	spk_MF      : in  STD_LOGIC_VECTOR(7 downto 0);
	spk_CF      : in  STD_LOGIC_VECTOR(7 downto 0);
	spk_GrC     : in  STD_LOGIC_VECTOR(7 downto 0);
	spk_GoC     : in  STD_LOGIC_VECTOR(7 downto 0);
	spk_PkC     : in  STD_LOGIC_VECTOR(7 downto 0);
	spk_BkC     : in  STD_LOGIC_VECTOR(7 downto 0);
	-- To RAM --
	WOUT1 : out  STD_LOGIC_VECTOR(28 downto 0)
);
end Selector_stim;

architecture Behavioral of Selector_stim is
	-- state --
	signal state : std_logic_vector(1 downto 0);
	constant INVALID    : std_logic_vector(1 downto 0) := "00";
	constant SET        : std_logic_vector(1 downto 0) := "01";
	constant CNT_ADDR_X : std_logic_vector(1 downto 0) := "10";
	constant READING    : std_logic_vector(1 downto 0) := "11";

	--counter --
	signal addr_x : INTEGER := 0;

	signal addr_x_INIT : INTEGER := 0;
	constant addr_x_INIT_stim_L : INTEGER := 0;
	constant addr_x_INIT_stim_R : INTEGER := 50;

	signal addr_x_max  : INTEGER := 0;
	constant addr_x_max_stim_L : INTEGER := 38;
	constant addr_x_max_Stim_R : INTEGER := 88;

	-- MUX --
	signal addr_l : integer := 0;
	signal addr_m : integer := 0;

	signal data_weight_pkc : std_logic_vector(   7 downto 0);
	signal data_Stim       : std_logic_vector( 311 downto 0);
	constant zeros7 : std_logic_vector(6 downto 0) := (others=>'0');

	signal enable  : std_logic := '0';
	signal data    : std_logic_vector(7 downto 0) := (others=>'0');
	signal xaddr   : std_logic_vector(16 downto 0) := (others=>'0');
	constant RAMID : std_logic_vector(2 downto 0) := "000";

begin
-- state machine --------------------------------------------------------------
	process(CLK,RST) begin
		if(RST='1') then
			state <= INVALID;
		elsif(CLK'event and CLK = '1') then
			case state is
				when INVALID =>
--					state <= READING;

--				when READING =>
					if START_SIM='1' then
						state <= SET;
					else
						state <= INVALID;
					end if;

				when SET =>
					state <= CNT_ADDR_X;

				when CNT_ADDR_X =>
					if addr_x>=(addr_x_max-addr_x_INIT) then
						state <= INVALID;
					end if;

				when others =>
					state <= INVALID;
			end case;
		end if;
	end process;
-------------------------------------------------------------------------------

--- Counter -------------------------------------------------------------------
	process(CLK, RST) begin
		if RST='1' then
			addr_x <= 0;
		elsif rising_edge(CLK) then
			case state is
				when SET =>
					addr_x <= 0;

				when CNT_ADDR_X =>
					addr_x <= addr_x + 1;

				when others =>
					addr_x <= 0;
			end case;
		end if;
	end process;
-------------------------------------------------------------------------------

--- SET -----------------------------------------------------------------------
	process(CLK, RST) begin
		if RST='1' then
			addr_x_INIT <= 0;
		elsif rising_edge(CLK) then
			if state=SET then
				if hem='1' then
					addr_x_INIT <= addr_x_INIT_Stim_R;
				else
					addr_x_INIT <= addr_x_INIT_Stim_L;
				end if;
			end if;
		end if;
	end process;

	process(CLK, RST) begin
		if RST='1' then
			addr_x_max <= 0;
		elsif rising_edge(CLK) then
			if state=SET then
				if hem='1' then
					addr_x_max <= addr_x_max_Stim_R;
				else
					addr_x_max <= addr_x_max_Stim_L;
				end if;
			end if;
		end if;
	end process;
-------------------------------------------------------------------------------

--- Set Data ------------------------------------------------------------------
	addr_l <= to_integer(to_unsigned(addr_x, 8) & "111"); -- 7
	addr_m <= to_integer(to_unsigned(addr_x, 8) & "000"); -- 0

	data_Stim    <= spkmean_R & spkmean_L & ERR       & COM              & CONMSR &
	                DSR       & PID       & time_sim  & (zeros7 & hem)   &
									spk_bkc   & spk_pkc   & spk_goc   & spk_grc & spk_cf & spk_mf;

	process(CLK, RST) begin
		if RST='1' then
			data <= (others => '0');
		elsif rising_edge(CLK) then
			if state=CNT_ADDR_X then
				data <= data_Stim( addr_l downto addr_m );
			end if;
		end if;
	end process;

	process(CLK, RST) begin
		if rising_edge(CLK) then
			if state=CNT_ADDR_X then
				xaddr <= std_logic_vector(to_unsigned(addr_x + addr_x_INIT, 17));
			end if;
		end if;
	end process;

	process(CLK, RST) begin
		if RST='1' then
			enable <= '0';
		elsif rising_edge(CLK) then
			if state=CNT_ADDR_X then
				enable <= '1';
			else
				enable <= '0';
			end if;
		end if;
	end process;
-------------------------------------------------------------------------------

--- Output --------------------------------------------------------------------
	WOUT1 <= data & xaddr & enable & RAMID;
-------------------------------------------------------------------------------
end Behavioral;
