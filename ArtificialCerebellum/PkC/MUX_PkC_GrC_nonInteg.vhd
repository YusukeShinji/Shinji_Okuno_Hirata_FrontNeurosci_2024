-------------------------------------------------------------------------------
-- BSD 3-Clause License
-- Copyright (c) 2024, Yusuke Shinji
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.std_logic_misc.all;

entity MUX_PkC_GrC_0 is
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
	t_win       : in  STD_LOGIC_VECTOR(11 downto 0);
	INIT        : in  STD_LOGIC_VECTOR(31 downto 0);
	-- Input --
	addr_cf : in  STD_LOGIC_VECTOR(2 downto 0);
	addr_grc  : in  STD_LOGIC_VECTOR(9 downto 0);
	t_spk_grc : in  STD_LOGIC_VECTOR(1023 downto 0);
	t_spk_cf  : in  STD_LOGIC_VECTOR(7 downto 0);
	-- Output --
	weight_syn : out STD_LOGIC_VECTOR(15 downto 0)
);
end MUX_PkC_GrC_0;

architecture Behavioral of MUX_PkC_GrC_0 is
	-- Pipeline Register --
	signal VALID_REG0_READ : STD_LOGIC;
	signal VALID_REG1_CNT  : STD_LOGIC;
	signal VALID_REG2_STDP : STD_LOGIC;

	signal VALID_I_STDP : STD_LOGIC;
	signal VALID_O_STDP : STD_LOGIC;

--	signal END_SUM_delay0: STD_LOGIC;
	signal END_SUM_delay1: STD_LOGIC;
	signal END_SUM_delay2: STD_LOGIC;

	-- Delay --
	signal t_spk_cf_delay0 : STD_LOGIC;
	signal t_spk_cf_delay1 : STD_LOGIC;

	-- STDP & FIFO --
	signal INIT_MUX : STD_LOGIC_VECTOR(31 downto 0);
	signal read_t_spk    : STD_LOGIC_VECTOR(0 downto 0);
	signal write_t_spk   : STD_LOGIC_VECTOR(8 downto 0);
	signal t_spk_grc_old : STD_LOGIC_VECTOR(7 downto 0);
	signal t_spk_grc_new : STD_LOGIC_VECTOR(7 downto 0);

	signal read_weight  : STD_LOGIC_VECTOR(0 downto 0);
	signal write_weight : STD_LOGIC_VECTOR(16 downto 0);
	signal weight_old : STD_LOGIC_VECTOR(15 downto 0);
	signal weight_new : STD_LOGIC_VECTOR(15 downto 0);
	signal weight_delay0 : STD_LOGIC_VECTOR(15 downto 0);

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

	COMPONENT FIFO_weight_pkc_grc_0
	PORT(
		CLK : IN  std_logic;
		RST : IN  std_logic;
		hem : IN  std_logic;
		READ1  : IN  std_logic_vector(0 downto 0);
		WRITE1 : IN  std_logic_vector(16 downto 0);
		DOUT1  : OUT std_logic_vector(15 downto 0)
	);
	END COMPONENT;

	COMPONENT FIFO_t_spk_grc
	PORT(
		CLK : IN  STD_LOGIC;
		RST : IN  STD_LOGIC;
		hem : IN  STD_LOGIC;
		READ1  : IN  STD_LOGIC_VECTOR(0 downto 0);
		WRITE1 : IN  STD_LOGIC_VECTOR(8 downto 0);
		DOUT1  : OUT STD_LOGIC_VECTOR(7 downto 0)
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
		t_win		: in  STD_LOGIC_VECTOR(11 downto 0);
		INIT    : in  STD_LOGIC_VECTOR(31 downto 0);
		-- input --
		weight_old : in  STD_LOGIC_VECTOR(15 downto 0);
		t_spk_grc  : in  STD_LOGIC_VECTOR(7 downto 0);
		t_spk_cf   : in  STD_LOGIC;
		-- output --
		weight_new : out  STD_LOGIC_VECTOR(15 downto 0)
	);
	end COMPONENT;

