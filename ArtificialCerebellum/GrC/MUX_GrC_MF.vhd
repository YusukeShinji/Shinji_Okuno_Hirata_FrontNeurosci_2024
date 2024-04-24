-------------------------------------------------------------------------------
-- BSD 3-Clause License
-- Copyright (c) 2024, Yusuke Shinji
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity MUX_GrC_MF is
Port (
	CLK : in  STD_LOGIC;
	RST : in  STD_LOGIC;
	VALID_I : in  STD_LOGIC;
	VALID_O : out STD_LOGIC;
	-- Constant --
	Num_MUX     : in  STD_LOGIC_VECTOR(2 downto 0);
	weight_ampl : in  STD_LOGIC_VECTOR(15 downto 0);
	weight_mean : in  STD_LOGIC_VECTOR(15 downto 0);
	INIT        : in  STD_LOGIC_VECTOR(31 downto 0);
	-- Input --
	t_spk : in  STD_LOGIC_VECTOR(245 downto 0);
	-- Output --
	weight_syn : out STD_LOGIC_VECTOR(15 downto 0)
);
end MUX_GrC_MF;

architecture Behavioral of MUX_GrC_MF is
	-- Pipeline Register --
	signal VALID_REG0_LFSR : STD_LOGIC;
	signal VALID_REG1_ADDR : STD_LOGIC;
	signal VALID_REG2_MUX  : STD_LOGIC;

	-- LFSR --
	constant Num_Cell : STD_LOGIC_VECTOR(7 downto 0)
		:= "11110101";

	signal INIT_MUX  : STD_LOGIC_VECTOR(31 downto 0);
	signal LFSR      : STD_LOGIC_VECTOR(31 downto 0) := (others=>'0');
	signal ADDR_LFSR : STD_LOGIC_VECTOR(23 downto 0) := (others=>'0');
	signal ADDR      : INTEGER := 0;

	-- weight --
	signal INIT_weight : STD_LOGIC_VECTOR(31 downto 0);
	signal rand_weight : STD_LOGIC_VECTOR(31 downto 0);
	signal rdweight    : STD_LOGIC_VECTOR(15 downto 0) := (others=>'0');
	signal weight      : STD_LOGIC_VECTOR(31 downto 0) := (others=>'0');
	signal spk_mux     : STD_LOGIC;

  -- COMPONENT --
	COMPONENT LFSR32bit is
		Port (
			CLK : in  STD_LOGIC;
			RST : in  STD_LOGIC;
			ENA : in  STD_LOGIC;
			-- Input --
			INIT : in  STD_LOGIC_VECTOR (31 downto 0);
			-- Output --
			LFSR : out STD_LOGIC_VECTOR (31 downto 0)
		);
  END COMPONENT;

	COMPONENT LFSR32bit_Gausian16bit is
		Port (
			CLK : in  STD_LOGIC;
			RST : in  STD_LOGIC;
			ENA : in  STD_LOGIC;
			-- Input --
			INIT   : in  STD_LOGIC_VECTOR (31 downto 0);
			-- Output --
			GAUSS  : out STD_LOGIC_VECTOR (15 downto 0)
		);
  END COMPONENT;

	COMPONENT MULT_16_16
	PORT (
		clk : IN STD_LOGIC;
		a : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		b : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		ce : IN STD_LOGIC;
		p : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
	);
	END COMPONENT;

begin
--- Valid  protocol -----------------------------------------------------------
	VALID_REG0_LFSR <= '1' when VALID_I='1' else
						 '0';

	process(CLK, RST) begin
		if RST='1' then
			VALID_REG1_ADDR <= '0';
		elsif(CLK'event and CLK='1') then
			if VALID_REG0_LFSR='1' then
				VALID_REG1_ADDR <= '1';
			else
				VALID_REG1_ADDR <= '0';
			end if;
		end if;
	end process;

	process(CLK, RST) begin
		if RST='1' then
			VALID_REG2_MUX <= '0';
		elsif(CLK'event and CLK='1') then
			if VALID_REG1_ADDR='1' then
				VALID_REG2_MUX <= '1';
			else
				VALID_REG2_MUX <= '0';
			end if;
		end if;
	end process;
-------------------------------------------------------------------------------

--- Generating Address --------------------------------------------------------
	INIT_MUX <= INIT + (Num_MUX+7);

  LFSR32bit_COMP : LFSR32bit Port MAP(
		CLK => CLK,
		RST => RST,
	  ENA => VALID_REG0_LFSR,
	  -- Input --
	  INIT => INIT_MUX,
	  -- Output --
	  LFSR => LFSR
	);

	ADDR_LFSR <= LFSR(15 downto 0) * Num_Cell;

	process(CLK,RST) begin
		if RST='1' then
			ADDR <= 0;
		elsif(CLK'event and CLK = '1') then
			if(VALID_REG1_ADDR='1') then
				ADDR <= to_integer(unsigned( ADDR_LFSR(23 downto 16) + ADDR_LFSR(15)));
			else
				ADDR <= 0;
			end if;
		end if;
	end process;
-------------------------------------------------------------------------------

--- Generating Weight ---------------------------------------------------------
	INIT_weight <= (INIT_MUX(15 downto 0) & INIT_MUX(31 downto 16));

--	weight_LFSR32bit_Gausian16bit_COMP : LFSR32bit_Gausian16bit Port MAP(
--		CLK => CLK,
--		RST => RST,
--		ENA => VALID_REG0_LFSR,
--		-- Input --
--		INIT => INIT_weight,
--		-- Output --
--		GAUSS => rand_weight
--	);

	weight_LFSR32bit_COMP : LFSR32bit Port MAP(
		CLK => CLK,
		RST => RST,
		ENA => VALID_REG1_ADDR,
		-- Input --
		INIT => INIT_weight,
		-- Output --
		LFSR => rand_weight
	);

	rdweight <= "0"&rand_weight(14 downto 0);

	--- Convert to Weight ---
	MULT_16_16_COMP : MULT_16_16
	PORT MAP (
		clk => clk,
		a => weight_ampl,
		b => rdweight,
		ce => VALID_REG2_MUX,
		p => weight
	);

	process(CLK,RST) begin
		if RST='1' then
			spk_mux <= '0';
		elsif(CLK'event and CLK = '1') then
			if(VALID_REG2_MUX='1') then
				spk_mux <= t_spk( ADDR );
			else
				spk_mux <= '0';
			end if;
		end if;
	end process;
-------------------------------------------------------------------------------

---- Output -------------------------------------------------------------------
	process(CLK, RST) begin
		if RST='1' then
			VALID_O <= '0';
		elsif (CLK'event and CLK='1') then
			if VALID_REG2_MUX='1' then
				VALID_O <= '1';
			else
				VALID_O <= '0';
			end if;
		end if;
	end process;

	weight_syn <= weight(29 downto 14) + weight_mean when spk_mux='1' else
	              (others=>'0');
-------------------------------------------------------------------------------
end Behavioral;
