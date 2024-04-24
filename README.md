# Artificial Cerebellum on an FPGA

![langage][langage-shield] ![target][target-shield] ![environment][environment-shield] ![license][license-shield]

## Overview
This repository is a real-time adaptive controller using a realistic cerebellar spiking neural network model on an FPGA. It is published in [Y. Shinji, H. Okuno & Y. Hirata, Front. Neurosci., 2024][myDOI].

## Directory layout
    .
    │  top.vhd               # Map of top level
    │  MultiCamIF.ucf        # User Constraints File to descrive using in/out pins
    │  DCM40M80M.vhd         # Converting Clock
    │
    ├─ArtificialCerebellum
    │  ├─BkC                 # Processor of molecular layer inhibitory 
    │  │      CELLGROUP_BkC.vhd
    │  │      CELL_BkC.vhd
    │  │      FF_t_spk_BkC.vhd
    │  │      FIFO_g_syn_BkC_GrC.vhd
    │  │      FIFO_v_mb_BkC.vhd
    │  │      MUX_BkC_GrC.vhd
    │  │
    │  ├─CF                  # Processor of climbing fibers
    │  │      CfNonLinFunc.vhd
    │  │      FF_t_spk_CF.vhd
    │  │      FIBERGROUP_CF.vhd
    │  │      FIBER_CF.vhd
    │  │      FIFO_v_mb_CF.vhd
    │  │      MUX_CF.vhd
    │  │
    │  ├─Common              # Neuron and Synapse model
    │  │      LFSR32bit.vhd
    │  │      MEMPOT16bit.vhd
    │  │      Pinknoise.vhd
    │  │      SYNCND16bit.vhd
    │  │      SYNCUR16bit.vhd
    │  │
    │  ├─GoC                 # Processor of Golgic cells
    │  │      CELLGROUP_GoC.vhd
    │  │      CELL_GoC.vhd
    │  │      FF_t_spk_GoC.vhd
    │  │      FIFO_g_syn_GoC_GrC.vhd
    │  │      FIFO_g_syn_GoC_MF.vhd
    │  │      FIFO_v_mb_GoC.vhd
    │  │      MUX_GoC_GrC.vhd
    │  │      MUX_GoC_MF.vhd
    │  │
    │  ├─GrC                 # Processor of granule cells
    │  │      CELLGROUP_GrC.vhd
    │  │      CELL_GrC.vhd
    │  │      FF_t_spk_GrC.vhd
    │  │      FIFO_g_syn_GrC_GoC.vhd
    │  │      FIFO_g_syn_GrC_MF.vhd
    │  │      FIFO_v_mb_GrC.vhd
    │  │      MUX_GrC_GoC.vhd
    │  │      MUX_GrC_MF.vhd
    │  │
    │  ├─MF                  # Processor of mossy fibers
    │  │      FF_t_spk_MF.vhd
    │  │      FIBERGROUP_MF.vhd
    │  │      FIBER_MF.vhd
    │  │      FIFO_v_mb_MF.vhd
    │  │      MUX_MF.vhd
    │  │
    │  ├─Others              # Controler of neuron processors
    │  │      ACNNcontroller.vhd
    │  │      FIFO_spks_GrC.vhd
    │  │      FIFO_weight.vhd
    │  │      LPF_SPK.vhd
    │  │      PID_Controller.vhd
    │  │      PWMGenerator.vhd
    │  │      ROM_DSR.vhd
    │  │      RotaryEncoder5a2.vhd
    │  │      Selector_spk_grc.vhd
    │  │      Selector_stim.vhd
    │  │      Selector_to_usb.vhd
    │  │      Selector_weight.vhd
    │  │
    │  └─PkC                 # Processor of Purkinje cells
    │          CELLGROUP_PkC.vhd
    │          CELL_PkC.vhd
    │          FF_t_spk_PkC.vhd
    │          FIFO_g_syn_PkC_BkC.vhd
    │          FIFO_g_syn_PkC_GrC.vhd
    │          FIFO_g_weight_grc.vhd
    │          FIFO_v_mb_PkC.vhd
    │          FIFO_weight_PkC_GrC_0.vhd
    │          FIFO_weight_PkC_GrC_1.vhd
    │          FIFO_weight_PkC_GrC_2.vhd
    │          FIFO_weight_PkC_GrC_3.vhd
    │          MUX_PkC_BkC.vhd
    │          MUX_PkC_GrC_0.vhd
    │          MUX_PkC_GrC_1.vhd
    │          MUX_PkC_GrC_2.vhd
    │          MUX_PkC_GrC_3.vhd
    │          MUX_PkC_GrC_nonInteg.vhd
    │          STDP_PF_PkC.vhd
    │
    ├─USBController         # EzUsb Controller
    │      DataRegister8bit_32reg.vhd
    │      BRAM_1P_QQVGA_Async1.vhd
    │      EZUSBctrlv31_QQVGA.vhd
    │      Zeros36Bit.vhd
    │      Timing_Generator_LVDS.vhd
    │
    └─coe                   # Initial value of ROM
            Waveform.png
            wave_sin.coe
            wave_sqr.coe
            wave_tri.coe

