# ReCOP Processor
COMPSYS 701 Group Project 1
## Hardware & Software Requirements
### Hardware:
- **FPGA Board**: Terasic DE1-SoC (Cyclone V)
### Software:
- **Quartus Prime**: Lite/Standard v18.1 or newer with Cyclone V support
- **Python 3.x**: Required to run the `assembler.py` script
## Board Interface
**KEY(0)**: global reset\
**SW(9) = '1'**: selects 50MHz clock\
        **'0':** selects manual debug mode\
**KEY(1)**: press to step through one instruction\
**SW(0:3)**: binary value which selects which debug register value is displayed on the 7-seg display (0000 = R1)\
**HEX(0:3)**: shows the value of the selected register in decimal
## Getting Started
1. **Open Project**: Launch Quartus and open the `.qpf` project file.
2. **Set Top-Level Entity**: Right-click `recop_soc.vhd` in the project navigator and select **Set as Top-Level Entity**.
3. **Assignments** Ensure the DE1-SoC pin assignments are imported (Assignments -> Import Assignments).
4. **Compile**: Click **Start Compilation**.
5. **Flash**:
   - Open Tools -> Programmer.
   - Ensure USB-Blaster is selected.
   - Click Start to load the `.sof` file onto the FPGA.
## Updating Processor Instructions
### Step 1: Assemble
Compile your `.asm` file into a Memory Initialization File (.mif): `python assembler.py instructions.asm instructions.mif`
### Step 2: Update Quartus Memory
1. In Quartus, go to Processing -> Update Memory Initialization File.
2. Go to Tools -> Generate Assembler Files.
3. Flash the board using the Programmer as described above.
