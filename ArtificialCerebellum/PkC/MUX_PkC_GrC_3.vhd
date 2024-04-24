-------------------------------------------------------------------------------
-- BSD 3-Clause License
-- Copyright (c) 2024, Yusuke Shinji
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.std_logic_misc.all;

entity MUX_PkC_GrC_3 is
Port (
	CLK : in  STD_LOGIC;
	RST : in  STD_LOGIC;
	hem : in  STD_LOGIC;
	VALID_I : in  STD_LOGIC;
	VALID_O : out STD_LOGIC;
	END_SUM_I : in  STD_LOGIC;
	END_SUM_O : out STD_LOGIC;
	-- Constant --
	Num_MUX     : in  STD_LOGIC_VECTOR(2 downto 0);
--	weight_mean : in  STD_LOGIC_VECTOR(15 downto 0);
	gum_LTD     : in  STD_LOGIC_VECTOR(31 downto 0);
	gum_LTP     : in  STD_LOGIC_VECTOR(31 downto 0);
	t_win       : in  STD_LOGIC_VECTOR(31 downto 0);
	INIT        : in  STD_LOGIC_VECTOR(31 downto 0);
	-- Input --
	addr_cf : in  STD_LOGIC_VECTOR(2 downto 0);
	addr_grc  : in  STD_LOGIC_VECTOR(9 downto 0);
	spk_grc : in  STD_LOGIC_VECTOR(1023 downto 0);
	spk_cf  : in  STD_LOGIC_VECTOR(7 downto 0);
	-- Output --
	weight_syn : out STD_LOGIC_VECTOR(15 downto 0);
	WRITE_weight_usb : out STD_LOGIC_VECTOR(29 downto 0)
);
end MUX_PkC_GrC_3;

architecture Behavioral of MUX_PkC_GrC_3 is
	-- Pipeline Register --
	signal VALID_REG0_READ : STD_LOGIC;
	signal VALID_REG1_STDP : STD_LOGIC;

	signal VALID_I_STDP : STD_LOGIC;
	signal VALID_O_STDP : STD_LOGIC;

--	signal END_SUM_delay0: STD_LOGIC;
	signal END_SUM_delay1: STD_LOGIC;
	signal END_SUM_delay2: STD_LOGIC;

	-- MUX --
	signal spk_cf_mux     : STD_LOGIC;
	signal spk_grc_mux    : STD_LOGIC;
	signal addr_cf_delay : STD_LOGIC_VECTOR(2 downto 0);
	signal addr_grc_delay : STD_LOGIC_VECTOR(9 downto 0);

	-- STDP & FIFO --
	signal INIT_MUX : STD_LOGIC_VECTOR(31 downto 0);
	signal read_g_weight_grc  : STD_LOGIC_VECTOR(0 downto 0);
	signal write_g_weight_grc : STD_LOGIC_VECTOR(16 downto 0);
	signal g_weight_grc_old   : STD_LOGIC_VECTOR(15 downto 0);
	signal g_weight_grc_new   : STD_LOGIC_VECTOR(15 downto 0);

	signal read_weight        : STD_LOGIC_VECTOR(0 downto 0);
	signal write_weight       : STD_LOGIC_VECTOR(16 downto 0);
	signal weight_old         : STD_LOGIC_VECTOR(15 downto 0);
	signal weight_new         : STD_LOGIC_VECTOR(15 downto 0);

	constant zeros :	std_logic_vector(31 downto 0) := (others=>'0');

  -- COMPONENT --
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

	COMPONENT FIFO_weight_pkc_grc_3
	PORT(
		CLK : IN  std_logic;
		RST : IN  std_logic;
		hem : IN  std_logic;
		READ1  : IN  std_logic_vector(0 downto 0);
		WRITE1 : IN  std_logic_vector(16 downto 0);
		DOUT1  : OUT std_logic_vector(15 downto 0)
	);
	END COMPONENT;

	COMPONENT FIFO_g_weight_grc
	PORT(
		CLK : IN  STD_LOGIC;
		RST : IN  STD_LOGIC;
		hem : IN  STD_LOGIC;
		READ1  : IN  STD_LOGIC_VECTOR(0 downto 0);
		WRITE1 : IN  STD_LOGIC_VECTOR(16 downto 0);
		DOUT1  : OUT STD_LOGIC_VECTOR(15 downto 0)
	);
	END COMPONENT;

	COMPONENT STDP_PkC_PF
	Port (
		CLK : in  STD_LOGIC;
		RST : in  STD_LOGIC;
		VALID_I : in  STD_LOGIC;
		VALID_O : out STD_LOGIC;
		-- constant --
		gum_LTD	: in  STD_LOGIC_VECTOR(31 downto 0);
		gum_LTP	: in  STD_LOGIC_VECTOR(31 downto 0);
		t_win		: in  STD_LOGIC_VECTOR(31 downto 0);
		INIT    : in  STD_LOGIC_VECTOR(31 downto 0);
		-- input --
		g_weight_grc_old : in  STD_LOGIC_VECTOR(15 downto 0);
		weight_old       : in  STD_LOGIC_VECTOR(15 downto 0);
		spk_grc          : in  STD_LOGIC;
		spk_cf           : in  STD_LOGIC;
		-- output --
		g_weight_grc_new : out STD_LOGIC_VECTOR(15 downto 0);
		weight_new       : out  STD_LOGIC_VECTOR(15 downto 0)
	);
	end COMPONENT;

