--------------------------------------------------------------------------------
-- BSD 3-Clause License
-- Copyright (c) 2024, Hirotsugu Okuno
-- Copyright (c) 2024, Yusuke Shinji
--
-- EzUsb Controller rev. 1.00 (2008/12/05)
-- EzUsb Controller rev. 1.01 (2010/11/02)
--		"Delay = 2" was enabled.
-- EzUsb Controller rev. 1.02 (2011/07/08)
--		CLK timing was optimized.
-- EzUsb Controller rev. 2.00 (2012/07/09)
--		CLK timing was optimized for Spartan 6.
-- EzUsb Controller rev. 2.01 (2013/05/03)
-- 		SLRD was wired for internal ctrl.
-- EzUsb Controller rev. 2.02 (2013/05/05)
-- 		IMG_ADDR_X, and Y were added.
-- EzUsb Controller rev. 3.00 (2013/12/21)
-- 		USB_ACTIVE was added.
-- EzUsb Controller rev. 3.10 (2015/10/13)
-- 		Common platform bus was implemented.
--		Source codes were rearranged.
-- EzUsb Controller rev. 3.11 (2024/4/16)
-- 		Buf size was changed.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

---- Uncomment the following library declaration if instantiating
---- any Xilinx primitives in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity EZUSBctrlv31_QQVGA is
	port(
		CLK				:in		std_logic;
		RESET			:in		std_logic;
		SEND_START		:in		std_logic;
		USB_FLAGB		:in		std_logic;
		USB_FLAGC		:in		std_logic;
		IMAGE_DATA		:in		std_logic_vector(7 downto 0);
		APPEND_DATA		:in		std_logic_vector(7 downto 0);
		FRAME_NUMBER	:in		std_logic_vector(7 downto 0);
		TX_ACTIVE		:out	std_logic;
		RX_ACTIVE		:out	std_logic;
		USB_CLK			:out	std_logic;
		USB_nRESET		:out	std_logic;
		USB_PKTEND		:out	std_logic;
		USB_SLOE		:out	std_logic;
		USB_SLRD		:out	std_logic;
		USB_SLRD_INTNL	:out	std_logic;
		USB_SLWR		:out	std_logic;
		USB_FIFOADDR	:out	std_logic_vector(1 downto 0);
		USB_FD			:inout	std_logic_vector(7 downto 0);
		IMAGE_NUMBER	:out	std_logic_vector(3 downto 0);
		APPEND_ADDR		:out	std_logic_vector(8 downto 0);
		TX_ROUT			:out	std_logic_vector(20 downto 0);
		RX_WOUT			:out	std_logic_vector(28 downto 0)
		);
end EZUSBctrlv31_QQVGA;

architecture Behavioral of EZUSBctrlv31_QQVGA is
	attribute	keep				: string;
	signal		DCLK				: std_logic;
	attribute	keep of DCLK		: signal is "true";
	signal		RESET_COUNT			: std_logic_vector(15 downto 0);
	signal		START_DLY			: std_logic;
	signal		START_DLY2			: std_logic;
	signal		START_UP			: std_logic;
	signal		SENDING				: std_logic;
	signal		SENDING_DLY			: std_logic;
	signal		USB_ACTIVE			: std_logic;
	signal		APPEND_DATA_EN		: std_logic;
	signal		APPEND_DATA_EN_PRE	: std_logic_vector(1 downto 0);
	signal		USB_SLWR_IN			: std_logic;
	signal		USB_SLRD_IN			: std_logic;
	signal		USB_PKTEND_IN		: std_logic;
	signal		USB_SLRD_DLY		: std_logic;
	signal		USB_DOUT_IN			: std_logic_vector(7 downto 0);
	signal		USB_DOUT			: std_logic_vector(7 downto 0);
	signal		UNIT_COUNT_EN		: std_logic;
	signal		UNIT_COUNT_EN_DLY	: std_logic;
	signal		UNIT_COUNT_END		: std_logic;
	signal		UNIT_COUNT			: std_logic_vector(11 downto 0);
	signal		SEND_DATA			: std_logic_vector(7 downto 0);
	signal		IMG_ADDR			: std_logic_vector(16 downto 0);
	signal		IMG_NUMBER			: std_logic_vector(3 downto 0);
	signal		count_addrx			: std_logic_vector(16 downto 0);
