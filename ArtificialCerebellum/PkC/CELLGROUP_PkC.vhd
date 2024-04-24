-------------------------------------------------------------------------------
-- BSD 3-Clause License
-- Copyright (c) 2024, Yusuke Shinji
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.std_logic_misc.all;

entity CELLGROUP_PkC is
Port (
	CLK : in  STD_LOGIC;
	RST : in  STD_LOGIC;
	hem   : in STD_LOGIC;
	LEARN : in STD_LOGIC;
	VALID_I : in  STD_LOGIC;
	VALID_O : out STD_LOGIC;
	-- Parameter --
	t_win     : in STD_LOGIC_VECTOR(31 downto 0);
	g_LTD     : in  STD_LOGIC_VECTOR(31 downto 0);
	g_LTP     : in  STD_LOGIC_VECTOR(31 downto 0);
	-- Input --
	t_spk_grc : in  STD_LOGIC_VECTOR(4095 downto 0);
	t_spk_bkc : in  STD_LOGIC_VECTOR(24 downto 0);
	t_spk_cf  : in  STD_LOGIC_VECTOR(7 downto 0);
	-- Output --
	t_spk : out STD_LOGIC_VECTOR(7 downto 0);
	write_weight_syns : out STD_LOGIC_VECTOR(77 downto 0)
);
end CELLGROUP_PkC;

