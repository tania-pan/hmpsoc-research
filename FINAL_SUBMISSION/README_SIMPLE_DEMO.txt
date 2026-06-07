HMPSoC GP2 Demo README

What this demo shows

This demo shows a working HMPSoC signal-processing pipeline using:

ReCOP as the control processor
TDMA-MIN as the NoC interconnect
Hardware ASPs for signal generation, moving average, symmetry/correlation, and peak detection
Nios II as the software processor that reads peak-event packets and calculates frequency

The important point is that the waveform mode is changed live using a switch and button. The demo does not require changing the MIF file or recompiling between 40 Hz and 80 Hz modes.

Basic demo controls

Buttons:

KEY0 = reset
KEY1 = start/configure the pipeline
KEY2 = clear debug snapshot / clear mailbox valid flag

Main switch:

SW4 = 0 gives 40 Hz signal mode
SW4 = 1 gives 80 Hz signal mode

After changing SW4, press KEY1 again to send a new configuration packet.

Debug display controls

The HEX display can show different pipeline values:

All SW0 to SW3 off = show the ReCOP configuration packet
SW0 = show moving average output
SW1 = show symmetry/correlation output
SW2 = show peak detector / Nios mailbox payload
SW3 = show signal generator output
SW7 = arm snapshot on next peak
SW8 = manually freeze current debug values
SW9 = word select:
SW9 = 0 shows low 16 bits
SW9 = 1 shows high 16 bits

Configuration packet check:

SW0 to SW3 all off, SW9 = 0 should show 0001 in 40 Hz mode
SW0 to SW3 all off, SW9 = 1 should show 4000
In 80 Hz mode, the low word becomes 0005

The two key configuration payloads are:

0x40000001 = enable signal generator, 40 Hz mode
0x40000005 = enable signal generator, 80 Hz mode

The only difference is 0x00000004, which is bit 2. Bit 2 is the signal-generator frequency mode.

Demo sequence

Reset the board using KEY0.
Set SW4 = 0.
Press KEY1.
ReCOP sends the NoC configuration packet.
The ASP pipeline starts.
Nios should report approximately 40 Hz.
Change SW4 = 1.
Press KEY1 again.
ReCOP sends a new configuration packet.
The signal generator changes to 80 Hz mode.
Nios should report approximately 80 Hz.

This proves that the system is live-reconfigurable using NoC packets rather than changing the MIF file.

What the pipeline is doing

The data path is:

Signal Generator -> Moving Average -> Symmetry/Correlation -> Peak Detector -> Nios Mailbox -> Nios frequency calculation

The signal generator produces samples at a 16 kHz sample tick. The moving average smooths those samples. The symmetry ASP calculates a 32-bit correlation value from a moving sample window. The peak detector watches the correlation stream and outputs an event packet when a local correlation peak is detected.

The peak detector payload is the count between detected symmetry events minus one.

Why the peak value is 00C7 in 40 Hz mode

For 40 Hz mode, the sine wave has a 400-sample full period:

16000 samples/s / 400 samples = 40 Hz

The symmetry detector responds to both the top and bottom of the sine wave, because both are symmetric points. So it produces events every half-period:

400 samples / 2 = 200 samples

The peak detector outputs the spacing minus one:

200 - 1 = 199

199 decimal = 0x00C7

So in 40 Hz mode:

SW2 = 1
SW9 = 0
HEX should show around 00C7

Nios then calculates:

frequency = 16000 / (2 * (payload + 1))

frequency = 16000 / (2 * (199 + 1))

frequency = 40 Hz

Expected values

Mode: 40 Hz
SW4: 0
Expected payload: 0x00C7 / 199
Expected frequency: 40 Hz

Mode: 80 Hz
SW4: 1
Expected payload: 0x0063 / 99
Expected frequency: 80 Hz

For 80 Hz mode:

period = 200 samples

symmetry event spacing = 100 samples

payload = 100 - 1 = 99 = 0x0063

frequency = 16000 / (2 * 100) = 80 Hz

Nios mailbox

The peak detector sends event packets to the Nios mailbox on NoC port 6.

The mailbox latches the packet so Nios does not need to catch a one-clock NoC pulse. Nios polls:

peak_valid
peak_payload

Then it calculates frequency and clears the mailbox.

The formula used by Nios is:

frequency_hz = 16000 / (2 * (peak_payload + 1))

The system uses polling rather than interrupts. This is acceptable because the mailbox holds the packet until Nios clears it.

Polling rate

ReCOP polls the KEY1 event through its control loop. The polling loop is approximately three instructions. Each ReCOP instruction takes about 4 to 6 clock cycles.

At a 50 MHz clock:

minimum polling rate = 50 MHz / 18 = about 2.78 MHz

maximum polling rate = 50 MHz / 12 = about 4.17 MHz

So ReCOP polls KEY1 at approximately 2.8 to 4.2 MHz, which is much faster than a human button press.

Nios also polls the mailbox. The exact Nios polling rate depends on the compiled C program and JTAG UART printing speed, but the mailbox holds valid packets until cleared, so packet loss is avoided for this demo.

What to say during the demo

ReCOP is responsible for control. KEY1 is an external event. When KEY1 is pressed, ReCOP sends a configuration packet through TDMA-MIN to the signal generator. SW4 controls one bit in that packet, selecting either 40 Hz or 80 Hz mode.

The ASPs then process the signal in hardware. The peak detector sends event-spacing packets to the Nios mailbox. Nios reads the packet payload and calculates the frequency in software.

This demonstrates control-flow processing, hardware dataflow acceleration, NoC communication, runtime reconfiguration, and software-level frequency calculation in one HMPSoC system.

Important notes

The MIF can be changed to test different stored waveforms, but it should not be used as the main live demo method. The main demo uses SW4 and KEY1 so that ReCOP sends a NoC configuration packet and changes the signal mode at runtime without recompilation or reprogramming.

Use SW4 and KEY1 to change between 40 Hz and 80 Hz.
The MIF is only the waveform ROM source.
The live reconfiguration is done by ReCOP sending a NoC configuration packet.
Port 6 is the functional Nios mailbox output path.
Port 5 is only a debug/reserved display slot.

Quick demo card

KEY0 reset

SW4 = 0, then KEY1 -> Nios prints 40 Hz

SW4 = 1, then KEY1 -> Nios prints 80 Hz

SW2 shows peak payload:

00C7 for 40 Hz
0063 for 80 Hz