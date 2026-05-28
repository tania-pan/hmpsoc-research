transcript on
if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

vcom -2008 gp2_packet_pkg.vhd
vcom -2008 signal_rom_file_sim.vhd
vcom -2008 signal_gen.vhd
vcom -2008 symmetry_core.vhd
vcom -2008 asp_signal_noc.vhd
vcom -2008 moving_average_noc_asp.vhd
vcom -2008 symmetry_noc_asp.vhd
vcom -2008 peak_detector_noc_asp.vhd
vcom -2008 gp2_asp_chain_probe.vhd
vcom -2008 tb_gp2_asp_chain_tracecheck.vhd

vsim -voptargs=+acc work.tb_gp2_asp_chain_tracecheck

add wave -divider "Top-level control"
add wave -radix binary sim:/tb_gp2_asp_chain_tracecheck/clk
add wave -radix binary sim:/tb_gp2_asp_chain_tracecheck/reset_n
add wave -radix binary sim:/tb_gp2_asp_chain_tracecheck/tick_16khz
add wave -radix hexadecimal sim:/tb_gp2_asp_chain_tracecheck/config_pkt

add wave -divider "ASP chain packets"
add wave -radix hexadecimal sim:/tb_gp2_asp_chain_tracecheck/sig_to_avg
add wave -radix hexadecimal sim:/tb_gp2_asp_chain_tracecheck/avg_to_sym
add wave -radix hexadecimal sim:/tb_gp2_asp_chain_tracecheck/sym_to_peak
add wave -radix hexadecimal sim:/tb_gp2_asp_chain_tracecheck/peak_out
add wave -radix hexadecimal sim:/tb_gp2_asp_chain_tracecheck/final_pkt
add wave -radix binary sim:/tb_gp2_asp_chain_tracecheck/peak_irq

add wave -divider "Packet counters"
add wave -radix unsigned sim:/tb_gp2_asp_chain_tracecheck/sig_count
add wave -radix unsigned sim:/tb_gp2_asp_chain_tracecheck/avg_count
add wave -radix unsigned sim:/tb_gp2_asp_chain_tracecheck/sym_count
add wave -radix unsigned sim:/tb_gp2_asp_chain_tracecheck/final_count

add wave -divider "ROM / signal generator internals"
add wave -radix unsigned sim:/tb_gp2_asp_chain_tracecheck/dut/u_signal/u_signal_gen/rom_address
add wave -radix unsigned sim:/tb_gp2_asp_chain_tracecheck/dut/u_signal/core_signal_out
add wave -radix binary   sim:/tb_gp2_asp_chain_tracecheck/dut/u_signal/core_data_ready
add wave -radix binary   sim:/tb_gp2_asp_chain_tracecheck/dut/u_signal/enabled

run -all
wave zoom full
