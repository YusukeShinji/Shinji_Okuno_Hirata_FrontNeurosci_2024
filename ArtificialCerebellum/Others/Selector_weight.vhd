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

entity Selector_weight is
Port (
	CLK : in STD_LOGIC;
	RST : in STD_LOGIC;
  hem : in STD_LOGIC;
  START_SIM : in STD_LOGIC;
	write_weight_syns : in STD_LOGIC_VECTOR(77 downto 0);
  WOUT1 : out STD_LOGIC_VECTOR(28 downto 0)
);
end Selector_weight;

architecture Behavioral of Selector_weight is
  signal weight  : STD_LOGIC_VECTOR(63 downto 0);
  signal cell    : STD_LOGIC_VECTOR(2 downto 0);
  signal syn     : STD_LOGIC_VECTOR(9 downto 0);
  signal ena     : STD_LOGIC := '0';
	signal ena_str : STD_LOGIC := '0';
  signal ena_cnt : STD_LOGIC := '0';

  signal cnt_syn  : STD_LOGIC_VECTOR(4 downto 0) := (others=>'0');
  signal cnt_core : STD_LOGIC_VECTOR(4 downto 0) := (others=>'0');
  signal cnt_cell : STD_LOGIC_VECTOR(4 downto 0) := (others=>'0');
  constant cnt_syn_max  : STD_LOGIC_VECTOR(4 downto 0) := "00111"; -- 8 synapses
  constant cnt_core_max : STD_LOGIC_VECTOR(4 downto 0) := "00011"; -- 4 cores
  constant cnt_cell_max : STD_LOGIC_VECTOR(4 downto 0) := "00000";--"00111"; -- 8 cells

  signal syn_max : STD_LOGIC_VECTOR(9 downto 0);
  signal syn_min : STD_LOGIC_VECTOR(9 downto 0);
  signal addr_w_l : INTEGER :=15;
  signal addr_w_m : INTEGER :=0;

  signal write_weight_fifo_ENA : STD_LOGIC;
  signal write_weight_fifo     : STD_LOGIC_VECTOR(16 downto 0);
  signal read_weight_fifo      : std_logic_vector(0 downto 0);
  signal weight_fifo : STD_LOGIC_VECTOR(15 downto 0);

  signal VALID_weight_data_0 : STD_LOGIC;
  signal VALID_weight_data_1 : STD_LOGIC;
  signal VALID_weight_data_2 : STD_LOGIC;
	signal cnt_valid_weight_data : STD_LOGIC_VECTOR(0 downto 0) := "0";
  signal addr_l : INTEGER :=7;
  signal addr_m : INTEGER :=0;
  signal data   : STD_LOGIC_VECTOR(7 downto 0);
  signal enable : STD_LOGIC;

  constant xaddr_max : STD_LOGIC_VECTOR(16 downto 0) := "00000000101011001"; -- 345
  constant xaddr_min : STD_LOGIC_VECTOR(16 downto 0) := "00000000001011010"; --  90
  signal xaddr : STD_LOGIC_VECTOR(16 downto 0) := xaddr_min;
	constant RAMID  : std_logic_vector(2 downto 0) := "000";

  COMPONENT FIFO_WEIGHT
  PORT(
    CLK : IN  std_logic;
    RST : IN  std_logic;
    READ1  : IN  std_logic_vector(0 downto 0);
    WRITE1 : IN  std_logic_vector(16 downto 0);
    DOUT1  : OUT std_logic_vector(15 downto 0)
  );
  END COMPONENT;