--	signal		count_addrx			: std_logic_vector(11 downto 0);
	signal		count_addry			: std_logic_vector(0 downto 0);
	signal		A_ADDR				: std_logic_vector(8 downto 0);
	signal		R_ADDR				: std_logic_vector(8 downto 0);
	signal		RECV_DATA			: std_logic_vector(7 downto 0);
	signal		RECV_DATA_BUF		: std_logic_vector(7 downto 0);
	signal		BUF_NUMBER			: std_logic_vector(7 downto 0);
	constant	count_reset_end		: integer := 40000;
--	constant	count_reset_end		: integer := 40000;
--	constant	count_reset_end		: integer := 8;		-- for debugging
	constant	BufLength			: integer := 512;	-- Size of buffer
	constant	NumOfBuf			: integer := 2;
--	constant	BufLength			: integer := 60;	-- for debugging
--	constant	NumOfBuf			: integer := 4;		-- for debugging
	constant	IntervalLength		: integer := 8; --8
	constant	DataLength				: integer := 1016;
	constant	count_addrx_end		: integer := 1016; -- 512*3+508(NumofBuf)
	constant	count_addry_end		: integer := 1;
--	constant	DataLength			: integer := 508;
--	constant	count_addrx_end		: integer := 508;
--	constant	count_addry_end		: integer := 1;
--	constant	DataLength			: integer := 200;	-- for debugging
--	constant	count_addrx_end		: integer := 20;	-- for debugging
--	constant	count_addry_end		: integer := 10;	-- for debugging
	constant	NumOfData			: integer := 1;
	constant	HeaderLength		: integer := 4;
	constant	Delay				: integer := 2; -- 0 or 1 or 2
begin

