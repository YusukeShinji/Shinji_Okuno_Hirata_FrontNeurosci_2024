--------------------------------------------------------------------------------
-- BSD 3-Clause License
-- Copyright (c) 2024, Hirotsugu Okuno
-- Copyright (c) 2024, Yusuke Shinji
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity BRAM_1P_QQVGA_Async1 is
	Port(
		CLK_W		: in	std_logic;
		CLK_R		: in	std_logic;
		WRITE1		: in	std_logic_vector(28 downto 0);
		READ1		: in	std_logic_vector(20 downto 0);
		DOUT1		: out	std_logic_vector(7 downto 0)
	);
end BRAM_1P_QQVGA_Async1;

architecture Behavioral of BRAM_1P_QQVGA_Async1 is
	signal READ1_CTRL_REG	:std_logic_vector(3 downto 0);
	signal BRAM1_EN_W		:std_logic;
	signal BRAM1_EN_R		:std_logic;
	signal BRAM1_WE			:std_logic_vector(0 downto 0);
	signal BRAM1_ADDR_W		:std_logic_vector(14 downto 0);
	signal BRAM1_ADDR_R		:std_logic_vector(14 downto 0);
	signal BRAM1_DIN		:std_logic_vector(7 downto 0);
	signal BRAM1_DOUT		:std_logic_vector(7 downto 0);

	signal addr_conv_w1		:std_logic_vector(14 downto 0);
	signal addr_temp_w1		:std_logic_vector(7 downto 0);
	signal addr_conv_r1		:std_logic_vector(14 downto 0);
	signal addr_temp_r1		:std_logic_vector(7 downto 0);

	component ramb_qqvga_dual2
		port (
			clka: IN std_logic;
			ena: IN std_logic;
			wea: IN std_logic_VECTOR(0 downto 0);
			addra: IN std_logic_VECTOR(14 downto 0);
			dina: IN std_logic_VECTOR(7 downto 0);
			clkb: IN std_logic;
			enb: IN std_logic;
			addrb: IN std_logic_VECTOR(14 downto 0);
			doutb: OUT std_logic_VECTOR(7 downto 0)
		);
	end component;

begin

---- Read-out control ---------------------------------------------------------
	process(CLK_R) begin
		if(CLK_R'event and CLK_R = '1') then
			READ1_CTRL_REG <= READ1(3 downto 0);
		end if;
	end process;

	process(CLK_R) begin
		if(CLK_R'event and CLK_R = '1') then
			if(READ1_CTRL_REG(3) = '1') then
				case READ1_CTRL_REG(2) is
					when '0' => DOUT1 <= BRAM1_DOUT;
					when others => DOUT1 <= (others => '0');
				end case;
			end if;
		end if;
	end process;
-------------------------------------------------------------------------------

---- Address conversion -------------------------------------------------------
--	addr_temp_w1 <= WRITE1(11 downto 4) - "00100000";
--	addr_conv_w1 <= WRITE1(19 downto 13) & WRITE1(11 downto 4);
	addr_conv_w1 <= WRITE1(18 downto 4);
--	addr_conv_w1 <= WRITE1(11 downto 4) & WRITE1(19 downto 13)
--					when(WRITE1(11 downto 4) < 152) else
--					'0' & WRITE1(19 downto 13) & addr_temp_w1(6 downto 0);
--	addr_temp_r1 <= READ1(11 downto 4) - "00100000";
--	addr_conv_r1 <= READ1(19 downto 13) & READ1(11 downto 4);
	addr_conv_r1 <= READ1(18 downto 4);
--	addr_conv_r1 <= READ1(11 downto 4) & READ1(19 downto 13)
--					when(READ1(11 downto 4) < 152) else
--					'0' & READ1(19 downto 13) & addr_temp_r1(6 downto 0);
-------------------------------------------------------------------------------

---- BRAM1 control ------------------------------------------------------------
	process(CLK_W) begin
		if(CLK_W'event and CLK_W = '1') then
			if(	(WRITE1(3 downto 2) = "10")) then
				BRAM1_EN_W <= '1';
				BRAM1_WE(0) <= '1';
			else
				BRAM1_EN_W <= '0';
				BRAM1_WE(0) <= '0';
			end if;
		end if;
	end process;

	process(CLK_W) begin
		if(CLK_W'event and CLK_W = '1') then
			if(WRITE1(3 downto 2) = "10") then
				BRAM1_ADDR_W <= addr_conv_w1;
			else
				BRAM1_ADDR_W <= (others => '0');
			end if;
		end if;
	end process;

	process(CLK_W) begin
		if(CLK_W'event and CLK_W = '1') then
			if(WRITE1(3 downto 2) = "10") then
				BRAM1_DIN <= WRITE1(28 downto 21);
			else
				BRAM1_DIN <= (others => '0');
			end if;
		end if;
	end process;

	BRAM1_EN_R <= '1' when(READ1(3 downto 2) = "10") else
				  '0';

	BRAM1_ADDR_R <= addr_conv_r1 when (READ1(3 downto 2) = "10") else
					(others => '0');

	U0 : ramb_qqvga_dual2
		port map (
			clka => CLK_W,
			ena => BRAM1_EN_W,
			wea => BRAM1_WE,
			addra => BRAM1_ADDR_W,
			dina => BRAM1_DIN,
			clkb => CLK_R,
			enb => BRAM1_EN_R,
			addrb => BRAM1_ADDR_R,
			doutb => BRAM1_DOUT
		);
-------------------------------------------------------------------------------

end Behavioral;
