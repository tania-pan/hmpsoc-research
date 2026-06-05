HMPSOC GP2 simple demo controls
===============================

Use this build for the live demo.

Buttons:
- KEY0 = reset
- KEY1 = start the pipeline. This is the external event that ReCOP polls.
- KEY2 = clear the peak snapshot / re-arm snapshot debug.

Switches:
- all SW0..SW3 off = show ReCOP config packet. Expected: low=0001, high=4000.
- SW0 = show moving average output
- SW1 = show symmetry/correlation output
- SW2 = show peak detector output
- SW3 = show signal generator output
- SW7 = arm snapshot on next peak. Toggle SW7 from 0 to 1 after the pipeline is running.
- SW8 = manual freeze of live values
- SW9 = word select: 0 = low 16 bits, 1 = high 16 bits

Expected peak detector check:
- The signal_data.mif file is a 1600-sample sine table with a 400-sample full period.
- The symmetry detector sees both sine maxima and minima as symmetric points.
- Therefore peak events occur every half period: about 200 samples.
- The peak detector counter displays period_minus_1, so expected value is about 199 decimal = 0x00C7.
- For demo: set SW2=1 and SW9=0. Expected HEX is about 00C7.

Frequency calculation:
- sample tick = 16 kHz
- event spacing shown = 0x00C7 = 199, so samples between symmetry events ~= 199 + 1 = 200
- sine full period = 2 * 200 = 400 samples, because both max and min are detected
- frequency = 16000 / 400 = 40 Hz

Which MIF do I change?
- Change only: signal_data.mif
- This is the waveform ROM used by the signal generator.
- Do not change the ReCOP instructions MIF unless you are changing the ReCOP control program.

Do I need a full recompile after changing signal_data.mif?
- Usually no full synthesis is needed for a MIF-only change.
- In Quartus, use Processing -> Update Memory Initialization File, then run Assembler, then program the board.
- If Quartus does not pick up the MIF update, do a full compile once.

Demo proof:
1. Reset: only running/heartbeat should be active.
2. Press KEY1: ReCOP sees the event and sends the NoC config packet.
3. Show config packet: all SW0..SW3 off. Low=0001, high=4000.
4. Show SW3: signal generator stream is live.
5. Show SW0: moving average output is live and different from raw signal.
6. Show SW1: symmetry/correlation stream is live.
7. Show SW2: peak detector output is stable around 00C7, proving detected peak spacing matches the known 400-sample sine period.


Nios peak-mailbox integration
=============================

What changed
------------
1. Peak detector output is now routed to NoC port 6 instead of the old debug sink.
2. Added gp2_files/gp2_linkable_asps/nios_noc_mailbox.vhd.
3. The mailbox latches peak-detector packets and exposes stable signals:
   - peak_valid_o
   - peak_payload_o
   - peak_count_o
   - overflow_o
   - peak_clear_i
4. Added nios_software/nios_peak_frequency_polling.c as the Nios polling example.

Why this is the right interface
-------------------------------
Nios should not try to catch a one-clock TDMA-MIN packet. The VHDL mailbox
turns the packet into a stable register-style interface. Nios polls peak_valid,
reads peak_payload, computes frequency, then clears the valid flag.

Frequency calculation
---------------------
The peak detector payload is the count between symmetry events minus 1.
For the period-400 sine MIF the board shows approximately:

    payload = 0x00C7 = 199
    event_spacing = payload + 1 = 200 samples

The symmetry detector fires at both the top and bottom of the sine wave, so:

    full_period_samples = 2 * event_spacing = 400
    frequency = 16000 / 400 = 40 Hz

General formula used by Nios:

    frequency_hz = SAMPLE_RATE_HZ / (2 * (peak_payload + 1))

How to connect to Nios
----------------------
This ZIP does not contain a full Platform Designer Nios system. To connect it:

Option A, quickest:
- Add PIO inputs for peak_valid_o and peak_payload_o.
- Add a PIO output for peak_clear_i.
- Connect those PIOs to the nios_noc_mailbox signals.
- Use nios_software/nios_peak_frequency_polling.c.

Option B, cleaner:
- Wrap nios_noc_mailbox in a small Avalon-MM slave with registers:
    offset 0: status bit0=valid, bit1=overflow
    offset 1: payload
    offset 2: packet count
    offset 3: write 1 to clear

Demo controls preserved
-----------------------
KEY0 = reset
KEY1 = start pipeline through ReCOP
KEY2 = clear peak snapshot and mailbox valid
SW0 = moving average display
SW1 = symmetry/correlation display
SW2 = peak/Nios-mailbox payload display
SW3 = signal display
SW7 = arm peak snapshot
SW8 = manual freeze
SW9 = high/low 16-bit display