---- Initializing --------------------------------------------------------------
	process(CLK, RESET) begin
		if(RESET = '1') then
			RESET_COUNT <= (others => '0');
		elsif(rising_edge(CLK)) then
			if(RESET_COUNT < count_reset_end) then
				RESET_COUNT <= RESET_COUNT + 1;
			end if;
		end if;
	end process;

	USB_nRESET <= '1' when RESET_COUNT = count_reset_end else
				  '0';

	process(CLK, RESET) begin								-- ver.3
		if(RESET = '1') then								-- ver.3
			USB_ACTIVE <= '0';								-- ver.3
		elsif(CLK'event and CLK ='1') then					-- ver.3
			if(RECV_DATA_BUF = 255 and R_ADDR = 0) then		-- ver.3
				USB_ACTIVE <= '1';							-- ver.3
			end if;											-- ver.3
		end if;												-- ver.3
	end process;
--	USB_ACTIVE <= '1';	-- for debugging
--------------------------------------------------------------------------------

---- USB clock -----------------------------------------------------------------
	ODDR2_USBCLK_inst : ODDR2
		generic map(
			DDR_ALIGNMENT	=> "NONE",
			INIT		=> '0',
			SRTYPE	=> "SYNC"
		)
		port map(
			Q	=> USB_CLK,
			C0	=> CLK,
			C1	=> not CLK,
			CE	=> '1',
			D0	=> '1',
			D1	=> '0',
			R	=> '0',
			S	=> '0'
		);
--------------------------------------------------------------------------------

---- Bidirectional port --------------------------------------------------------
	IOBUF_FD_Inst : for i in 0 to 7 generate
		IOBUF_inst : IOBUF
		generic map(
			DRIVE				=> 12,
			IBUF_DELAY_VALUE	=> "0",
			IFD_DELAY_VALUE		=> "AUTO",
			IOSTANDARD			=> "DEFAULT",
			SLEW				=> "SLOW"
		)
		port map(
			O	=> RECV_DATA(i),
			IO	=> USB_FD(i),
			I	=> USB_DOUT(i),
			T	=> not SENDING
		);

		IODELAY2_FD_inst : IODELAY2
			generic map(
				COUNTER_WRAPAROUND	=> "WRAPAROUND",
				DATA_RATE		=> "SDR",
				DELAY_SRC		=> "ODATAIN",
				IDELAY2_VALUE	=> 0,
				IDELAY_MODE		=> "NORMAL",
				IDELAY_TYPE		=> "DEFAULT",
				IDELAY_VALUE	=> 0,
				ODELAY_VALUE	=> 95,
				SERDES_MODE		=> "NONE",
				SIM_TAPDELAY_VALUE	=> 75
			)
			port map(
				BUSY		=> open,
				DATAOUT		=> open,
				DATAOUT2	=> open,
				DOUT		=> USB_DOUT(i),
				TOUT		=> open,
				CAL			=> '0',
				CE			=> '0',
				CLK			=> CLK,
				IDATAIN		=> '0',
				INC			=> '0',
				-- IOCLK0	=> CLK,
				IOCLK0		=> '0',
				IOCLK1		=> '0',
				ODATAIN		=> USB_DOUT_IN(i),
				RST			=> '0',
				T			=> '0'
			);
	end generate;
--------------------------------------------------------------------------------

---- Output port ---------------------------------------------------------------
	IODELAY2_SLRD_inst : IODELAY2
		generic map(
			COUNTER_WRAPAROUND	=> "WRAPAROUND",
			DATA_RATE		=> "SDR",
			DELAY_SRC		=> "ODATAIN",
			IDELAY2_VALUE	=> 0,
			IDELAY_MODE		=> "NORMAL",
			IDELAY_TYPE		=> "DEFAULT",
			IDELAY_VALUE	=> 0,
			ODELAY_VALUE	=> 95,
			SERDES_MODE		=> "NONE",
			SIM_TAPDELAY_VALUE	=> 75
		)
		port map(
			BUSY		=> open,
			DATAOUT		=> open,
			DATAOUT2	=> open,
			DOUT		=> USB_SLRD,
			TOUT		=> open,
			CAL			=> '0',
			CE			=> '0',
			CLK			=> CLK,
			IDATAIN		=> '0',
			INC			=> '0',
			-- IOCLK0	=> CLK,
			IOCLK0		=> '0',
			IOCLK1		=> '0',
			ODATAIN		=> USB_SLRD_IN,
			RST			=> '0',
			T			=> '0'
		);


	IODELAY2_SLWR_inst : IODELAY2
		generic map(
			COUNTER_WRAPAROUND	=> "WRAPAROUND",
			DATA_RATE		=> "SDR",
			DELAY_SRC		=> "ODATAIN",
			IDELAY2_VALUE	=> 0,
			IDELAY_MODE		=> "NORMAL",
			IDELAY_TYPE		=> "DEFAULT",
			IDELAY_VALUE	=> 0,
			ODELAY_VALUE	=> 95,
			SERDES_MODE		=> "NONE",
			SIM_TAPDELAY_VALUE	=> 75
		)
		port map(
			BUSY		=> open,
			DATAOUT		=> open,
			DATAOUT2	=> open,
			DOUT		=> USB_SLWR,
			TOUT		=> open,
			CAL			=> '0',
			CE			=> '0',
			CLK			=> CLK,
			IDATAIN		=> '0',
			INC			=> '0',
			-- IOCLK0	=> CLK,
			IOCLK0		=> '0',
			IOCLK1		=> '0',
			ODATAIN		=> USB_SLWR_IN,
			RST			=> '0',
			T			=> '0'
		);

	--OBUF_SLOE_Inst : OBUF
	--	generic map(
	--	DRIVE => 12,
	--		IOSTANDARD => "DEFAULT",
	--		SLEW => "SLOW"
	--	)
	--	port map(
	--		O => USB_SLOE,
	--		I => SENDING
	--	);
	USB_SLOE <= SENDING;

	IODELAY2_PKTEND_inst : IODELAY2
		generic map(
			COUNTER_WRAPAROUND	=> "WRAPAROUND",
			DATA_RATE		=> "SDR",
			DELAY_SRC		=> "ODATAIN",
			IDELAY2_VALUE	=> 0,
			IDELAY_MODE		=> "NORMAL",
			IDELAY_TYPE		=> "DEFAULT",
			IDELAY_VALUE	=> 0,
			ODELAY_VALUE	=> 95,
			SERDES_MODE		=> "NONE",
			SIM_TAPDELAY_VALUE	=> 75
		)
		port map(
			BUSY		=> open,
			DATAOUT		=> open,
			DATAOUT2	=> open,
			DOUT		=> USB_PKTEND,
			TOUT		=> open,
			CAL			=> '0',
			CE			=> '0',
			CLK			=> CLK,
			IDATAIN		=> '0',
			INC			=> '0',
			-- IOCLK0	=> CLK,
			IOCLK0		=> '0',
			IOCLK1		=> '0',
			ODATAIN		=> USB_PKTEND_IN,
			RST			=> '0',
			T			=> '0'
		);
--------------------------------------------------------------------------------

---- Timing Controller for TX --------------------------------------------------
	process(CLK) begin
		if(rising_edge(CLK)) then
			START_DLY <= SEND_START;
			START_DLY2 <= START_DLY;
		end if;
	end process;
	START_UP <= START_DLY and not START_DLY2;
--	START_UP <= SEND_START;

	process(CLK, RESET) begin
		if(RESET = '1') then
			SENDING <= '0';
		elsif(rising_edge(CLK)) then
			if(START_UP = '1') then
				if(USB_ACTIVE = '1') then							-- ver.3
					SENDING <= '1';									-- ver.3
				end if;												-- ver.3
			elsif(UNIT_COUNT_END = '1' and BUF_NUMBER = NumOfBuf - 1
				and IMG_NUMBER = NumOfData - 1) then
				SENDING <= '0';
			end if;
		end if;
	end process;
	TX_ACTIVE <= SENDING;

	process(CLK) begin
		if(rising_edge(CLK)) then
			if(UNIT_COUNT_EN = '0' or (UNIT_COUNT = BufLength)) then
				USB_SLWR_IN <= '1';
			elsif(UNIT_COUNT = 0) then
				USB_SLWR_IN <= '0';
			end if;
		end if;
	end process;

	process(CLK) begin
		if(rising_edge(CLK)) then
			if(UNIT_COUNT = BufLength + IntervalLength - 5) then
				USB_PKTEND_IN <= '0';
			else
				USB_PKTEND_IN <= '1';
			end if;
		end if;
	end process;

	USB_FIFOADDR <= "10" when SENDING = '1' else 	-- EP6
					"00"; 							-- EP2
--------------------------------------------------------------------------------

---- Counters for TX -----------------------------------------------------------
	process(CLK) begin
		if(rising_edge(CLK)) then
			if(SENDING = '0' or (UNIT_COUNT = BufLength + IntervalLength - 1)) then
				UNIT_COUNT_EN <= '0';
			elsif(USB_FLAGB = '1') then
				UNIT_COUNT_EN <= '1';
			end if;
		end if;
	end process;

	process(CLK) begin
		if(rising_edge(CLK)) then
			if(UNIT_COUNT = BufLength + IntervalLength - 2) then
				UNIT_COUNT_END <= '1';
			else
				UNIT_COUNT_END <= '0';
			end if;
		end if;
	end process;

	process(CLK, RESET) begin
		if(RESET = '1') then
			UNIT_COUNT <= (others => '0');
		elsif(rising_edge(CLK)) then
			if(UNIT_COUNT_EN = '0') then
				UNIT_COUNT <= (others => '0');
			else
				UNIT_COUNT <= UNIT_COUNT + 1;
			end if;
		end if;
	end process;

	process(CLK) begin
		if(rising_edge(CLK)) then
			if(SENDING = '0') then
				BUF_NUMBER <= (others => '0');
			elsif(UNIT_COUNT_END = '1') then
				if(BUF_NUMBER = NumOfBuf - 1) then
					BUF_NUMBER <= (others => '0');
				else
					BUF_NUMBER <= BUF_NUMBER + 1;
				end if;
			end if;
		end if;
	end process;

	process(CLK) begin
		if(rising_edge(CLK)) then
			if(SENDING = '0' or (UNIT_COUNT_END = '1' and BUF_NUMBER = NumOfBuf - 1)) then
				APPEND_DATA_EN_PRE(0) <= '0';
			elsif(IMG_ADDR = DataLength - 3 + Delay) then
				APPEND_DATA_EN_PRE(0) <= '1';
			end if;
		end if;
	end process;

	process(CLK) begin
		if(rising_edge(CLK)) then
			APPEND_DATA_EN_PRE(1) <= APPEND_DATA_EN_PRE(0);
			APPEND_DATA_EN <= APPEND_DATA_EN_PRE(1);
		end if;
	end process;
--------------------------------------------------------------------------------

---- Image Data Counter --------------------------------------------------------
	process(CLK) begin
		if(rising_edge(CLK)) then
			if(SENDING = '0' or APPEND_DATA_EN = '1') then
				IMG_ADDR <= (others => '0');
			elsif((UNIT_COUNT > HeaderLength - Delay - 1) and
					(UNIT_COUNT < BufLength - Delay)) then
				if(IMG_ADDR = DataLength - 1) then
					IMG_ADDR <= (others => '0');
				else
					IMG_ADDR <= IMG_ADDR + 1;
				end if;
			end if;
		end if;
	end process;

	process(CLK) begin
		if(rising_edge(CLK)) then
			if(SENDING = '0' or APPEND_DATA_EN = '1') then
				count_addrx <= (others => '0');
			elsif((UNIT_COUNT > HeaderLength - Delay - 1) and
					(UNIT_COUNT < BufLength - Delay)) then
				if(IMG_ADDR = DataLength - 1 or count_addrx = count_addrx_end - 1) then
					count_addrx <= (others => '0');
				else
					count_addrx <= count_addrx + 1;
				end if;
			end if;
		end if;
	end process;

--	process(CLK) begin
--		if(rising_edge(CLK)) then
--			if(SENDING = '0' or APPEND_DATA_EN = '1') then
--				count_addry <= (others => '0');
--			elsif((UNIT_COUNT > HeaderLength - Delay - 1)
--			and	(UNIT_COUNT < BufLength - Delay)
--			and (count_addrx = count_addrx_end - 1)) then
--				if(IMG_ADDR = DataLength - 1) then
--					count_addry <= (others => '0');
--				else
--					count_addry <= count_addry + 1;
--				end if;
--			end if;
--		end if;
--	end process;
--	TX_ROUT <= "0000" & count_addry & count_addrx & SENDING & "000";
	TX_ROUT <= count_addrx & SENDING & "000";

	process(CLK) begin
		if(rising_edge(CLK)) then
			if(SENDING = '0') then
				IMG_NUMBER <= (others => '0');
			elsif(UNIT_COUNT_END = '1' and BUF_NUMBER = NumOfBuf - 1) then
				IMG_NUMBER <= IMG_NUMBER + 1;
			end if;
		end if;
	end process;
	IMAGE_NUMBER <= IMG_NUMBER;

	process(CLK) begin
		if(rising_edge(CLK)) then
			if(APPEND_DATA_EN_PRE(1) = '0') then
				A_ADDR <= (others => '0');
			else
				A_ADDR <= A_ADDR + 1;
			end if;
		end if;
	end process;
	APPEND_ADDR <= A_ADDR;
--------------------------------------------------------------------------------

---- TX data -------------------------------------------------------------------
	process(CLK) begin
		if(rising_edge(CLK)) then
			case UNIT_COUNT is
				when "000000000000"	=> USB_DOUT_IN <= BUF_NUMBER; -- NumOfBuf == packet
				when "000000000001"	=> USB_DOUT_IN <= "0000" & IMG_NUMBER;
				when "000000000010"	=> USB_DOUT_IN <= FRAME_NUMBER;
				when "000000000011"	=> USB_DOUT_IN <= CONV_STD_LOGIC_VECTOR(NumOfData, 8);
				when others			=> USB_DOUT_IN <= SEND_DATA;
			end case;
		end if;
	end process;

	SEND_DATA <= IMAGE_DATA when APPEND_DATA_EN = '0' else
				 APPEND_DATA;
--------------------------------------------------------------------------------

---- Signals for RX ------------------------------------------------------------
	process(CLK) begin
		if(rising_edge(CLK)) then
			SENDING_DLY <= SENDING;
		end if;
	end process;

	process(CLK) begin
		if(rising_edge(CLK)) then
			if(SENDING = '1' or SENDING_DLY = '1' or IMG_ADDR = BufLength - 1) then
				USB_SLRD_IN <= '1';
			elsif(USB_FLAGC = '1') then
				USB_SLRD_IN <= '0';
			else
				USB_SLRD_IN <= '1';
			end if;
		end if;
	end process;
	USB_SLRD_INTNL <= USB_SLRD_IN ;

	process(CLK) begin
		if(rising_edge(CLK)) then
			USB_SLRD_DLY <= USB_SLRD_IN;
		end if;
	end process;

	process(CLK) begin
		if(rising_edge(CLK)) then
			if(SENDING = '1' or USB_ACTIVE = '0') then		-- ver.3
				R_ADDR <= (others => '0');
			elsif(USB_SLRD_DLY = '0') then
				R_ADDR <= R_ADDR + 1;
			end if;
		end if;
	end process;

	process(CLK) begin
		if(rising_edge(CLK)) then
			if(SENDING = '0') then
				RECV_DATA_BUF <= RECV_DATA;
			else
				RECV_DATA_BUF <= (others => '0');
			end if;
		end if;
	end process;

	RX_ACTIVE <= not USB_SLRD_IN;
	RX_WOUT <= RECV_DATA_BUF & "00000000" & R_ADDR & not USB_SLRD_IN & "000";
--------------------------------------------------------------------------------

end Behavioral;
