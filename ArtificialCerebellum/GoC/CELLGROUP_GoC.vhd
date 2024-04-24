-------------------------------------------------------------------------------
-- BSD 3-Clause License
-- Copyright (c) 2024, Yusuke Shinji
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.std_logic_misc.all;

entity CELLGROUP_GoC is
Port (
	CLK : in  STD_LOGIC;
	RST : in  STD_LOGIC;
	hem   : in STD_LOGIC;
	VALID_I : in  STD_LOGIC;
	VALID_O : out STD_LOGIC;
	-- Input --
	t_spk_grc : in  STD_LOGIC_VECTOR(4095 downto 0);
	t_spk_mf : in  STD_LOGIC_VECTOR(245 downto 0);
	-- Output --
	t_spk : out STD_LOGIC_VECTOR(368 downto 0)
);
end CELLGROUP_GoC;

architecture Behavioral of CELLGROUP_GoC is
	-- State --
	signal state : STD_LOGIC_VECTOR(1 downto 0);
	constant INVALID  : STD_LOGIC_VECTOR(1 downto 0) := "00";
	constant CNT_Cell : STD_LOGIC_VECTOR(1 downto 0) := "01";
	constant CNT_Syn  : STD_LOGIC_VECTOR(1 downto 0) := "10";

	-- Valid --
	signal VALID_I_CELL : STD_LOGIC;
	signal VALID_O_CELL : STD_LOGIC_VECTOR(2 downto 0);

	signal END_CELL : STD_LOGIC;
	signal RST_ADDR : STD_LOGIC;

	signal END_SUM_GoC_MF  : STD_LOGIC;
	signal END_SUM_GoC_GrC : STD_LOGIC;

	-- Count --
	signal addr_cell : STD_LOGIC_VECTOR(6 downto 0);
	signal addr_cell_out : STD_LOGIC_VECTOR(6 downto 0);
	signal addr_syn : STD_LOGIC_VECTOR(6 downto 0);

	constant addr_cell_max : STD_LOGIC_VECTOR(6 downto 0)
		:= "1111010"; -- GoC 123
	constant addr_syn_max : STD_LOGIC_VECTOR(6 downto 0)
		:= "1100011"; -- GoC-GrC 100

	constant addr_grc_max : STD_LOGIC_VECTOR(6 downto 0)
		:= "1100011"; -- GoC-GrC 100
	constant addr_mf_max : STD_LOGIC_VECTOR(6 downto 0)
		:= "0010011"; -- GoC-MF 20

	-- Initial Value of LFSR
	constant INIT : STD_LOGIC_VECTOR(31 downto 0)
		:= "01110001001011101110101001110110";

	-- value --
	signal t_spk_new_0 : STD_LOGIC_VECTOR(122 downto 0);
	signal t_spk_new_1 : STD_LOGIC_VECTOR(122 downto 0);
	signal t_spk_new_2 : STD_LOGIC_VECTOR(122 downto 0);

	-- Cell Component --
  COMPONENT CELL_GoC is
  Port (
		CLK : in  STD_LOGIC;
		RST : in  STD_LOGIC;
		hem      : in STD_LOGIC;
		RST_ADDR : in STD_LOGIC;
		VALID_I : in  STD_LOGIC;
		VALID_O : out STD_LOGIC;
		END_SUM_I_GoC_GrC : in STD_LOGIC;
		END_SUM_I_GoC_MF : in STD_LOGIC;
		-- Constant --
		Num_Cell : in  STD_LOGIC_VECTOR(2 downto 0);
		INIT : in  STD_LOGIC_VECTOR(31 downto 0);
		-- Input --
		t_spk_grc : in  STD_LOGIC_VECTOR(4095 downto 0);
		t_spk_mf : in  STD_LOGIC_VECTOR(245 downto 0);
		-- Output --
		t_spk : out STD_LOGIC_VECTOR(122 downto 0)
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
				if VALID_O_CELL="111" then
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
	END_SUM_GoC_GrC <= '1' when addr_syn=addr_grc_max else
	                   '0';
	END_SUM_GoC_MF <= '1' when addr_syn>=addr_mf_max else
	                   '0';
	RST_ADDR <= '1' when RST='1' or END_CELL='1' else
	            '0';
  CELL_GoC_COMP: CELL_GoC PORT MAP(
		CLK => CLK,
		RST => RST,
		hem   => hem,
		RST_ADDR => RST_ADDR,
		VALID_I => VALID_I_CELL,
		VALID_O => VALID_O_CELL(0),
		END_SUM_I_GoC_GrC => END_SUM_GoC_GrC,
		END_SUM_I_GoC_MF => END_SUM_GoC_MF,
		-- Constant --
		Num_Cell => "000",
		INIT => INIT,
		-- Input --
		t_spk_grc => t_spk_grc,
		t_spk_mf => t_spk_mf,
		-- Output --
		t_spk => t_spk_new_0
  );

	CELL_GoC_COMP_1: CELL_GoC PORT MAP(
		CLK => CLK,
		RST => RST,
		hem   => hem,
		RST_ADDR => RST_ADDR,
		VALID_I => VALID_I_CELL,
		VALID_O => VALID_O_CELL(1),
		END_SUM_I_GoC_GrC => END_SUM_GoC_GrC,
		END_SUM_I_GoC_MF => END_SUM_GoC_MF,
		-- Constant --
		Num_Cell => "001",
		INIT => INIT,
		-- Input --
		t_spk_grc => t_spk_grc,
		t_spk_mf => t_spk_mf,
		-- Output --
		t_spk => t_spk_new_1
  );

	CELL_GoC_COMP_2: CELL_GoC PORT MAP(
		CLK => CLK,
		RST => RST,
		hem   => hem,
		RST_ADDR => RST_ADDR,
		VALID_I => VALID_I_CELL,
		VALID_O => VALID_O_CELL(2),
		END_SUM_I_GoC_GrC => END_SUM_GoC_GrC,
		END_SUM_I_GoC_MF => END_SUM_GoC_MF,
		-- Constant --
		Num_Cell => "010",
		INIT => INIT,
		-- Input --
		t_spk_grc => t_spk_grc,
		t_spk_mf => t_spk_mf,
		-- Output --
		t_spk => t_spk_new_2
  );
-------------------------------------------------------------------------

--- Output --------------------------------------------------------------
	VALID_O  <= '1' when END_CELL='1' else '0';
	t_spk    <= t_spk_new_0 & t_spk_new_1 & t_spk_new_2;
-------------------------------------------------------------------------
end Behavioral;
