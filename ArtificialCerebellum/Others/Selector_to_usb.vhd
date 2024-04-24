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

entity Selector_to_usb is
Port (
	CLK : in STD_LOGIC;
	RST : in STD_LOGIC;
	-- Sim Data --
	hem         : in  STD_LOGIC;
	START_SIM   : in  STD_LOGIC;
	VALID_O_MF  : in  STD_LOGIC;
	time_sim    : in  STD_LOGIC_VECTOR(31 downto 0);
	CONMSR      : in  STD_LOGIC_VECTOR(31 downto 0);
	COM         : in  STD_LOGIC_VECTOR(31 downto 0);
	ERR         : in  STD_LOGIC_VECTOR(31 downto 0);
	DSR         : in  STD_LOGIC_VECTOR(31 downto 0);
	PID         : in  STD_LOGIC_VECTOR(31 downto 0);
	spkmean_L   : in  STD_LOGIC_VECTOR(31 downto 0);
	spkmean_R   : in  STD_LOGIC_VECTOR(31 downto 0);
	spk_MF      : in  STD_LOGIC_VECTOR(245 downto 0);
	spk_CF      : in  STD_LOGIC_VECTOR(7 downto 0);
	spk_GrC     : in  STD_LOGIC_VECTOR(4095 downto 0);
	spk_GoC     : in  STD_LOGIC_VECTOR(368 downto 0);
	spk_PkC     : in  STD_LOGIC_VECTOR(7 downto 0);
	spk_BkC     : in  STD_LOGIC_VECTOR(24 downto 0);
  write_weight_syns : in STD_LOGIC_VECTOR(77 downto 0);
	-- To RAM --
	WOUT1 : out  STD_LOGIC_VECTOR(28 downto 0)
);
end Selector_to_usb;

architecture Behavioral of Selector_to_usb is

	signal spk_MF8bit : std_logic_vector(7 downto 0);
	signal spk_GrC8bit : std_logic_vector(7 downto 0);
	signal spk_GoC8bit : std_logic_vector(7 downto 0);
	signal spk_BkC8bit : std_logic_vector(7 downto 0);

	signal bufnum : INTEGER := 0;
	constant buf0 : INTEGER := 0;
	constant buf1 : INTEGER := 508;
	constant buf2 : INTEGER := 1015;
	constant buf3 : INTEGER := 1523;

	signal time_sim_buf : std_logic_vector(1 downto 0) := (others=>'0');

	signal WOUT1_stim   : STD_LOGIC_VECTOR(28 downto 0);
	signal WOUT1_weight : STD_LOGIC_VECTOR(28 downto 0);
	signal WOUT1_spk    : STD_LOGIC_VECTOR(28 downto 0);

	signal enable   : std_logic := '0';
	signal data     : std_logic_vector(7 downto 0) := (others=>'0');
	signal xaddr    : std_logic_vector(16 downto 0) := (others=>'0');
	constant RAMID  : std_logic_vector(2 downto 0) := "000";

	COMPONENT Selector_spk_grc
  PORT(
		CLK : in  STD_LOGIC;
		RST : in  STD_LOGIC;
	  hem : in  STD_LOGIC;
	  VALID_O_MF : in  STD_LOGIC;
		spk_grc    : in  STD_LOGIC_VECTOR(4095 downto 0);
	  WOUT1      : out STD_LOGIC_VECTOR(28 downto 0)
    );
  END COMPONENT;

  COMPONENT Selector_weight
  PORT(
    CLK : IN std_logic;
    RST : IN std_logic;
    hem : IN std_logic;
    START_SIM : IN std_logic;
    write_weight_syns : IN std_logic_vector(77 downto 0);
    WOUT1 : OUT std_logic_vector(28 downto 0)
    );
  END COMPONENT;

  COMPONENT Selector_stim
  PORT(
    CLK : IN std_logic;
    RST : IN std_logic;
    hem : IN std_logic;
    START_SIM : IN std_logic;
    time_sim : IN std_logic_vector(31 downto 0);
    CONMSR : IN std_logic_vector(31 downto 0);
    COM : IN std_logic_vector(31 downto 0);
    ERR : IN std_logic_vector(31 downto 0);
    DSR : IN std_logic_vector(31 downto 0);
    PID : IN std_logic_vector(31 downto 0);
    spkmean_L : IN std_logic_vector(31 downto 0);
    spkmean_R : IN std_logic_vector(31 downto 0);
    spk_MF : IN std_logic_vector(7 downto 0);
    spk_CF : IN std_logic_vector(7 downto 0);
    spk_GrC : IN std_logic_vector(7 downto 0);
    spk_GoC : IN std_logic_vector(7 downto 0);
    spk_PkC : IN std_logic_vector(7 downto 0);
    spk_BkC : IN std_logic_vector(7 downto 0);
    WOUT1 : OUT std_logic_vector(28 downto 0)
    );
  END COMPONENT;

