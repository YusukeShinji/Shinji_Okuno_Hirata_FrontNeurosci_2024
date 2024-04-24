-------------------------------------------------------------------------------
-- BSD 3-Clause License
-- Copyright (c) 2024, Yusuke Shinji
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_SIGNED.ALL;

entity MUX_MF is
Port (
	CLK : in  STD_LOGIC;
	RST : in  STD_LOGIC;
	VALID_I : in  STD_LOGIC;
	VALID_O : out STD_LOGIC;
	VALID_O_PRE : out STD_LOGIC;
	-- Constant --
	INIT        : in  STD_LOGIC_VECTOR(31 downto 0);
	-- Input --
	i_stim_0 : in  STD_LOGIC_VECTOR(15 downto 0);
	i_stim_1 : in  STD_LOGIC_VECTOR(15 downto 0);
	i_stim_2 : in  STD_LOGIC_VECTOR(15 downto 0);
	i_stim_3 : in  STD_LOGIC_VECTOR(15 downto 0);
	i_stim_4 : in  STD_LOGIC_VECTOR(15 downto 0);
	-- Output --
	i_syn : out STD_LOGIC_VECTOR(15 downto 0)
);
end MUX_MF;

architecture Behavioral of MUX_MF is
	-- Pipeline Register --
	signal VALID_REG0_LFSR : STD_LOGIC;
	signal VALID_REG1_ADDR : STD_LOGIC;
	signal VALID_REG2_MUX  : STD_LOGIC;
	signal VALID_REG3_MUL  : STD_LOGIC;

	-- Address of pre cells --
	signal INIT_MUX  : STD_LOGIC_VECTOR(31 downto 0);
	signal rand_MUX  : STD_LOGIC_VECTOR(31 downto 0);
	signal ADDR_LFSR : STD_LOGIC_VECTOR(19 downto 0);
	signal ADDR      : INTEGER := 0;
	constant Num_i_stim : STD_LOGIC_VECTOR(3 downto 0) := "0100";

	-- Weight --
	signal INIT_weight    : STD_LOGIC_VECTOR(31 downto 0);
	signal rand_weight    : STD_LOGIC_VECTOR(31 downto 0);
	signal rdweight       : STD_LOGIC_VECTOR(15 downto 0);
	signal rdweight_delay : STD_LOGIC_VECTOR(15 downto 0);
	signal i_stim         : STD_LOGIC_VECTOR(15 downto 0);
	signal i_stim_sat     : STD_LOGIC_VECTOR(15 downto 0);
	signal i_weight       : STD_LOGIC_VECTOR(31 downto 0);

	constant weight_mean : STD_LOGIC_VECTOR(15 downto 0) := (others=>'0');
	constant i_stim_MAX  : STD_LOGIC_VECTOR(15 downto 0) := (15=>'0',others=>'1');
	constant i_stim_MIN  : STD_LOGIC_VECTOR(15 downto 0) := (15=>'1',others=>'0');

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

	process(CLK, RST) begin
		if RST='1' then
			VALID_REG3_MUL <= '0';
		elsif(CLK'event and CLK='1') then
			if VALID_REG2_MUX='1' then
				VALID_REG3_MUL <= '1';
			else
				VALID_REG3_MUL <= '0';
			end if;
		end if;
	end process;
-------------------------------------------------------------------------------

--- Generating Address --------------------------------------------------------
	INIT_MUX <= INIT;

	MUX_LFSR32bit_COMP : LFSR32bit Port MAP(
		CLK => CLK,
		RST => RST,
		ENA => VALID_REG0_LFSR,
		-- Input --
		INIT => INIT_MUX,
		-- Output --
		LFSR => rand_MUX
	);

	ADDR_LFSR <= rand_MUX(15 downto 0) * Num_i_stim;

	process(CLK,RST) begin
		if RST='1' then
			ADDR <= 0;
		elsif(CLK'event and CLK = '1') then
			if(VALID_REG1_ADDR='1') then
				ADDR <= to_integer(signed( (ADDR_LFSR(19 downto 15) + ADDR_LFSR(14)) ));
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

	rdweight <= "0"&rand_weight(14 downto 0); -- weight_mean = 0.5

	process(CLK,RST) begin
		if(RST='1') then
			rdweight_delay <= (others=>'0');
		elsif(CLK'event and CLK = '1') then
			if(VALID_REG2_MUX='1') then
				rdweight_delay <= rdweight + weight_mean;
			else
				rdweight_delay <= (others=>'0');
			end if;
		end if;
	end process;

	--- Convert to Weight ---
	process(CLK,RST) begin
		if(RST='1') then
			i_stim <= (others=>'0');
		elsif(CLK'event and CLK = '1') then
			if(VALID_REG2_MUX='1') then
				case ADDR is
					when 0      => i_stim <= i_stim_0;
					when 1      => i_stim <= i_stim_1;
					when 2      => i_stim <= i_stim_2;
					when 3      => i_stim <= i_stim_3;
					when 4      => i_stim <= i_stim_4;
					when others => i_stim <= (others=>'0');
				end case;
			else
				i_stim <= (others=>'0');
			end if;
		end if;
	end process;

	i_stim_sat <= i_stim_MAX when i_stim>i_stim_MAX else
								i_stim_MIN when i_stim<i_stim_MIN else
								i_stim;

	MULT_16_16_COMP : MULT_16_16
	PORT MAP (
		clk => clk,
		a => i_stim_sat,
		b => rdweight_delay,
		ce => VALID_REG3_MUL,
		p => i_weight
	);
-------------------------------------------------------------------------------

---- Output -------------------------------------------------------------------
	process(CLK, RST) begin
		if RST='1' then
			VALID_O <= '0';
		elsif (CLK'event and CLK='1') then
			if(VALID_REG3_MUL='1') then
				VALID_O <= '1';
			else
				VALID_O <= '0';
			end if;
		end if;
	end process;

	VALID_O_PRE <= VALID_REG3_MUL;

	i_syn <= i_weight(30 downto 15);
-------------------------------------------------------------------------------
end Behavioral;