begin
--- Valid  protocol -----------------------------------------------------------
	VALID_REG0_READ <= '1' when VALID_I='1' else
										 '0';

	process(CLK, RST) begin
		if RST='1' then
			VALID_REG1_CNT <= '0';
		elsif(CLK'event and CLK='1') then
			if(VALID_REG0_READ='1') then
				VALID_REG1_CNT <= '1';
			else
				VALID_REG1_CNT <= '0';
			end if;
		end if;
	end process;

	process(CLK, RST) begin
	 if(RST='1') then
			VALID_REG2_STDP <= '0';
		elsif(CLK'event and CLK='1') then
			if(VALID_REG1_CNT='1') then
				VALID_REG2_STDP <= '1';
			else
				VALID_REG2_STDP <= '0';
			end if;
		end if;
	end process;

-----------------------
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

	 process(CLK, RST) begin
		 if(RST='1') then
				END_SUM_delay2 <= '0';
			elsif(CLK'event and CLK='1') then
				if(END_SUM_delay1='1') then
					END_SUM_delay2 <= '1';
				else
					END_SUM_delay2 <= '0';
				end if;
			end if;
		end process;
-------------------------------------------------------------------------------

--- Delay ---------------------------------------------------------------------
	process(CLK, RST) begin
		if(CLK'event and CLK='1') then
			t_spk_cf_delay0 <= t_spk_cf( to_integer(unsigned(addr_cf)) );
			t_spk_cf_delay1 <= t_spk_cf_delay0;
			weight_delay0 <= weight_old;
		end if;
	end process;
-------------------------------------------------------------------------------

--- Count ---------------------------------------------------------------------
	process(CLK, RST) begin
	 if(RST='1') then
		 t_spk_grc_new <= "01111111";
	 elsif(CLK'event and CLK='1') then
		 if(VALID_REG1_CNT='1') then
			 if(t_spk_grc( to_integer(unsigned(addr_grc)) )='0') then
				 if(t_spk_grc_old<"01111111") then
					 t_spk_grc_new <= t_spk_grc_old+1;
				 else
					 t_spk_grc_new <= "01111111";
				 end if;
			 else
				 t_spk_grc_new <= (others=>'0');
			 end if;
		 end if;
	 end if;
	end process;
-------------------------------------------------------------------------------

--- Access to RAM -------------------------------------------------------------
	READ_t_spk <= "1" when VALID_REG0_READ='1' else
	              "0";
	WRITE_t_spk <= t_spk_grc_new & '1' when VALID_REG2_STDP='1' else
	               (others=>'0');

	FIFO_t_spk_grc_comp : FIFO_t_spk_grc Port MAP(
	  CLK => CLK,
	  RST => RST,
		hem => hem,
	  READ1  => READ_t_spk,
	  WRITE1 => WRITE_t_spk,
	  DOUT1  => t_spk_grc_old
	);


  READ_weight  <= "1" when VALID_REG0_READ='1' else
	                (others=>'0');
  WRITE_weight <= weight_new & '1' when VALID_O_STDP='1'   else
									(others=>'0');

  FIFO_weight_pkc_grc_comp: FIFO_weight_pkc_grc_0 PORT MAP(
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

	VALID_I_STDP <= '1' when VALID_REG2_STDP='1' else
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
		weight_old => weight_delay0,
		t_spk_grc  => t_spk_grc_new,
		t_spk_cf   => t_spk_cf_delay1,
		-- output --
		weight_new => weight_new
	);
-------------------------------------------------------------------------------

---- Output -------------------------------------------------------------------
	process(CLK, RST) begin
		if RST='1' then
			VALID_O <= '0';
		elsif(CLK'event and CLK='1') then
			if VALID_REG2_STDP='1' then
				VALID_O <= '1';
			else
				VALID_O <= '0';
			end if;
		end if;
	end process;

	process(CLK, RST) begin
		if RST='1' then
			END_SUM_O <= '0';
		elsif(CLK'event and CLK='1') then
			if END_SUM_delay2='1' then
				END_SUM_O <= '1';
			else
				END_SUM_O <= '0';
			end if;
		end if;
	end process;

	weight_syn <= weight_delay0 when t_spk_grc_new="00000000" else
	              (others=>'0');
-------------------------------------------------------------------------------

end Behavioral;