begin
-------------------------------------------------------------------------------
  weight <= write_weight_syns(77 downto 14);
  cell   <= write_weight_syns(13 downto 11);
  syn    <= write_weight_syns(10 downto 1);
  ena    <= write_weight_syns(0);

  process(CLK, RST) begin
		if RST='1' then
      ena_str <= '0';
    elsif rising_edge(CLK) then
      if START_SIM='1' and hem='1' then
	      ena_str <= '1';
	    elsif (syn  = syn_max) and
						(cell = cnt_cell) then
	      ena_str <= '0';
	    end if;
		end if;
  end process;

	process(CLK, RST) begin
    if RST='1' then
      ena_cnt <= '0';
    elsif rising_edge(CLK) then
      if (ena_str = '1') and
			   (syn  = syn_max) and
			   (cell = cnt_cell) then
				ena_cnt <= '1';
			else
				ena_cnt <= '0';
      end if;
    end if;
  end process;
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
  process(CLK, RST) begin
    if RST='1' then
      cnt_syn <= (others=>'0');
    elsif rising_edge(CLK) then
      if ena_cnt='1' then
        if cnt_syn=cnt_syn_max then
          cnt_syn <= (others=>'0');
        else
          cnt_syn <= cnt_syn + 1;
        end if;
      end if;
    end if;
  end process;

  process(CLK, RST) begin
    if RST='1' then
      cnt_core <= (others=>'0');
    elsif rising_edge(CLK) then
      if ena_cnt='1' then
        if cnt_syn=cnt_syn_max then
          if cnt_core=cnt_core_max then
            cnt_core <= (others=>'0');
          else
            cnt_core <= cnt_core + 1;
          end if;
        end if;
      end if;
    end if;
  end process;

  process(CLK, RST) begin
    if RST='1' then
      cnt_cell <= (others=>'0');
    elsif rising_edge(CLK) then
      if ena_cnt='1' then
        if cnt_syn=cnt_syn_max and cnt_core=cnt_core_max then
          if cnt_cell=cnt_cell_max then
            cnt_cell <= (others=>'0');
          else
            cnt_cell <= cnt_cell + 1;
          end if;
        end if;
      end if;
    end if;
  end process;
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
  syn_max  <= (cnt_syn(2 downto 0)&"1111111"); -- * 128 bit + 128 bit
  syn_min  <= (cnt_syn(2 downto 0)&"0000000"); -- * 128 bit
  addr_w_l <= to_integer(unsigned(cnt_core(1 downto 0))&"1111"); -- * 16 bit + 16 bit
  addr_w_m <= to_integer(unsigned(cnt_core(1 downto 0))&"0000"); -- * 16 bit

  write_weight_fifo_ENA <= '1' when (syn_min<=syn) and (syn<=syn_max) and
                                    (cell = cnt_cell) and
                                    (ena_str = '1') and
																	  (ena     = '1') else
                           '0';

	process(CLK, RST) begin
		if RST='1' then
      write_weight_fifo <= (others=>'0');
    elsif rising_edge(CLK) then
			if write_weight_fifo_ENA='1' then
	      write_weight_fifo <= (weight(addr_w_l downto addr_w_m)) & '1';
			else
				write_weight_fifo <= (others=>'0');
			end if;
    end if;
  end process;
--  write_weight_fifo <= (weight(addr_w_l downto addr_w_m)) & '1' when write_weight_fifo_ENA='1' else
--                      (others=>'0');

  FIFO_WEIGHT_comp: FIFO_WEIGHT PORT MAP(
  	CLK => CLK,
  	RST => RST,
  	READ1  => read_weight_fifo,
  	WRITE1 => write_weight_fifo,
  	DOUT1  => weight_fifo
  );

  process(CLK, RST) begin
    if rising_edge(CLK) then
      VALID_weight_data_0 <= write_weight_fifo_ENA;
      VALID_weight_data_1 <= VALID_weight_data_0;
      VALID_weight_data_2 <= VALID_weight_data_1;
    end if;
  end process;

	process(CLK, RST) begin
		if rising_edge(CLK) then
			if RST='1' then
				cnt_valid_weight_data <= "0";
			elsif (VALID_weight_data_1='1') or (VALID_weight_data_2='1') then
				cnt_valid_weight_data <= cnt_valid_weight_data + 1;
			end if;
		end if;
	end process;

  read_weight_fifo <= "1" when (VALID_weight_data_2='1') and (cnt_valid_weight_data="0") else
	                    "0";
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
  addr_l <= 15 when cnt_valid_weight_data="0" else
             7 when cnt_valid_weight_data="1";
  addr_m <=  8 when cnt_valid_weight_data="0" else
             0 when cnt_valid_weight_data="1";

  data   <= weight_fifo(addr_l downto addr_m);
  enable <= '1' when VALID_weight_data_1='1' or VALID_weight_data_2='1' else
            '0';

  process(CLK, RST) begin
    if RST='1' then
      xaddr <= xaddr_min;
		elsif rising_edge(CLK) then
			if enable='1' then
        if xaddr>=xaddr_max then
          xaddr <= xaddr_min;
        else
		      xaddr <= xaddr + 1;
        end if;
			end if;
		end if;
	end process;
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
  WOUT1 <= data & xaddr & enable & RAMID;
-------------------------------------------------------------------------------
end Behavioral;
