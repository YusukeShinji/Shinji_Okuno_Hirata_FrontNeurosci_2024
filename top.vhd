--------------------------------------------------------------------------------
-- BSD 3-Clause License
-- Copyright (c) 2024, Hirotsugu Okuno
-- Copyright (c) 2024, Yusuke Shinji
-- Copyright (c) 1995-2013 Xilinx, Inc.  All rights reserved.
--------------------------------------------------------------------------------
--   ____  ____
--  /   /\/   /
-- /___/  \  /    Vendor: Xilinx
-- \   \   \/     Version : 14.7
--  \   \         Application : sch2hdl
--  /   /         Filename : top.vhf
-- /___/   /\     Timestamp : 04/16/2024 16:39:20
-- \   \  /  \
--  \___\/\___\
--
--Command: C:\Xilinx\14.7\ISE_DS\ISE\bin\nt64\unwrapped\sch2hdl.exe -sympath F:/FPGAprojects/CRBNET_SPARTAN6/publish/ACNN_ForDCM_main/Shinji_Okuno_Hirata_FrontNeurosci_2024/ipcore_dir -intstyle ise -family spartan6 -flat -suppress -vhdl top.vhf -w F:/FPGAprojects/CRBNET_SPARTAN6/publish/ACNN_ForDCM_main/Shinji_Okuno_Hirata_FrontNeurosci_2024/top.sch
--Design Name: top
--Device: spartan6
--Purpose:
--    This vhdl netlist is translated from an ECS schematic. It can be
--    synthesized and simulated, but it should not be modified.
--
----- CELL INV8_HXILINX_top -----

library IEEE;
use IEEE.STD_LOGIC_1164.all;

entity INV8_HXILINX_top is
port(
    O  : out std_logic_vector(7 downto 0);

    I  : in std_logic_vector(7 downto 0)
  );
end INV8_HXILINX_top;

architecture INV8_HXILINX_top_V of INV8_HXILINX_top is
begin
  O <= not I ;
end INV8_HXILINX_top_V;

library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;
library UNISIM;
use UNISIM.Vcomponents.ALL;

entity top is
   port ( CLK50M_A    : in    std_logic;
          DIP_E       : in    std_logic_vector (7 downto 0);
          DIP_H_4     : in    std_logic;
          HALL0       : in    std_logic;
          HALL1       : in    std_logic;
          HALL2       : in    std_logic;
          PUSH_SW1    : in    std_logic;
          PUSH_SW2    : in    std_logic;
          USB_FLAGB   : in    std_logic;
          USB_FLAGC   : in    std_logic;
          GPIO1       : out   std_logic;
          GPIO2       : out   std_logic;
          GPIO3       : out   std_logic;
          GPIO4       : out   std_logic;
          LED_E       : out   std_logic_vector (3 downto 0);
          LED_H       : out   std_logic_vector (7 downto 0);
          LOAD        : out   std_logic;
          MOTCON0     : out   std_logic;
          MOTCON1     : out   std_logic;
          USB_FIFOADR : out   std_logic_vector (1 downto 0);
          USB_IFCLK   : out   std_logic;
          USB_nRESET  : out   std_logic;
          USB_PKTEND  : out   std_logic;
          USB_SLOE    : out   std_logic;
          USB_SLRD    : out   std_logic;
          USB_SLWR    : out   std_logic;
          USB_FD      : inout std_logic_vector (7 downto 0));
end top;

