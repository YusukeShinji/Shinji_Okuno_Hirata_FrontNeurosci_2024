-------------------------------------------------------------------------------
-- BSD 3-Clause License
-- Copyright (c) 2024, Yusuke Shinji
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.all;
use IEEE.std_logic_misc.all;

entity CELLGROUP_GrC is
Port (
	CLK : in  STD_LOGIC;
	RST : in  STD_LOGIC;
	hem : in  STD_LOGIC;
  VALID_I : in  STD_LOGIC;
  VALID_O : out STD_LOGIC;
  -- Input --
  t_spk_mf  : in  STD_LOGIC_VECTOR(245 downto 0);
  t_spk_goc : in  STD_LOGIC_VECTOR(368 downto 0);
  -- Output --
	t_spk    : out STD_LOGIC_VECTOR(4095 downto 0)
);
end CELLGROUP_GrC;

architecture Behavioral of CELLGROUP_GrC is
	-- state --
	signal state : std_logic_vector(1 downto 0);
	constant INVALID : std_logic_vector(1 downto 0) := "00";
	constant VALID : std_logic_vector(1 downto 0) := "01";
	constant RESET : std_logic_vector(1 downto 0) := "10";

	signal VALID_I_CELL : std_logic;
	signal VALID_O_CELL : std_logic_vector(3 downto 0);
	signal VALID_O_CELL_delay : std_logic;

	signal END_CELL : std_logic;
	signal RST_ADDR : std_logic;

	-- num of cells --
	signal addr_cnt : std_logic_vector(9 downto 0);
	constant addr_cnt_max : std_logic_vector(9 downto 0)
		:= "1111111111"; -- grc : 4096 cells

	-- Initial Value of LFSR --
	constant INIT : STD_LOGIC_VECTOR(31 downto 0)
		:= "10010110000100110001000001100010";

	-- Value --
	signal t_spk_0 : STD_LOGIC_VECTOR(1023 downto 0);
	signal t_spk_1 : STD_LOGIC_VECTOR(1023 downto 0);
	signal t_spk_2 : STD_LOGIC_VECTOR(1023 downto 0);
	signal t_spk_3 : STD_LOGIC_VECTOR(1023 downto 0);

	-- Cell Component --
  COMPONENT CELL_GrC is
	  Port (
			CLK : in  STD_LOGIC;
			RST : in  STD_LOGIC;
			hem : in  STD_LOGIC;
			RST_ADDR : in  STD_LOGIC;
		  VALID_I : in  STD_LOGIC;
		  VALID_O : out STD_LOGIC;
			-- Constant --
			NumProc  : in  STD_LOGIC_VECTOR(2 downto 0);
			INIT : in  STD_LOGIC_VECTOR(31 downto 0);
		  -- Input --
		  t_spk_mf  : in  STD_LOGIC_VECTOR(245 downto 0);
		  t_spk_goc : in  STD_LOGIC_VECTOR(368 downto 0);
		  -- Output --
			t_spk   : out STD_LOGIC_VECTOR(1023 downto 0)
		);
	end COMPONENT;

begin
-- state machine --------------------------------------------------------------
	process(CLK,RST) begin
		if(RST='1') then
			state <= INVALID;
		elsif(CLK'event and CLK = '1') then
			case state is
				when INVALID =>
					if VALID_I='1' then
						state <= RESET;
					end if;

				when RESET =>
					state <= VALID;

				when VALID =>
					if addr_cnt>=addr_cnt_max then
						state <= INVALID;
					end if;

				when others =>
					state <= INVALID;
			end case;
		end if;
	end process;

	VALID_I_CELL <= '1' when STATE=VALID else
									'0';
-------------------------------------------------------------------------------

-- Count up the number of cells -----------------------------------------------
  process(CLK,RST) begin
    if(RST='1') then
      addr_cnt <= (others=>'0');
    elsif(CLK'event and CLK = '1') then
			if state=RESET then
				addr_cnt <= (others=>'0');
			elsif state=VALID then
			  	addr_cnt <= addr_cnt + 1;
			end if;
    end if;
  end process;
-------------------------------------------------------------------------------

-- Cells ----------------------------------------------------------------------
	RST_ADDR <= '1' when RST='1' or END_CELL='1' else
	            '0';
	CELL_GrC_COMP0: CELL_GrC PORT MAP(
		CLK => CLK,
		RST => RST,
		hem   => hem,
		RST_ADDR => RST_ADDR,
		VALID_I => VALID_I_CELL,
		VALID_O => VALID_O_CELL(0),
		-- Constant --
		NumProc => "000",
		INIT => INIT,
		-- Input --
		t_spk_mf  => t_spk_mf,
		t_spk_goc => t_spk_goc,
		-- Output --
		t_spk  => t_spk_0
	);

	CELL_GrC_COMP1: CELL_GrC PORT MAP(
		CLK => CLK,
		RST => RST,
		hem   => hem,
		RST_ADDR => RST_ADDR,
		VALID_I => VALID_I_CELL,
		VALID_O => VALID_O_CELL(1),
		-- Constant --
		NumProc => "001",
		INIT => INIT,
		-- Input --
		t_spk_mf  => t_spk_mf,
		t_spk_goc => t_spk_goc,
		-- Output --
		t_spk  => t_spk_1
	);

	CELL_GrC_COMP2: CELL_GrC PORT MAP(
		CLK => CLK,
		RST => RST,
		hem   => hem,
		RST_ADDR => RST_ADDR,
		VALID_I => VALID_I_CELL,
		VALID_O => VALID_O_CELL(2),
		-- Constant --
		NumProc => "010",
		INIT => INIT,
		-- Input --
		t_spk_mf  => t_spk_mf,
		t_spk_goc => t_spk_goc,
		-- Output --
		t_spk  => t_spk_2
	);

	CELL_GrC_COMP3: CELL_GrC PORT MAP(
		CLK => CLK,
		RST => RST,
		hem   => hem,
		RST_ADDR => RST_ADDR,
		VALID_I => VALID_I_CELL,
		VALID_O => VALID_O_CELL(3),
		-- Constant --
		NumProc => "011",
		INIT => INIT,
		-- Input --
		t_spk_mf  => t_spk_mf,
		t_spk_goc => t_spk_goc,
		-- Output --
		t_spk  => t_spk_3
	);
-------------------------------------------------------------------------------

-- Output ---------------------------------------------------------------------
	process(CLK,RST) begin
		if(RST='1') then
			VALID_O_CELL_delay <= '0';
		elsif(CLK'event and CLK = '1') then
			VALID_O_CELL_delay <= and_reduce(VALID_O_CELL);
		end if;
	end process;

	END_CELL <=  '1' when (state=INVALID and
	                       VALID_O_CELL_delay='1' and
	                       and_reduce(VALID_O_CELL)='0') else
	             '0';
	VALID_O  <= END_CELL;
	t_spk    <= t_spk_3 & t_spk_2 & t_spk_1 & t_spk_0;
-------------------------------------------------------------------------------
end Behavioral;