begin
--- COMPONENT -----------------------------------------------------------------
	spk_MF8bit <= (spk_MF(0)   &
		            spk_MF(204) &
							  spk_MF(14)  &
							  spk_MF(215) &
							  spk_MF(14)  &
							  spk_MF(159) &
							  spk_MF(231) &
							  spk_MF(245));
	spk_GrC8bit <= (spk_GrC(0)    &
		            spk_GrC(767)  &
							  spk_GrC(2653) &
							  spk_GrC(507)  &
							  spk_GrC(1198) &
							  spk_GrC(2653) &
							  spk_GrC(1503) &
							  spk_GrC(4095));
	spk_GoC8bit <= (spk_GoC(0)   &
		            spk_GoC(63)  &
							  spk_GoC(251) &
							  spk_GoC(163) &
							  spk_GoC(345) &
							  spk_GoC(251) &
							  spk_GoC(264) &
							  spk_GoC(368));
	spk_BkC8bit <= (spk_BkC(0)  &
		            spk_BkC(13) &
							  spk_BkC(19) &
							  spk_BkC(22) &
							  spk_BkC(7)  &
		            spk_BkC(14) &
							  spk_BkC(6)  &
							  spk_BkC(24));

  Inst_Selector_stim: Selector_stim PORT MAP(
    CLK => CLK,
    RST => RST,
    hem => hem,
    START_SIM => START_SIM,
    time_sim => time_sim,
    CONMSR => CONMSR,
    COM => COM,
    ERR => ERR,
    DSR => DSR,
    PID => PID,
    spkmean_L => spkmean_L,
    spkmean_R => spkmean_R,
    spk_MF =>  spk_MF8bit,
    spk_CF =>  spk_CF,
    spk_GrC => spk_GrC8bit,
    spk_GoC => spk_GoC8bit,
    spk_PkC => spk_PkC,
    spk_BkC => spk_BkC8bit,
    WOUT1 => WOUT1_stim
  );

  Inst_Selector_weight: Selector_weight PORT MAP(
    CLK => CLK,
    RST => RST,
    hem => hem,
    START_SIM => START_SIM,
    write_weight_syns => write_weight_syns,
    WOUT1 => WOUT1_weight
  );

	Inst_Selector_spk_grc: Selector_spk_grc PORT MAP(
		CLK => CLK,
		RST => RST,
		hem => hem,
		VALID_O_MF => VALID_O_MF,
		spk_grc    => spk_grc,
		WOUT1      => WOUT1_spk
	);
-------------------------------------------------------------------------------

--- Set Data ------------------------------------------------------------------
  process(CLK, RST) begin
    if RST='1' then
      time_sim_buf <= (others=>'0');
    elsif rising_edge(CLK) then
      time_sim_buf <= "0"&time_sim(0 downto 0);
    end if;
  end process;

  process(CLK, RST) begin
    if RST='1' then
      bufnum <= 0;
    elsif rising_edge(CLK) then
      case time_sim_buf is
				when "00" => bufnum <= buf0;
				when "01" => bufnum <= buf1;
				when "10" => bufnum <= buf2;
				when "11" => bufnum <= buf3;
				when others => bufnum <= buf0;
			end case;
    end if;
  end process;

  process(CLK, RST) begin
    if RST='1' then
			data <= (others=>'0');
		elsif rising_edge(CLK) then
      if WOUT1_stim(3)='1' then
        data <= WOUT1_stim(28 downto 21);
      elsif WOUT1_weight(3)='1' then
        data <= WOUT1_weight(28 downto 21);
      elsif WOUT1_spk(3)='1' then
        data <= WOUT1_spk(28 downto 21);
      end if;
    end if;
  end process;

	process(CLK, RST) begin
    if RST='1' then
			xaddr <= (others=>'0');
		elsif rising_edge(CLK) then
			if WOUT1_stim(3)='1' then
				xaddr <= WOUT1_stim(20 downto 4) + std_logic_vector(to_unsigned(bufnum, 17));
    	elsif WOUT1_weight(3)='1' then
    		xaddr <= WOUT1_weight(20 downto 4) +std_logic_vector(to_unsigned(bufnum, 17));
    	elsif WOUT1_spk(3)='1' then
    		xaddr <= WOUT1_spk(20 downto 4) +std_logic_vector(to_unsigned(bufnum, 17));
      else
        xaddr <= (others=>'0');
			end if;
		end if;
	end process;

	process(CLK, RST) begin
		if RST='1' then
			enable <= '0';
		elsif rising_edge(CLK) then
			if WOUT1_stim(3)='1' or WOUT1_weight(3)='1' or WOUT1_spk(3)='1' then
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
