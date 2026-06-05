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
