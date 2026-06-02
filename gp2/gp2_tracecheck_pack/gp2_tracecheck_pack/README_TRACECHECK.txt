GP2 ASP trace/check simulation
==============================

Run in Questa:

    cd C:/path/to/gp2_tracecheck_pack
    do run_gp2_tracecheck.do

What this does:

1. Uses signal_rom_file_sim.vhd instead of the Quartus altsyncram ROM.
2. signal_rom_file_sim.vhd reads input_samples.dec, one decimal 12-bit sample per line.
3. input_samples.dec contains 0, 4, 8, 12, ... so the signal generator packet payload becomes 0, 1, 2, 3, ... because asp_signal_noc uses ROM sample bits 11 downto 2.
4. The testbench watches the real pipeline packets:
      sig_to_avg  -> raw sample packet
      avg_to_sym  -> moving average packet
      sym_to_peak -> symmetry/correlation result
      peak_out    -> final output
5. For every moving-average packet it computes the expected L=4 average and asserts that the ASP output matches.

Expected transcript:

    SIG  sample[1] raw_payload=...
    AVG  sample[1] raw=... expected_avg=... got_avg=...
    ...
    TRACE CHECK PASSED

input_samples.mif is included only as a Quartus-style reference file. Questa uses input_samples.dec because it is much easier and more reliable to read from VHDL.
