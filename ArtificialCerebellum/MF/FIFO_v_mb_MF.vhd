-------------------------------------------------------------------------------
-- BSD 3-Clause License
-- Copyright (c) 2024, Yusuke Shinji
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity FIFO_v_mb_MF is
Port (
  CLK : in  STD_LOGIC;
  RST : in  STD_LOGIC;
	hem : in  STD_LOGIC;
  READ1  : in  STD_LOGIC_VECTOR(0 downto 0);
  WRITE1 : in  STD_LOGIC_VECTOR(16 downto 0);
  DOUT1  : out STD_LOGIC_VECTOR(15 downto 0)
);
end FIFO_v_mb_MF;

architecture Behavioral of FIFO_v_mb_MF is
	signal R_ADDR : STD_LOGIC_VECTOR(7 downto 0) := (others=>'0');
	signal W_ADDR : STD_LOGIC_VECTOR(7 downto 0) := (others=>'0');

	signal BRAM1_EN_W :std_logic;	-- ena = W_Enable %% write enable
	signal BRAM1_EN_R :std_logic;	-- enb = R_Enable %% write enable
	signal BRAM1_WE     :std_logic_vector(0 downto 0);	-- wea   = W_Enable	%% write enable
	signal BRAM1_ADDR_W :std_logic_vector(7 downto 0);	-- addra = W_ADDR	%% write addres
	signal BRAM1_ADDR_R :std_logic_vector(7 downto 0);	-- addra = R_ADDR	%% read  addres
	signal BRAM1_DIN    :std_logic_vector(15 downto 0);	-- dina  = DIN		%% write DATA
--	signal BRAM1_DOUT   :std_logic_vector(15 downto 0);	-- doutb = DOUT1	%% read  DATA

  signal BRAM1_EN_W_LH :std_logic;	-- ena = W_Enable %% write enable
  signal BRAM1_EN_R_LH :std_logic;	-- enb = R_Enable %% write enable
  signal BRAM1_WE_LH   :std_logic_vector(0 downto 0);	-- wea   = W_Enable	%% write enable
  signal BRAM1_DOUT_LH :std_logic_vector(15 downto 0);	-- doutb = DOUT1	%% read  DATA

  signal BRAM1_EN_W_RH :std_logic;	-- ena = W_Enable %% write enable
  signal BRAM1_EN_R_RH :std_logic;	-- enb = R_Enable %% write enable
  signal BRAM1_WE_RH   :std_logic_vector(0 downto 0);	-- wea   = W_Enable	%% write enable
  signal BRAM1_DOUT_RH :std_logic_vector(15 downto 0);	-- doutb = DOUT1	%% read  DATA

	component ramb_dual2_v_mb_MF
		port (
			clka: IN std_logic;
			ena: IN std_logic;
			wea: IN std_logic_VECTOR(0 downto 0);
			addra: IN std_logic_VECTOR(7 downto 0);
			dina: IN std_logic_VECTOR(15 downto 0);
			clkb: IN std_logic;
			enb: IN std_logic;
			addrb: IN std_logic_VECTOR(7 downto 0);
			doutb: OUT std_logic_VECTOR(15 downto 0)
		);
	end component;

begin
---- Write-in control -------------------------------------------------------

	-- Enable --
  BRAM1_EN_W <= '1' when (WRITE1(0)='1') else
                '0';
  BRAM1_WE(0) <= '1' when (WRITE1(0)='1') else
                 '0';

  BRAM1_EN_W_LH <= BRAM1_EN_W when (hem='0') else
                   '0';
  BRAM1_WE_LH(0) <= BRAM1_WE(0) when (hem='0') else
                    '0';
  BRAM1_EN_W_RH <= BRAM1_EN_W when (hem='1') else
                   '0';
  BRAM1_WE_RH(0) <= BRAM1_WE(0) when (hem='1') else
                    '0';

	-- Address--
	process(CLK, RST) begin
		if RST='1' then
			W_ADDR <= (others=>'0');
		elsif rising_edge(CLK) then
			if WRITE1(0)='1' then
				W_ADDR <= W_ADDR +1;
			end if;
		end if;
	end process;

	BRAM1_ADDR_W <= W_ADDR;

	-- InputData --
  BRAM1_DIN <= WRITE1(16 downto 1) when (WRITE1(0)='1') else
               (others=>'0');
-------------------------------------------------------------------------------

---- Read-out control ---------------------------------------------------------

	-- Enable --
  BRAM1_EN_R <= '1' when READ1(0)='1' else
                '0';
  BRAM1_EN_R_LH <= BRAM1_EN_R when hem='0' else
                   '0';
  BRAM1_EN_R_RH <= BRAM1_EN_R when hem='1' else
                   '0';

	-- Address --
	process(CLK, RST) begin
		if RST='1' then
			R_ADDR <= (others=>'0');
		elsif rising_edge(CLK) then
			if READ1(0)='1' then
				R_ADDR <= R_ADDR +1;
			end if;
		end if;
	end process;

	BRAM1_ADDR_R <= R_ADDR;

	-- OutputData --
	DOUT1 <= BRAM1_DOUT_RH when hem='1' else
           BRAM1_DOUT_LH;
-------------------------------------------------------------------------------

---- RAM port map -------------------------------------------------------------
  Hem_L : ramb_dual2_v_mb_MF
    port map (
      clka => CLK,
      ena => BRAM1_EN_W_LH,
      wea => BRAM1_WE_LH,
      addra => BRAM1_ADDR_W,
      dina => BRAM1_DIN,
      clkb => CLK,
      enb => BRAM1_EN_R_LH,
      addrb => BRAM1_ADDR_R,
      doutb => BRAM1_DOUT_LH
    );

  Hem_R : ramb_dual2_v_mb_MF
    port map (
      clka => CLK,
      ena => BRAM1_EN_W_RH,
      wea => BRAM1_WE_RH,
      addra => BRAM1_ADDR_W,
      dina => BRAM1_DIN,
      clkb => CLK,
      enb => BRAM1_EN_R_RH,
      addrb => BRAM1_ADDR_R,
      doutb => BRAM1_DOUT_RH
    );
-------------------------------------------------------------------------------
end Behavioral;