## Requirement
This controller requires the following Xilinx IP cores.

| Core name | Instance name | Options |
|:--|:--|:--|
| Clocking Wizard | DCM40M80M_SP6 | Input Frequency: 50 MHz, Input Jitter: 0.01, Output Clock 1: 40 MHz, 0 degrees and 50 % duty cycle, Output Clock 2: 80 MHz, 0 degrees and 50 % duty cycle, Optional Input: RESET |
| Multiplier | MULT_16_16 | Port A: signed 16, Port B: signed 16, Multiplier Construction: Use Mults |
| Multiplier | MULT_16_16_NoneDSP | Port A: signed 16, Port B: signed 16, Multiplier Construction: Use LUTs |
| Multiplier | MULT_23_16 | Port A: signed 32, Port B: signed 16, Multiplier Construction: Use Mults |
| Multiplier | MULT_32_16 | Port A: signed 32, Port B: signed 16, Multiplier Construction: Use Mults |
| Block Memory Generator | blk_mem_gen_v7_3 | Memory Type: Simple Dual Port RAM, Port A write width: 23, Port A write depth: 8192, Port B read width: 23, Port B read depth: 8192 |
| Block Memory Generator | ramb_dual2_fifo_spks_grc | Memory Type: Simple Dual Port RAM, Port A write width: 8, Port A write depth: 4096, Port B read width: 8, Port B read depth: 4096 |
| Block Memory Generator | ramb_dual2_fifo_weight | Memory Type: Simple Dual Port RAM, Port A write width: 16, Port A write depth: 512, Port B read width: 16, Port B read depth: 512 |
| Block Memory Generator | ramb_dual2_g_syn_BkC_GrC | Memory Type: Simple Dual Port RAM, Port A write width: 16, Port A write depth: 25, Port B read width: 16, Port B read depth: 25 |
| Block Memory Generator | ramb_dual2_g_syn_GoC_GrC | Memory Type: Simple Dual Port RAM, Port A write width: 16, Port A write depth: 123, Port B read width: 16, Port B read depth: 123 |
| Block Memory Generator | ramb_dual2_g_syn_GoC_MF | Memory Type: Simple Dual Port RAM, Port A write width: 16, Port A write depth: 123, Port B read width: 16, Port B read depth: 123 |
| Block Memory Generator | ramb_dual2_g_syn_GrC_GoC | Memory Type: Simple Dual Port RAM, Port A write width: 16, Port A write depth: 1024, Port B read width: 16, Port B read depth: 1024 |
| Block Memory Generator | ramb_dual2_g_syn_GrC_MF | Memory Type: Simple Dual Port RAM, Port A write width: 16, Port A write depth: 1024, Port B read width: 16, Port B read depth: 1024 |
| Block Memory Generator | ramb_dual2_g_syn_PkC_BkC | Memory Type: Simple Dual Port RAM, Port A write width: 16, Port A write depth: 8, Port B read width: 16, Port B read depth: 8 |
| Block Memory Generator | ramb_dual2_g_syn_PkC_GrC | Memory Type: Simple Dual Port RAM, Port A write width: 16, Port A write depth: 8, Port B read width: 16, Port B read depth: 8 |
| Block Memory Generator | ramb_dual2_g_weight_pkc_grc | Memory Type: Simple Dual Port RAM, Port A write width: 16, Port A write depth: 8192, Port B read width: 16, Port B read depth: 8192 |
| Block Memory Generator | ramb_dual2_v_mb_BkC | Memory Type: Simple Dual Port RAM, Port A write width: 16, Port A write depth: 25, Port B read width: 16, Port B read depth: 25 |
| Block Memory Generator | ramb_dual2_v_mb_CF | Memory Type: Simple Dual Port RAM, Port A write width: 16, Port A write depth: 8, Port B read width: 16, Port B read depth: 8 |
| Block Memory Generator | ramb_dual2_v_mb_GoC | Memory Type: Simple Dual Port RAM, Port A write width: 16, Port A write depth: 123, Port B read width: 16, Port B read depth: 123 |
| Block Memory Generator | ramb_dual2_v_mb_GrC | Memory Type: Simple Dual Port RAM, Port A write width: 16, Port A write depth: 1024, Port B read width: 16, Port B read depth: 1024 |
| Block Memory Generator | ramb_dual2_v_mb_MF | Memory Type: Simple Dual Port RAM, Port A write width: 16, Port A write depth: 246, Port B read width: 16, Port B read depth: 246 |
| Block Memory Generator | ramb_dual2_v_mb_PkC | Memory Type: Simple Dual Port RAM, Port A write width: 16, Port A write depth: 8, Port B read width: 16, Port B read depth: 8 |
| Block Memory Generator | ramb_dual2_weight_pkc_grc_0 | Memory Type: Simple Dual Port RAM, Port A write width: 16, Port A write depth: 8192, Port B read width: 16, Port B read depth: 8192 |
| Block Memory Generator | ramb_dual2_weight_pkc_grc_1 | Memory Type: Simple Dual Port RAM, Port A write width: 16, Port A write depth: 8192, Port B read width: 16, Port B read depth: 8192 |
| Block Memory Generator | ramb_dual2_weight_pkc_grc_2 | Memory Type: Simple Dual Port RAM, Port A write width: 16, Port A write depth: 8192, Port B read width: 16, Port B read depth: 8192 |
| Block Memory Generator | ramb_dual2_weight_pkc_grc_3 | Memory Type: Simple Dual Port RAM, Port A write width: 16, Port A write depth: 8192, Port B read width: 16, Port B read depth: 8192 |
| Block Memory Generator | ramb_qqvga_dual2 | Memory Type: Simple Dual Port RAM, Port A write width: 8, Port A write depth: 15, Port B read width: 8, Port B read depth: 15 |
| Block Memory Generator | rom_single_wave_sin | Memory Type: Single Port ROM, Port A write width: 23, Port A write depth: 8192, Load Init File, ./coe/wave_sin.coe |
| Block Memory Generator | rom_single_wave_sqr | Memory Type: Single Port ROM, Port A write width: 23, Port A write depth: 8192, Load Init File, ./coe/wave_sqr.coe |
| Block Memory Generator | rom_single_wave_tri | Memory Type: Single Port ROM, Port A write width: 23, Port A write depth: 8192, Load Init File, ./coe/wave_tri.coe |


## License
This project is licensed under the BSD 3-Clause License - see the LICENSE.md file for details



<!-- MARKDOWN LINKS & IMAGES -->
[myDOI]: https://doi.org/10.3389/fnins.2024.1220908
[langage-shield]: https://img.shields.io/badge/langage-VHDL--93-1e90ff.svg?style=for-the-plastic
[target-shield]: https://img.shields.io/badge/target%20device-Spartan6--XC6SLX100--FGG484-1e90ff.svg?style=for-the-plastic
[environment-shield]: https://img.shields.io/badge/environment-ISE%20Design%20Suite%2014.7-1e90ff.svg?style=for-the-plastic
[license-shield]: https://img.shields.io/badge/license-BSD%203--Clause-32cd32.svg?style=for-the-plastic