begin
--- Valid  protocol -----------------------------------------------------------
	VALID_REG0_READ <= '1' when VALID_I='1' else
										 '0';

	process(CLK, RST) begin
	 if(RST='1') then
			VALID_REG1_STDP <= '0';
		elsif(CLK'event and CLK='1') then
			if(VALID_REG0_READ='1') then
				VALID_REG1_STDP <= '1';
			else
				VALID_REG1_STDP <= '0';
			end if;
		end if;
	end process;

	-- END signal
	process(CLK, RST) begin
		if(RST='1') then
			 END_SUM_delay1 <= '0';
		 elsif(CLK'event and CLK='1') then
			 if(END_SUM_I='1') then
				 END_SUM_delay1 <= '1';
			 else
				 END_SUM_delay1 <= '0';
			 end if;
		 end if;
	 end process;
-------------------------------------------------------------------------------

--- MUX -----------------------------------------------------------------------
	process(CLK, RST) begin
		if(RST='1') then
			spk_cf_mux <= '0';
		elsif(CLK'event and CLK='1') then
			if(VALID_REG0_READ='1') then
				spk_cf_mux <= spk_cf(  to_integer(unsigned(addr_cf))  );
			else
				spk_cf_mux <=  '0';
			end if;
		end if;
	end process;

	process(CLK, RST) begin
		if(RST='1') then
			spk_grc_mux <= '0';
		elsif(CLK'event and CLK='1') then
			if(VALID_REG0_READ='1') then
				spk_grc_mux <= spk_grc( to_integer(unsigned(addr_grc)) );
			else
				spk_grc_mux <= '0';
			end if;
		end if;
	end process;

	process(CLK, RST) begin
		if(CLK'event and CLK='1') then
			addr_cf_delay <= addr_cf;
			addr_grc_delay <= addr_grc;
		end if;
	end process;
-------------------------------------------------------------------------------

--- Access to RAM -------------------------------------------------------------
	READ_g_weight_grc  <= "1" when(VALID_REG0_READ='1') else
	                      "0";
	WRITE_g_weight_grc <= g_weight_grc_new & '1' when(VALID_O_STDP='1') else
	                      (others=>'0');

	FIFO_g_weight_grc_comp : FIFO_g_weight_grc Port MAP(
	  CLK => CLK,
	  RST => RST,
		hem => hem,
	  READ1  => READ_g_weight_grc,
	  WRITE1 => WRITE_g_weight_grc,
	  DOUT1  => g_weight_grc_old
	);

  READ_weight  <= "1" when(VALID_REG0_READ='1') else
	                (others=>'0');
  WRITE_weight <= weight_new & '1' when(VALID_O_STDP='1')   else
									(others=>'0');

  FIFO_weight_pkc_grc_comp: FIFO_weight_pkc_grc_3 PORT MAP(
		CLK => CLK,
		RST => RST,
		hem => hem,
		READ1  => READ_weight,
		WRITE1 => WRITE_weight,
		DOUT1  => weight_old
  );
-------------------------------------------------------------------------------

--- Calculate SynapticConductance ---------------------------------------------
	INIT_MUX <= INIT + (Num_MUX+1);

	VALID_I_STDP <= '1' when((VALID_REG1_STDP='1') and
	                         (gum_LTD/=zeros(15 downto 0)) and (gum_LTP/=zeros(31 downto 0))) else
	                '0';

  STDP_PkC_PF_COMP: STDP_PkC_PF Port MAP(
		CLK => CLK,
		RST => RST,
		VALID_I => VALID_I_STDP,
		VALID_O => VALID_O_STDP,
		-- constant --
		gum_LTD	=> gum_LTD,
		gum_LTP	=> gum_LTP,
		t_win		=> t_win,
		INIT    => INIT_MUX,
		-- input --
		g_weight_grc_old => g_weight_grc_old,
		weight_old       => weight_old,
		spk_grc => spk_grc_mux,
		spk_cf  => spk_cf_mux,
		-- output --
		g_weight_grc_new => g_weight_grc_new,
		weight_new => weight_new
	);
-------------------------------------------------------------------------------

---- Output -------------------------------------------------------------------
	process(CLK, RST) begin
		if(RST='1') then
			VALID_O <= '0';
		elsif(CLK'event and CLK='1') then
			if(VALID_REG0_READ='1') then
				VALID_O <= '1';
			else
				VALID_O <= '0';
			end if;
		end if;
	end process;

	process(CLK, RST) begin
		if(RST='1') then
			END_SUM_O <= '0';
		elsif(CLK'event and CLK='1') then
			if(END_SUM_delay1='1') then
				END_SUM_O <= '1';
			else
				END_SUM_O <= '0';
			end if;
		end if;
	end process;

	weight_syn <= weight_old when spk_grc_mux='1' else
	              (others=>'0');
	-- weight_syn <= weight_old when VALID_REG1_STDP='0' else (others=>'0');
	WRITE_weight_usb <= weight_old & addr_cf_delay & addr_grc_delay & VALID_REG1_STDP;
-------------------------------------------------------------------------------

end Behavioral;
