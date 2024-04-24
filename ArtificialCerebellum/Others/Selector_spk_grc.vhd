-------------------------------------------------------------------------------
-- BSD 3-Clause License
-- Copyright (c) 2024, Yusuke Shinji
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
--library UNISIM;
--use UNISIM.VComponents.all;
use ieee.std_logic_unsigned.all;
use IEEE.std_logic_misc.all;

entity Selector_spk_grc is
Port (
	CLK : in  STD_LOGIC;
	RST : in  STD_LOGIC;
  hem : in  STD_LOGIC;
  VALID_O_MF : in  STD_LOGIC;
	spk_grc    : in  STD_LOGIC_VECTOR(4095 downto 0);
  WOUT1      : out STD_LOGIC_VECTOR(28 downto 0)
);
end Selector_spk_grc;

architecture Behavioral of Selector_spk_grc is
  signal ena_str    : STD_LOGIC := '0';
  signal ena        : STD_LOGIC;
  signal ena_delay0 : STD_LOGIC := '0';
  signal ena_delay1 : STD_LOGIC := '0';
  signal ena_delay2 : STD_LOGIC := '0';

	signal spks           : STD_LOGIC_VECTOR(7 downto 0);
  signal cnt_spk        : STD_LOGIC_VECTOR(7 downto 0) := (others=>'0');
  signal cnt_addr       : STD_LOGIC_VECTOR(11 downto 0) := (others=>'0');
  signal cnt_addr_delay : STD_LOGIC_VECTOR(11 downto 0) := (others=>'0');
  signal cnt_addr_max   : STD_LOGIC_VECTOR(11 downto 0); -- 4095-1
  signal cnt_addr_min   : STD_LOGIC_VECTOR(11 downto 0); -- 4095-1
  signal cnt_addr_max_max   : STD_LOGIC_VECTOR(11 downto 0) := "111111111110"; -- 4095-1
  signal cnt_addr_ub    : STD_LOGIC_VECTOR(4 downto 0) := (others=>'0');

  signal write_fifo : STD_LOGIC_VECTOR(8 downto 0);
  signal read_fifo  : std_logic_vector(0 downto 0);
  signal data_fifo  : STD_LOGIC_VECTOR(7 downto 0);

  signal enable : STD_LOGIC;
  signal data   : STD_LOGIC_VECTOR(7 downto 0);
  constant xaddr_min : STD_LOGIC_VECTOR(16 downto 0) := "00000000101011011"; --  90+256+1
  signal xaddr : STD_LOGIC_VECTOR(16 downto 0) := xaddr_min;
	constant RAMID  : std_logic_vector(2 downto 0) := "000";

  COMPONENT FIFO_spks_GrC
  PORT(
    CLK : IN  std_logic;
    RST : IN  std_logic;
    READ1  : IN  std_logic_vector(0 downto 0);
    WRITE1 : IN  std_logic_vector(8 downto 0);
    DOUT1  : OUT std_logic_vector(7 downto 0)
  );
  END COMPONENT;

begin
-------------------------------------------------------------------------------
  process(CLK, RST) begin
    if RST='1' then
      ena <= '0';
    elsif rising_edge(CLK) then
      if VALID_O_MF='1' and hem='1' then
        ena <= '1';
      elsif (cnt_addr=cnt_addr_max_max) then
        ena <= '0';
      end if;
    end if;
  end process;

  process(CLK, RST) begin
    if rising_edge(CLK) then
      ena_delay0 <= ena;
      ena_delay1 <= ena_delay0;
      ena_delay2 <= ena_delay1;
    end if;
  end process;
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
	spks <= ("0000000"&spk_grc(to_integer(unsigned(cnt_addr))));

  process(CLK, RST) begin
    if RST='1' then
      cnt_spk <= (others=>'0');
    elsif rising_edge(CLK) then
      if ena_delay0='1' then
				if enable='1' then
					cnt_spk <= spks;
				else
					cnt_spk <= data_fifo + spks;
				end if;
      end if;
    end if;
  end process;

  process(CLK, RST) begin
    if RST='1' then
      cnt_addr <= (others=>'0');
    elsif rising_edge(CLK) then
      if ena_delay0='1' then
        cnt_addr <= cnt_addr + 1;
      else
        cnt_addr <= (others=>'0');
      end if;
    end if;
  end process;

  process(CLK, RST) begin
    if rising_edge(CLK) then
      cnt_addr_delay <= cnt_addr;
    end if;
  end process;

  process(CLK, RST) begin
    if RST='1' then
      cnt_addr_ub <= (others=>'0');
    elsif rising_edge(CLK) then
      if (cnt_addr=cnt_addr_max_max) then
        cnt_addr_ub <= cnt_addr_ub + 1;
      end if;
    end if;
  end process;
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
  read_fifo  <= "1"                   when ena='1'        else
                "0";
  write_fifo <= (0=>'1', others=>'0') when enable='1'     else -- reset to 0
                (data&'1')            when ena_delay2='1' else -- write data
                (others=>'0');

  FIFO_spks_GrC_comp: FIFO_spks_GrC PORT MAP(
  	CLK => CLK,
  	RST => RST,
  	READ1  => read_fifo,
  	WRITE1 => write_fifo,
  	DOUT1  => data_fifo
  );
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
  cnt_addr_max  <= (cnt_addr_ub&"1111111"); -- * 128 bit + 128 bit
  cnt_addr_min  <= (cnt_addr_ub&"0000000"); -- * 128 bit

  process(CLK, RST) begin
    if RST='1' then
      enable <= '0';
		elsif rising_edge(CLK) then
      if ena_delay1   = '1' and
         cnt_addr_min   <= cnt_addr_delay and
         cnt_addr_delay <= cnt_addr_max then
        enable <= '1';
      else
        enable <= '0';
      end if;
		end if;
	end process;

  process(CLK, RST) begin
    if RST='1' then
      data <= (others=>'0');
		elsif rising_edge(CLK) then
			data   <= cnt_spk;
		end if;
	end process;

  process(CLK, RST) begin
    if RST='1' then
      xaddr <= xaddr_min;
		elsif rising_edge(CLK) then
			xaddr <= xaddr_min + ("0000000000"&cnt_addr_delay(6 downto 0)); -- time pathed 32 ms ( = 5 bit)
		end if;
	end process;
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
  WOUT1 <= data & xaddr & enable & RAMID;
-------------------------------------------------------------------------------
end Behavioral;