architecture BEHAVIORAL of top is
   attribute BOX_TYPE   : string ;
   attribute HU_SET     : string ;
   attribute IOSTANDARD : string ;
   attribute SLEW       : string ;
   attribute DRIVE      : string ;
   signal amp               : std_logic_vector (31 downto 0);
   signal APPEND_ADDR       : std_logic_vector (8 downto 0);
   signal CLK_LVDS          : std_logic;
   signal CLK40M            : std_logic;
   signal COM               : std_logic_vector (31 downto 0);
   signal CONMSR            : std_logic_vector (31 downto 0);
   signal DC_cf             : std_logic_vector (31 downto 0);
   signal DSR               : std_logic_vector (31 downto 0);
   signal ENA_SIM           : std_logic;
   signal ERR               : std_logic_vector (31 downto 0);
   signal FRAME             : std_logic_vector (7 downto 0);
   signal freq              : std_logic_vector (31 downto 0);
   signal gain_COM          : std_logic_vector (31 downto 0);
   signal gain_MSR          : std_logic_vector (31 downto 0);
   signal gain_PkC_LPF      : std_logic_vector (31 downto 0);
   signal g_cf              : std_logic_vector (31 downto 0);
   signal g_D               : std_logic_vector (31 downto 0);
   signal g_LTD             : std_logic_vector (31 downto 0);
   signal g_LTP             : std_logic_vector (31 downto 0);
   signal g_P               : std_logic_vector (31 downto 0);
   signal hem               : std_logic;
   signal LEARN             : std_logic;
   signal LVDS2_RX_ACTIVE   : std_logic;
   signal PID               : std_logic_vector (31 downto 0);
   signal RST_NET           : std_logic;
   signal spkmean_L         : std_logic_vector (31 downto 0);
   signal spkmean_R         : std_logic_vector (31 downto 0);
   signal spk_BkC           : std_logic_vector (24 downto 0);
   signal spk_CF            : std_logic_vector (7 downto 0);
   signal spk_GoC           : std_logic_vector (368 downto 0);
   signal spk_GrC           : std_logic_vector (4095 downto 0);
   signal spk_MF            : std_logic_vector (245 downto 0);
   signal spk_PkC           : std_logic_vector (7 downto 0);
   signal START_SIM         : std_logic;
   signal SYS_RST           : std_logic;
   signal tau_MSR           : std_logic_vector (31 downto 0);
   signal tau_PkC_LPF       : std_logic_vector (31 downto 0);
   signal time_sim          : std_logic_vector (31 downto 0);
   signal t_win             : std_logic_vector (31 downto 0);
   signal USB_DATA          : std_logic_vector (7 downto 0);
   signal USB_IMG_NUM       : std_logic_vector (3 downto 0);
   signal USB_REG_13        : std_logic_vector (7 downto 0);
   signal USB_ROUT          : std_logic_vector (20 downto 0);
   signal USB_RX_ACTIVE     : std_logic;
   signal USB_SLRD_INTNL    : std_logic;
   signal USB_START         : std_logic;
   signal USB_START_STATE   : std_logic_vector (1 downto 0);
   signal USB_WOUT          : std_logic_vector (28 downto 0);
   signal VALID_O_BkC       : std_logic;
   signal VALID_O_CF        : std_logic;
   signal VALID_O_GoC       : std_logic;
   signal VALID_O_GrC       : std_logic;
   signal VALID_O_MF        : std_logic;
   signal VALID_O_PkC       : std_logic;
   signal wave_CF0          : std_logic_vector (15 downto 0);
   signal wave_MF0          : std_logic_vector (15 downto 0);
   signal wave_MF1          : std_logic_vector (15 downto 0);
   signal wave_MF2          : std_logic_vector (15 downto 0);
   signal write_weight_syns : std_logic_vector (77 downto 0);
   signal XLXN_6788         : std_logic;
   signal XLXN_6789         : std_logic;
   signal XLXN_6803         : std_logic;
   signal XLXN_6804         : std_logic;
   signal XLXN_8268         : std_logic_vector (28 downto 0);
   signal XLXN_8582         : std_logic_vector (15 downto 0);
   signal XLXN_8583         : std_logic_vector (15 downto 0);
   signal ZEROS             : std_logic_vector (35 downto 0);
   component INV
      port ( I : in    std_logic;
             O : out   std_logic);
   end component;
   attribute BOX_TYPE of INV : component is "BLACK_BOX";

   component INV8_HXILINX_top
      port ( I : in    std_logic_vector (7 downto 0);
             O : out   std_logic_vector (7 downto 0));
   end component;

   component EZUSBctrlv31_QQVGA
      port ( CLK            : in    std_logic;
             RESET          : in    std_logic;
             SEND_START     : in    std_logic;
             USB_FLAGB      : in    std_logic;
             USB_FLAGC      : in    std_logic;
             IMAGE_DATA     : in    std_logic_vector (7 downto 0);
             APPEND_DATA    : in    std_logic_vector (7 downto 0);
             FRAME_NUMBER   : in    std_logic_vector (7 downto 0);
             TX_ACTIVE      : out   std_logic;
             RX_ACTIVE      : out   std_logic;
             USB_CLK        : out   std_logic;
             USB_nRESET     : out   std_logic;
             USB_PKTEND     : out   std_logic;
             USB_SLOE       : out   std_logic;
             USB_SLRD       : out   std_logic;
             USB_SLRD_INTNL : out   std_logic;
             USB_SLWR       : out   std_logic;
             USB_FIFOADDR   : out   std_logic_vector (1 downto 0);
             IMAGE_NUMBER   : out   std_logic_vector (3 downto 0);
             APPEND_ADDR    : out   std_logic_vector (8 downto 0);
             TX_ROUT        : out   std_logic_vector (20 downto 0);
             RX_WOUT        : out   std_logic_vector (28 downto 0);
             USB_FD         : inout std_logic_vector (7 downto 0));
   end component;

   component OBUF
      port ( I : in    std_logic;
             O : out   std_logic);
   end component;
   attribute IOSTANDARD of OBUF : component is "DEFAULT";
   attribute SLEW of OBUF : component is "SLOW";
   attribute DRIVE of OBUF : component is "12";
   attribute BOX_TYPE of OBUF : component is "BLACK_BOX";

   component BRAM_1P_QQVGA_Async1
      port ( CLK_W  : in    std_logic;
             CLK_R  : in    std_logic;
             WRITE1 : in    std_logic_vector (28 downto 0);
             READ1  : in    std_logic_vector (20 downto 0);
             DOUT1  : out   std_logic_vector (7 downto 0));
   end component;

   component DCM40M80M
      port ( CLK_IN : in    std_logic;
             RST    : in    std_logic;
             CLK40M : out   std_logic;
             CLK80M : out   std_logic);
   end component;

   component Timing_Generator_LVDS
      port ( CLK40M      : in    std_logic;
             RESET       : in    std_logic;
             LVDS_RX_ACT : in    std_logic;
             USB_START   : out   std_logic;
             STATE       : out   std_logic_vector (1 downto 0);
             TIME_COUNT  : out   std_logic_vector (15 downto 0);
             FRAME_COUNT : out   std_logic_vector (7 downto 0));
   end component;

   component CELLGROUP_GrC
      port ( CLK       : in    std_logic;
             RST       : in    std_logic;
             hem       : in    std_logic;
             VALID_I   : in    std_logic;
             t_spk_mf  : in    std_logic_vector (245 downto 0);
             t_spk_goc : in    std_logic_vector (368 downto 0);
             VALID_O   : out   std_logic;
             t_spk     : out   std_logic_vector (4095 downto 0));
   end component;

   component FIBERGROUP_MF
      port ( CLK      : in    std_logic;
             RST      : in    std_logic;
             hem      : in    std_logic;
             VALID_I  : in    std_logic;
             i_stim_0 : in    std_logic_vector (15 downto 0);
             i_stim_1 : in    std_logic_vector (15 downto 0);
             i_stim_2 : in    std_logic_vector (15 downto 0);
             i_stim_3 : in    std_logic_vector (15 downto 0);
             i_stim_4 : in    std_logic_vector (15 downto 0);
             VALID_O  : out   std_logic;
             t_spk    : out   std_logic_vector (245 downto 0));
   end component;

   component CELLGROUP_GoC
      port ( CLK       : in    std_logic;
             RST       : in    std_logic;
             hem       : in    std_logic;
             VALID_I   : in    std_logic;
             t_spk_grc : in    std_logic_vector (4095 downto 0);
             t_spk_mf  : in    std_logic_vector (245 downto 0);
             VALID_O   : out   std_logic;
             t_spk     : out   std_logic_vector (368 downto 0));
   end component;

   component FIBERGROUP_CF
      port ( CLK      : in    std_logic;
             RST      : in    std_logic;
             hem      : in    std_logic;
             VALID_I  : in    std_logic;
             g_cf     : in    std_logic_vector (15 downto 0);
             dc_cf    : in    std_logic_vector (15 downto 0);
             i_stim_1 : in    std_logic_vector (15 downto 0);
             i_stim_2 : in    std_logic_vector (15 downto 0);
             i_stim_3 : in    std_logic_vector (15 downto 0);
             VALID_O  : out   std_logic;
             t_spk    : out   std_logic_vector (7 downto 0));
   end component;

   component CELLGROUP_PkC
      port ( CLK               : in    std_logic;
             RST               : in    std_logic;
             hem               : in    std_logic;
             LEARN             : in    std_logic;
             VALID_I           : in    std_logic;
             t_win             : in    std_logic_vector (31 downto 0);
             g_LTD             : in    std_logic_vector (31 downto 0);
             g_LTP             : in    std_logic_vector (31 downto 0);
             t_spk_grc         : in    std_logic_vector (4095 downto 0);
             t_spk_bkc         : in    std_logic_vector (24 downto 0);
             t_spk_cf          : in    std_logic_vector (7 downto 0);
             VALID_O           : out   std_logic;
             t_spk             : out   std_logic_vector (7 downto 0);
             write_weight_syns : out   std_logic_vector (77 downto 0));
   end component;

   component CELLGROUP_BkC
      port ( CLK       : in    std_logic;
             RST       : in    std_logic;
             hem       : in    std_logic;
             VALID_I   : in    std_logic;
             t_spk_grc : in    std_logic_vector (4095 downto 0);
             VALID_O   : out   std_logic;
             t_spk     : out   std_logic_vector (24 downto 0));
   end component;

   component DataRegister8bit_32reg
      port ( CLK   : in    std_logic;
             RST   : in    std_logic;
             WRITE : in    std_logic_vector (28 downto 0);
             RO_00 : out   std_logic_vector (31 downto 0);
             RO_01 : out   std_logic_vector (31 downto 0);
             RO_02 : out   std_logic_vector (31 downto 0);
             RO_03 : out   std_logic_vector (31 downto 0);
             RO_04 : out   std_logic_vector (31 downto 0);
             RO_05 : out   std_logic_vector (31 downto 0);
             RO_06 : out   std_logic_vector (31 downto 0);
             RO_07 : out   std_logic_vector (31 downto 0);
             RO_08 : out   std_logic_vector (31 downto 0);
             RO_09 : out   std_logic_vector (31 downto 0);
             RO_10 : out   std_logic_vector (31 downto 0);
             RO_11 : out   std_logic_vector (31 downto 0);
             RO_12 : out   std_logic_vector (31 downto 0);
             RO_13 : out   std_logic_vector (31 downto 0));
   end component;

   component PWMGenerator
      port ( CLK      : in    std_logic;
             RST      : in    std_logic;
             STR      : in    std_logic;
             ENA_SIM  : in    std_logic;
             gain_COM : in    std_logic_vector (31 downto 0);
             MANSIG   : in    std_logic_vector (31 downto 0);
             CONSIG0  : out   std_logic;
             CONSIG1  : out   std_logic);
   end component;

   component Selector_to_usb
      port ( CLK               : in    std_logic;
             RST               : in    std_logic;
             hem               : in    std_logic;
             START_SIM         : in    std_logic;
             VALID_O_MF        : in    std_logic;
             time_sim          : in    std_logic_vector (31 downto 0);
             CONMSR            : in    std_logic_vector (31 downto 0);
             COM               : in    std_logic_vector (31 downto 0);
             ERR               : in    std_logic_vector (31 downto 0);
             DSR               : in    std_logic_vector (31 downto 0);
             PID               : in    std_logic_vector (31 downto 0);
             spkmean_L         : in    std_logic_vector (31 downto 0);
             spkmean_R         : in    std_logic_vector (31 downto 0);
             spk_MF            : in    std_logic_vector (245 downto 0);
             spk_CF            : in    std_logic_vector (7 downto 0);
             spk_GrC           : in    std_logic_vector (4095 downto 0);
             spk_GoC           : in    std_logic_vector (368 downto 0);
             spk_PkC           : in    std_logic_vector (7 downto 0);
             spk_BkC           : in    std_logic_vector (24 downto 0);
             write_weight_syns : in    std_logic_vector (77 downto 0);
             WOUT1             : out   std_logic_vector (28 downto 0));
   end component;

   component ACNNcontroller
      port ( CLK            : in    std_logic;
             START          : in    std_logic;
             RST            : in    std_logic;
             ENA_LEARN      : in    std_logic;
             ENA_cerebellum : in    std_logic;
             ENA_PID        : in    std_logic;
             ENA_LOAD       : in    std_logic;
             VALID_O_PkC    : in    std_logic;
             ENA_DSR        : in    std_logic_vector (3 downto 0);
             spk_pkc        : in    std_logic_vector (7 downto 0);
             CONMSR         : in    std_logic_vector (31 downto 0);
             freq           : in    std_logic_vector (15 downto 0);
             amp            : in    std_logic_vector (15 downto 0);
             g_P            : in    std_logic_vector (15 downto 0);
             g_D            : in    std_logic_vector (15 downto 0);
             LEARN          : out   std_logic;
             START_SIM      : out   std_logic;
             RST_NET        : out   std_logic;
             hem_out        : out   std_logic;
             LOAD           : out   std_logic;
             ENA_SIM_ALL    : out   std_logic;
             wave_MF0       : out   std_logic_vector (15 downto 0);
             wave_MF1       : out   std_logic_vector (15 downto 0);
             wave_MF2       : out   std_logic_vector (15 downto 0);
             wave_MF3       : out   std_logic_vector (15 downto 0);
             wave_MF4       : out   std_logic_vector (15 downto 0);
             wave_CF0       : out   std_logic_vector (15 downto 0);
             time_sim_out   : out   std_logic_vector (31 downto 0);
             wave_DSR       : out   std_logic_vector (31 downto 0);
             wave_PID       : out   std_logic_vector (31 downto 0);
             wave_ERR       : out   std_logic_vector (31 downto 0);
             wave_spkmean_L : out   std_logic_vector (31 downto 0);
             wave_spkmean_R : out   std_logic_vector (31 downto 0);
             wave_COM       : out   std_logic_vector (31 downto 0);
             tau_PkC_LPF    : in    std_logic_vector (15 downto 0);
             gain_PkC_LPF   : in    std_logic_vector (15 downto 0));
   end component;

   component RotaryEncoder5a2
      port ( CLK      : in    std_logic;
             RST      : in    std_logic;
             STR      : in    std_logic;
             hem      : in    std_logic;
             ENA_SIM  : in    std_logic;
             HALL0    : in    std_logic;
             HALL1    : in    std_logic;
             HALL2    : in    std_logic;
             tau_MSR  : in    std_logic_vector (31 downto 0);
             gain_MSR : in    std_logic_vector (31 downto 0);
             CONMSR   : out   std_logic_vector (31 downto 0));
   end component;

   component Zeros36Bit
      port ( VALUE : out   std_logic_vector (35 downto 0));
   end component;

   attribute HU_SET of XLXI_1043 : label is "XLXI_1043_0";