architecture Behavioral of CELLGROUP_PkC is
	-- State --
	signal state : STD_LOGIC_VECTOR(1 downto 0);
	constant INVALID  : STD_LOGIC_VECTOR(1 downto 0) := "00";
	constant CNT_Cell : STD_LOGIC_VECTOR(1 downto 0) := "01";
	constant CNT_Syn  : STD_LOGIC_VECTOR(1 downto 0) := "10";

	-- Valid --
	signal VALID_I_CELL : STD_LOGIC;
	signal VALID_O_CELL : STD_LOGIC;
	signal END_CELL : STD_LOGIC;
	signal RST_ADDR : STD_LOGIC;

	signal END_SUM_PkC_GrC : STD_LOGIC;
	signal END_SUM_PkC_BkC : STD_LOGIC;

	signal write_weight_syns_temp : STD_LOGIC_VECTOR(77 downto 0);

	-- Count --
	signal addr_cell : STD_LOGIC_VECTOR(2 downto 0) := (others=>'0');
	signal addr_cell_out : STD_LOGIC_VECTOR(3 downto 0) := (others=>'0');
	signal addr_syn : STD_LOGIC_VECTOR(9 downto 0) := (others=>'0');

	constant addr_cell_max : STD_LOGIC_VECTOR(2 downto 0)
		:= "111"; -- PkC -1
	constant addr_syn_max : STD_LOGIC_VECTOR(9 downto 0)
		:= "1111111111"; -- GrC -1

	constant addr_grc_max : STD_LOGIC_VECTOR(9 downto 0)
		:= "1111111111"; -- GrC -1
	constant addr_bkc_max : STD_LOGIC_VECTOR(9 downto 0)
		:= "0000001001"; -- BkC -1

		-- Initial Value of LFSR
		constant INIT : STD_LOGIC_VECTOR(31 downto 0)
			:= "00000110111110110110101001100100";

	-- value --
	signal t_spk_new : STD_LOGIC_VECTOR(7 downto 0);

	-- Cell Component --
  COMPONENT CELL_PkC is
  Port (
		CLK : in  STD_LOGIC;
		RST : in  STD_LOGIC;
		hem      : in STD_LOGIC;
		LEARN    : in STD_LOGIC;
		RST_ADDR : in STD_LOGIC;
		VALID_I : in  STD_LOGIC;
		VALID_O : out STD_LOGIC;
		END_SUM_I_PkC_GrC : in STD_LOGIC;
		END_SUM_I_PkC_BkC : in STD_LOGIC;
		-- Constant --
		t_win     : in  STD_LOGIC_VECTOR(31 downto 0);
		g_LTD     : in  STD_LOGIC_VECTOR(31 downto 0);
		g_LTP     : in  STD_LOGIC_VECTOR(31 downto 0);
		INIT      : in  STD_LOGIC_VECTOR(31 downto 0);
		-- Input --
		addr_cell : in  STD_LOGIC_VECTOR(2 downto 0);
		addr_syn  : in  STD_LOGIC_VECTOR(9 downto 0);
		t_spk_grc : in  STD_LOGIC_VECTOR(4095 downto 0);
		t_spk_bkc : in  STD_LOGIC_VECTOR(24 downto 0);
		t_spk_cf  : in  STD_LOGIC_VECTOR(7 downto 0);
		-- Output --
		t_spk     : out STD_LOGIC_VECTOR(7 downto 0);
		write_weight_syns : out STD_LOGIC_VECTOR(77 downto 0)
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
						state <= CNT_Syn;
					end if;

				when CNT_Syn =>
					if addr_syn>=addr_syn_max then
						state <= CNT_Cell;
					end if;

				when CNT_Cell =>
					if addr_cell>=addr_cell_max then
						state <= INVALID;
					else
						state <= CNT_Syn;
					end if;

				when others =>
					state <= INVALID;
			end case;
		end if;
	end process;

--	process(CLK,RST) begin
--    if(RST='1') then
--      VALID_I_CELL <= '0';
--    elsif(CLK'event and CLK = '1') then
--			if STATE=CNT_Syn then
--				VALID_I_CELL <= '1';
--			elsif state=INVALID then
--				VALID_I_CELL <= '0';
--			end if;
--    end if;
--  end process;
	VALID_I_CELL <= '1' when STATE=CNT_Syn else '0';
-------------------------------------------------------------------------------

-- Count up the number of cells -----------------------------------------------
  process(CLK,RST) begin
    if(RST='1') then
      addr_cell <= (others=>'0');
    elsif(CLK'event and CLK = '1') then
			if state=CNT_Cell then
      	addr_cell <= addr_cell + 1;
			elsif state=INVALID then
				addr_cell <= (others=>'0');
			end if;
    end if;
  end process;

	process(CLK,RST) begin
		if(RST='1') then
			addr_syn <= (others=>'0');
		elsif(CLK'event and CLK = '1') then
			if state=CNT_Syn then
				addr_syn <= addr_syn + 1;
			elsif (state=CNT_Cell or state=INVALID) then
				addr_syn <= (others=>'0');
			end if;
		end if;
	end process;

	process(CLK,RST_addr) begin
		if(RST_addr='1') then
			addr_cell_out <= (others=>'0');
		elsif(CLK'event and CLK = '1') then
			if END_CELL='0' then
				if VALID_O_CELL='1' then
					addr_cell_out <= addr_cell_out + 1;
				end if;
			else
				addr_cell_out <= (others=>'0');
			end if;
		end if;
	end process;

	process(CLK,RST) begin
		if(RST='1') then
			END_CELL <= '0';
		elsif(CLK'event and CLK = '1') then
			if(addr_cell_out>addr_cell_max) then
				END_CELL <= '1';
			else
				END_CELL <= '0';
			end if;
		end if;
	end process;
-------------------------------------------------------------------------------

-- Cells ----------------------------------------------------------------------
	END_SUM_PkC_GrC <= '1' when addr_syn=addr_grc_max else
	                   '0';
	END_SUM_PkC_BkC <= '1' when addr_syn>=addr_bkc_max else
	                   '0';
	RST_ADDR <= '1' when RST='1' or END_CELL='1' else
	            '0';
  CELL_PkC_COMP: CELL_PkC PORT MAP(
		CLK => CLK,
		RST => RST,
		hem   => hem,
		LEARN => LEARN,
		RST_ADDR => RST_ADDR,
		VALID_I => VALID_I_CELL,
		VALID_O => VALID_O_CELL,
		END_SUM_I_PkC_GrC => END_SUM_PkC_GrC,
		END_SUM_I_PkC_BkC => END_SUM_PkC_BkC,
		-- Constant --
		t_win => t_win,
		g_LTD => g_LTD,
		g_LTP => g_LTP,
		INIT => INIT,
		-- Input --
		addr_cell => addr_cell,
		addr_syn  => addr_syn,
		t_spk_grc => t_spk_grc,
		t_spk_bkc => t_spk_bkc,
		t_spk_cf  => t_spk_cf,
		-- Output --
		t_spk => t_spk_new,
		write_weight_syns => write_weight_syns_temp
  );
-------------------------------------------------------------------------------

-- Output ---------------------------------------------------------------------
	VALID_O  <= '1' when END_CELL='1' else '0';
	t_spk    <= t_spk_new;
	write_weight_syns <= write_weight_syns_temp;
-------------------------------------------------------------------------------
end Behavioral;
