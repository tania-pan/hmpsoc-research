GP2 HMPSoC demo controls
=======================

KEY0 = reset
KEY1 = start pipeline through ReCOP
KEY2 = clear peak snapshot / disarm snapshot

SW7 = arm peak snapshot. IMPORTANT: toggle SW7 low -> high AFTER the pipeline is running.
      Holding SW7 high during reset will not automatically take a snapshot.
SW8 = manual freeze of live debug values
SW9 = HEX high/low 16-bit select

SW[2:0] selects HEX payload:
000 = ReCOP config payload at signal ASP. Expected high=4000, low=0001
001 = signal generator output payload
010 = moving average output payload
011 = symmetry/correlation output payload
100 = peak detector/final output payload

Recommended demo flow:
1. Set SW7=0 and SW8=0.
2. Reset with KEY0.
3. Press KEY1 to start the pipeline. LEDs should advance/latch through the stages.
4. Show live values changing on HEX using SW[2:0].
5. Toggle SW7 from 0 to 1 to arm snapshot-on-next-peak.
6. LEDR8 turns on while armed/captured. When the next peak-detector packet arrives, HEX freezes on the captured snapshot.
7. Use SW[2:0] and SW9 to inspect frozen stage values.
8. Press KEY2 to clear/disarm, then toggle SW7 low->high again to capture another peak.

Design note:
SW7 does not stop the real ASP/NoC pipeline. It only freezes the debug snapshot when a fresh peak-detector output packet arrives. The actual real-time stream continues running.

Period-400 sine MIF update
--------------------------
This ZIP uses signal_data.mif as a 1600-depth, 12-bit sine wave with 4 cycles in the table.
Therefore the sine period is 400 samples.
With a 16 kHz sample tick, expected frequency is:
    f = 16000 / 400 = 40 Hz

The peak detector payload currently represents the measured sample count/index between detected peaks.
Because of the detector counter timing, the expected displayed value is likely period-1:
    399 decimal = 0x018F
So SW[2:0] = 100, SW9 = 0 should show around 018F when detecting the period-400 sine.