begin
   XLXI_93 : INV
      port map (I=>PUSH_SW1,
                O=>SYS_RST);

   XLXI_1043 : INV8_HXILINX_top
      port map (I(7 downto 0)=>USB_REG_13(7 downto 0),
                O(7 downto 0)=>LED_H(7 downto 0));

   XLXI_1156 : INV
      port map (I=>DIP_H_4,
                O=>XLXN_6788);

   XLXI_1157 : INV
      port map (I=>XLXN_6788,
                O=>LED_E(3));

   XLXI_1159 : INV
      port map (I=>DIP_E(1),
                O=>XLXN_6789);

   XLXI_1160 : INV
      port map (I=>XLXN_6789,
                O=>LED_E(1));

   XLXI_1165 : INV
      port map (I=>USB_START_STATE(0),
                O=>XLXN_6804);

   XLXI_1166 : INV
      port map (I=>PUSH_SW2,
                O=>XLXN_6803);

   XLXI_1167 : INV
      port map (I=>XLXN_6803,
                O=>LED_E(2));

   XLXI_1168 : INV
      port map (I=>XLXN_6804,
                O=>LED_E(0));

   XLXI_1191 : EZUSBctrlv31_QQVGA
      port map (APPEND_DATA(7 downto 0)=>ZEROS(7 downto 0),
                CLK=>CLK40M,
                FRAME_NUMBER(7 downto 0)=>FRAME(7 downto 0),
                IMAGE_DATA(7 downto 0)=>USB_DATA(7 downto 0),
                RESET=>SYS_RST,
                SEND_START=>USB_START,
                USB_FLAGB=>USB_FLAGB,
                USB_FLAGC=>USB_FLAGC,
                APPEND_ADDR(8 downto 0)=>APPEND_ADDR(8 downto 0),
                IMAGE_NUMBER(3 downto 0)=>USB_IMG_NUM(3 downto 0),
                RX_ACTIVE=>USB_RX_ACTIVE,
                RX_WOUT(28 downto 0)=>USB_WOUT(28 downto 0),
                TX_ACTIVE=>open,
                TX_ROUT(20 downto 0)=>USB_ROUT(20 downto 0),
                USB_CLK=>USB_IFCLK,
                USB_FIFOADDR(1 downto 0)=>USB_FIFOADR(1 downto 0),
                USB_nRESET=>USB_nRESET,
                USB_PKTEND=>USB_PKTEND,
                USB_SLOE=>USB_SLOE,
                USB_SLRD=>USB_SLRD,
                USB_SLRD_INTNL=>USB_SLRD_INTNL,
                USB_SLWR=>USB_SLWR,
                USB_FD(7 downto 0)=>USB_FD(7 downto 0));

   XLXI_1285 : OBUF
      port map (I=>ZEROS(0),
                O=>GPIO1);

   XLXI_1288 : OBUF
      port map (I=>USB_START,
                O=>GPIO2);

   XLXI_1289 : OBUF
      port map (I=>ZEROS(1),
                O=>GPIO3);

   XLXI_1290 : OBUF
      port map (I=>ZEROS(2),
                O=>GPIO4);

   XLXI_1389 : BRAM_1P_QQVGA_Async1
      port map (CLK_R=>CLK40M,
                CLK_W=>CLK40M,
                READ1(20 downto 0)=>USB_ROUT(20 downto 0),
                WRITE1(28 downto 0)=>XLXN_8268(28 downto 0),
                DOUT1(7 downto 0)=>USB_DATA(7 downto 0));

   XLXI_1508 : DCM40M80M
      port map (CLK_IN=>CLK50M_A,
                RST=>SYS_RST,
                CLK40M=>CLK40M,
                CLK80M=>CLK_LVDS);

   XLXI_1510 : Timing_Generator_LVDS
      port map (CLK40M=>CLK40M,
                LVDS_RX_ACT=>LVDS2_RX_ACTIVE,
                RESET=>SYS_RST,
                FRAME_COUNT(7 downto 0)=>FRAME(7 downto 0),
                STATE(1 downto 0)=>USB_START_STATE(1 downto 0),
                TIME_COUNT=>open,
                USB_START=>USB_START);

   XLXI_1592 : CELLGROUP_GrC
      port map (CLK=>CLK40M,
                hem=>hem,
                RST=>RST_NET,
                t_spk_goc(368 downto 0)=>spk_GoC(368 downto 0),
                t_spk_mf(245 downto 0)=>spk_MF(245 downto 0),
                VALID_I=>VALID_O_MF,
                t_spk(4095 downto 0)=>spk_GrC(4095 downto 0),
                VALID_O=>VALID_O_GrC);

   XLXI_1594 : FIBERGROUP_MF
      port map (CLK=>CLK40M,
                hem=>hem,
                i_stim_0(15 downto 0)=>wave_MF0(15 downto 0),
                i_stim_1(15 downto 0)=>wave_MF1(15 downto 0),
                i_stim_2(15 downto 0)=>wave_MF2(15 downto 0),
                i_stim_3(15 downto 0)=>XLXN_8582(15 downto 0),
                i_stim_4(15 downto 0)=>XLXN_8583(15 downto 0),
                RST=>RST_NET,
                VALID_I=>START_SIM,
                t_spk(245 downto 0)=>spk_MF(245 downto 0),
                VALID_O=>VALID_O_MF);

   XLXI_1595 : CELLGROUP_GoC
      port map (CLK=>CLK40M,
                hem=>hem,
                RST=>RST_NET,
                t_spk_grc(4095 downto 0)=>spk_GrC(4095 downto 0),
                t_spk_mf(245 downto 0)=>spk_MF(245 downto 0),
                VALID_I=>VALID_O_GrC,
                t_spk(368 downto 0)=>spk_GoC(368 downto 0),
                VALID_O=>VALID_O_GoC);

   XLXI_1596 : FIBERGROUP_CF
      port map (CLK=>CLK40M,
                dc_cf(15 downto 0)=>DC_cf(15 downto 0),
                g_cf(15 downto 0)=>g_cf(15 downto 0),
                hem=>hem,
                i_stim_1(15 downto 0)=>wave_CF0(15 downto 0),
                i_stim_2(15 downto 0)=>wave_CF0(15 downto 0),
                i_stim_3(15 downto 0)=>wave_CF0(15 downto 0),
                RST=>RST_NET,
                VALID_I=>START_SIM,
                t_spk(7 downto 0)=>spk_CF(7 downto 0),
                VALID_O=>VALID_O_CF);

   XLXI_1599 : CELLGROUP_PkC
      port map (CLK=>CLK40M,
                g_LTD(31 downto 0)=>g_LTD(31 downto 0),
                g_LTP(31 downto 0)=>g_LTP(31 downto 0),
                hem=>hem,
                LEARN=>LEARN,
                RST=>RST_NET,
                t_spk_bkc(24 downto 0)=>spk_BkC(24 downto 0),
                t_spk_cf(7 downto 0)=>spk_CF(7 downto 0),
                t_spk_grc(4095 downto 0)=>spk_GrC(4095 downto 0),
                t_win(31 downto 0)=>t_win(31 downto 0),
                VALID_I=>VALID_O_BkC,
                t_spk(7 downto 0)=>spk_PkC(7 downto 0),
                VALID_O=>VALID_O_PkC,
                write_weight_syns(77 downto 0)=>write_weight_syns(77 downto 0));

   XLXI_1600 : CELLGROUP_BkC
      port map (CLK=>CLK40M,
                hem=>hem,
                RST=>RST_NET,
                t_spk_grc(4095 downto 0)=>spk_GrC(4095 downto 0),
                VALID_I=>VALID_O_GrC,
                t_spk(24 downto 0)=>spk_BkC(24 downto 0),
                VALID_O=>VALID_O_BkC);

   XLXI_1603 : DataRegister8bit_32reg
      port map (CLK=>CLK40M,
                RST=>SYS_RST,
                WRITE(28 downto 0)=>USB_WOUT(28 downto 0),
                RO_00(31 downto 0)=>g_LTD(31 downto 0),
                RO_01(31 downto 0)=>g_LTP(31 downto 0),
                RO_02(31 downto 0)=>t_win(31 downto 0),
                RO_03(31 downto 0)=>g_cf(31 downto 0),
                RO_04(31 downto 0)=>DC_cf(31 downto 0),
                RO_05(31 downto 0)=>freq(31 downto 0),
                RO_06(31 downto 0)=>amp(31 downto 0),
                RO_07(31 downto 0)=>g_P(31 downto 0),
                RO_08(31 downto 0)=>g_D(31 downto 0),
                RO_09(31 downto 0)=>gain_MSR(31 downto 0),
                RO_10(31 downto 0)=>gain_COM(31 downto 0),
                RO_11(31 downto 0)=>tau_MSR(31 downto 0),
                RO_12(31 downto 0)=>gain_PkC_LPF(31 downto 0),
                RO_13(31 downto 0)=>tau_PkC_LPF(31 downto 0));

   XLXI_1605 : PWMGenerator
      port map (CLK=>CLK40M,
                ENA_SIM=>ENA_SIM,
                gain_COM(31 downto 0)=>gain_COM(31 downto 0),
                MANSIG(31 downto 0)=>COM(31 downto 0),
                RST=>SYS_RST,
                STR=>START_SIM,
                CONSIG0=>MOTCON0,
                CONSIG1=>MOTCON1);

   XLXI_1613 : Selector_to_usb
      port map (CLK=>CLK40M,
                COM(31 downto 0)=>COM(31 downto 0),
                CONMSR(31 downto 0)=>CONMSR(31 downto 0),
                DSR(31 downto 0)=>DSR(31 downto 0),
                ERR(31 downto 0)=>ERR(31 downto 0),
                hem=>hem,
                PID(31 downto 0)=>PID(31 downto 0),
                RST=>SYS_RST,
                spkmean_L(31 downto 0)=>spkmean_L(31 downto 0),
                spkmean_R(31 downto 0)=>spkmean_R(31 downto 0),
                spk_BkC(24 downto 0)=>spk_BkC(24 downto 0),
                spk_CF(7 downto 0)=>spk_CF(7 downto 0),
                spk_GoC(368 downto 0)=>spk_GoC(368 downto 0),
                spk_GrC(4095 downto 0)=>spk_GrC(4095 downto 0),
                spk_MF(245 downto 0)=>spk_MF(245 downto 0),
                spk_PkC(7 downto 0)=>spk_PkC(7 downto 0),
                START_SIM=>START_SIM,
                time_sim(31 downto 0)=>time_sim(31 downto 0),
                VALID_O_MF=>VALID_O_MF,
                write_weight_syns(77 downto 0)=>write_weight_syns(77 downto 0),
                WOUT1(28 downto 0)=>XLXN_8268(28 downto 0));

   XLXI_1614 : ACNNcontroller
      port map (amp(15 downto 0)=>amp(15 downto 0),
                CLK=>CLK40M,
                CONMSR(31 downto 0)=>CONMSR(31 downto 0),
                ENA_cerebellum=>DIP_E(1),
                ENA_DSR(3 downto 0)=>DIP_E(7 downto 4),
                ENA_LEARN=>DIP_E(0),
                ENA_LOAD=>DIP_E(3),
                ENA_PID=>DIP_E(2),
                freq(15 downto 0)=>freq(15 downto 0),
                gain_PkC_LPF(15 downto 0)=>gain_PkC_LPF(15 downto 0),
                g_D(15 downto 0)=>g_D(15 downto 0),
                g_P(15 downto 0)=>g_P(15 downto 0),
                RST=>SYS_RST,
                spk_pkc(7 downto 0)=>spk_PkC(7 downto 0),
                START=>USB_START,
                tau_PkC_LPF(15 downto 0)=>tau_PkC_LPF(15 downto 0),
                VALID_O_PkC=>VALID_O_PkC,
                ENA_SIM_ALL=>ENA_SIM,
                hem_out=>hem,
                LEARN=>LEARN,
                LOAD=>LOAD,
                RST_NET=>RST_NET,
                START_SIM=>START_SIM,
                time_sim_out(31 downto 0)=>time_sim(31 downto 0),
                wave_CF0(15 downto 0)=>wave_CF0(15 downto 0),
                wave_COM(31 downto 0)=>COM(31 downto 0),
                wave_DSR(31 downto 0)=>DSR(31 downto 0),
                wave_ERR(31 downto 0)=>ERR(31 downto 0),
                wave_MF0(15 downto 0)=>wave_MF0(15 downto 0),
                wave_MF1(15 downto 0)=>wave_MF1(15 downto 0),
                wave_MF2(15 downto 0)=>wave_MF2(15 downto 0),
                wave_MF3(15 downto 0)=>XLXN_8582(15 downto 0),
                wave_MF4(15 downto 0)=>XLXN_8583(15 downto 0),
                wave_PID(31 downto 0)=>PID(31 downto 0),
                wave_spkmean_L(31 downto 0)=>spkmean_L(31 downto 0),
                wave_spkmean_R(31 downto 0)=>spkmean_R(31 downto 0));

   XLXI_1634 : RotaryEncoder5a2
      port map (CLK=>CLK40M,
                ENA_SIM=>ENA_SIM,
                gain_MSR(31 downto 0)=>gain_MSR(31 downto 0),
                HALL0=>HALL0,
                HALL1=>HALL1,
                HALL2=>HALL2,
                hem=>hem,
                RST=>SYS_RST,
                STR=>VALID_O_PkC,
                tau_MSR(31 downto 0)=>tau_MSR(31 downto 0),
                CONMSR(31 downto 0)=>CONMSR(31 downto 0));

   XLXI_1635 : Zeros36Bit
      port map (VALUE(35 downto 0)=>ZEROS(35 downto 0));

end BEHAVIORAL;
