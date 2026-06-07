# HMPSoC GP2 Demo README

## Demo overview

This demo shows the final HMPSoC signal-processing system:

ReCOP → TDMA-MIN NoC → Signal Generator ASP → Moving Average ASP → Symmetry/Correlation ASP → Peak Detector ASP → Nios II Mailbox → Nios frequency calculation

ReCOP handles control. The ASPs process the signal in hardware. Nios II reads the peak detector output and calculates the signal frequency.

The key demo feature is live reconfiguration. The signal mode is changed using SW4 and KEY1, without editing `signal_data.mif` or recompiling between 40 Hz and 80 Hz modes.

## How to run the demo

### 1. Open the Quartus project

Open Quartus Prime 18.1 and open:

`hmpsoc_full.qpf`

Make sure the top-level entity is:

`gp2_tdma_full_chain_top`

### 2. Compile the FPGA design

Run:

Processing → Start Compilation

Wait for compilation to finish successfully. Quartus should generate a `.sof` file in the `output_files` folder.

### 3. Program the DE1-SoC board

Connect the DE1-SoC board through USB-Blaster.

Open:

Tools → Programmer

Select the generated `.sof` file and click Start.

After programming, the FPGA hardware is loaded onto the board.

### 4. Open Nios II Software Build Tools

Open:

Nios II Software Build Tools for Eclipse

Open or import the Nios software project:

`frequency_calculator`

and its BSP:

`frequency_calculator_bsp`

### 5. Build the Nios project

In Eclipse, run:

Project → Build All

This should generate:

`frequency_calculator.elf`

### 6. Run the Nios program on hardware

Make sure the FPGA has already been programmed with the latest `.sof`.

Then run:

Run As → Nios II Hardware

The Nios program polls the peak mailbox, reads the peak detector payload, calculates frequency, and prints to the JTAG UART console.

Expected console output:

SW4 = 0 → frequency around 40 Hz  
SW4 = 1 → frequency around 80 Hz

## Controls

### Buttons

KEY0 = reset  
KEY1 = send ReCOP configuration packet / start pipeline  
KEY2 = clear debug snapshot / clear mailbox valid flag

### Main mode switch

SW4 = 0 gives 40 Hz mode  
SW4 = 1 gives 80 Hz mode

### Debug display switches

SW0 = moving average output  
SW1 = symmetry/correlation output  
SW2 = peak detector / Nios mailbox payload  
SW3 = signal generator output  
SW0 to SW3 all off = ReCOP configuration packet  
SW7 = arm snapshot on next peak  
SW8 = freeze debug values  
SW9 = 0 shows low 16 bits  
SW9 = 1 shows high 16 bits

## Demo sequence

1. Reset the board using KEY0.
2. Set SW4 = 0.
3. Press KEY1.
4. ReCOP sends the NoC configuration packet.
5. The ASP pipeline starts.
6. Nios should report about 40 Hz.
7. Set SW4 = 1.
8. Press KEY1 again.
9. ReCOP sends a new configuration packet.
10. Nios should report about 80 Hz.

This proves the system is reconfigured live through NoC packets, not by changing the MIF file.

## Configuration packet check

With SW0 to SW3 all off:

40 Hz mode:

SW9 = 0 should show `0001`  
SW9 = 1 should show `4000`  
Full payload = `0x40000001`

80 Hz mode:

SW9 = 0 should show `0005`  
SW9 = 1 should show `4000`  
Full payload = `0x40000005`

The difference is:

`0x40000005 - 0x40000001 = 0x00000004`

This sets payload bit 2. Bit 2 is the signal-generator frequency mode.

## What the pipeline is doing

The data path is:

Signal Generator → Moving Average → Symmetry/Correlation → Peak Detector → Nios Mailbox → Nios frequency calculation

The signal generator produces samples at a 16 kHz sample tick.

The moving average smooths those samples.

The symmetry ASP calculates a 32-bit correlation value from a moving sample window.

The peak detector watches the correlation stream and outputs an event packet when a local correlation peak is detected.

The peak detector payload is the count between detected symmetry events minus one.

## Expected peak detector values

The signal generator runs from a 16 kHz sample tick.

### 40 Hz mode

Full sine period = 400 samples  
Symmetry detects both top and bottom of the sine wave  
Event spacing = 400 / 2 = 200 samples  
Peak payload = 200 - 1 = 199 = `0x00C7`  
Nios frequency = 16000 / (2 × (199 + 1)) = 40 Hz

Quick check:

SW2 = 1  
SW9 = 0  
HEX should show around `00C7`

### 80 Hz mode

Full sine period = 200 samples  
Event spacing = 200 / 2 = 100 samples  
Peak payload = 100 - 1 = 99 = `0x0063`  
Nios frequency = 16000 / (2 × (99 + 1)) = 80 Hz

Quick check:

SW2 = 1  
SW9 = 0  
HEX should show around `0063`

## Nios mailbox

The peak detector sends event packets to the Nios mailbox on NoC port 6.

The mailbox latches the packet so Nios does not need to catch a one-clock NoC pulse. Nios polls `peak_valid`, reads `peak_payload`, calculates frequency, then clears the mailbox.

Formula used by Nios:

`frequency_hz = 16000 / (2 * (peak_payload + 1))`

The system uses polling rather than interrupts. This is acceptable because the mailbox holds the packet until Nios clears it.

## Polling rate

ReCOP polls KEY1 through its control loop.

The polling loop is about 3 instructions, and each instruction takes about 4 to 6 clock cycles.

With a 50 MHz clock:

Fastest polling = 50 MHz / 12 = 4.17 MHz  
Slowest polling = 50 MHz / 18 = 2.78 MHz

So ReCOP polls KEY1 at approximately 2.8 to 4.2 MHz.

This is much faster than a human button press.

Nios also uses polling, but the mailbox holds packets until cleared, so Nios does not need to catch the NoC pulse directly.

## Important notes

The MIF can be changed for extra waveform testing, but it is not used as the main live demo method.

The main demo uses SW4 and KEY1 to change modes at runtime.

Port 6 is the functional Nios mailbox path.

Port 5 is only debug/reserved.

## Quick demo card

KEY0 reset

SW4 = 0, then KEY1 → Nios prints 40 Hz

SW4 = 1, then KEY1 → Nios prints 80 Hz

SW2 shows peak payload:

40 Hz → `00C7`  
80 Hz → `0063`