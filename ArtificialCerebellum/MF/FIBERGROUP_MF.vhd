-------------------------------------------------------------------------------
-- BSD 3-Clause License
-- Copyright (c) 2024, Yusuke Shinji
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.STD_LOGIC_MISC.ALL;

entity FIBERGROUP_MF is
Port (
	CLK : in  STD_LOGIC;
	RST : in  STD_LOGIC;
  hem : in  STD_LOGIC;
	VALID_I : in  STD_LOGIC;
	VALID_O : out STD_LOGIC;
	-- Input --
	i_stim_0 : in  STD_LOGIC_VECTOR(15 downto 0);
	i_stim_1 : in  STD_LOGIC_VECTOR(15 downto 0);
	i_stim_2 : in  STD_LOGIC_VECTOR(15 downto 0);
	i_stim_3 : in  STD_LOGIC_VECTOR(15 downto 0);
	i_stim_4 : in  STD_LOGIC_VECTOR(15 downto 0);
	-- Output --
	t_spk  : out STD_LOGIC_VECTOR(245 downto 0)
);
end FIBERGROUP_MF;

architecture Behavioral of FIBERGROUP_MF is
	-- state --
	signal state : std_logic_vector(1 downto 0);
	constant INVALID : std_logic_vector(1 downto 0) := "00";
	constant VALID : std_logic_vector(1 downto 0) := "01";
	constant RESET : std_logic_vector(1 downto 0) := "10";

	signal VALID_I_FIBER : std_logic;
	signal VALID_O_FIBER : std_logic;
	signal VALID_O_FIBER_delay : std_logic;

	signal END_FIBER : std_logic;
	signal RST_ADDR : std_logic;

	-- num of cells --
	signal addr_cnt : std_logic_vector(7 downto 0);
	constant addr_cnt_max : std_logic_vector(7 downto 0)
		:= "11110101";

	-- Initial Value of LFSR
	constant INIT : STD_LOGIC_VECTOR(31 downto 0)
		:= "11010010011000100000100000010111";

	-- Value --
	signal t_spk_new : STD_LOGIC_VECTOR(245 downto 0);

	COMPONENT FIBER_MF
	Port (
		CLK : in  STD_LOGIC;
		RST : in  STD_LOGIC;
	  hem : in  STD_LOGIC;
		RST_ADDR : in  STD_LOGIC;
		VALID_I : in  STD_LOGIC;
		VALID_O : out STD_LOGIC;
		-- Input --
		INIT     : in  STD_LOGIC_VECTOR(31 downto 0);
		i_stim_0 : in  STD_LOGIC_VECTOR(15 downto 0);
		i_stim_1 : in  STD_LOGIC_VECTOR(15 downto 0);
		i_stim_2 : in  STD_LOGIC_VECTOR(15 downto 0);
		i_stim_3 : in  STD_LOGIC_VECTOR(15 downto 0);
		i_stim_4 : in  STD_LOGIC_VECTOR(15 downto 0);
		-- Output --
		t_spk : out STD_LOGIC_VECTOR(245 downto 0)
	);
	END COMPONENT;

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

	VALID_I_FIBER <= '1' when STATE=VALID else
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

--- Calculate MembranePotential -----------------------------------------------
	RST_ADDR <= '1' when RST='1' or END_FIBER='1' else
	            '0';
	FIBER_MF_COMP: FIBER_MF PORT MAP(
		CLK => CLK,
		RST => RST,
		hem   => hem,
		RST_ADDR => RST_ADDR,
		VALID_I => VALID_I_FIBER,
		VALID_O => VALID_O_FIBER,
		-- Input --
		INIT     => INIT,
		i_stim_0 => i_stim_0,
		i_stim_1 => i_stim_1,
		i_stim_2 => i_stim_2,
		i_stim_3 => i_stim_3,
		i_stim_4 => i_stim_4,
		-- Output --
		t_spk => t_spk_new
	);
-------------------------------------------------------------------------------

--- Output --------------------------------------------------------------------
	process(CLK,RST) begin
		if(RST='1') then
			VALID_O_FIBER_delay <= '0';
		elsif(CLK'event and CLK = '1') then
			VALID_O_FIBER_delay <= VALID_O_FIBER;
		end if;
	end process;

	END_FIBER <= '1' when (state=INVALID and
	                       VALID_O_FIBER_delay='1' and
	                       VALID_O_FIBER='0') else
	             '0';
	VALID_O <= END_FIBER;
	t_spk   <= t_spk_new;
-------------------------------------------------------------------------------

end Behavioral;
