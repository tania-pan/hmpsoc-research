# Questa/ModelSim script for GP2 ASP chain simulation
# Run from the folder containing all VHDL files and this .do file.

transcript on

if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

# Compile order matters: package first, then cores, wrappers, top, testbench.
vcom -2008 gp2_packet_pkg.vhd
vcom -2008 signal_rom_sim.vhd
vcom -2008 signal_gen.vhd
vcom -2008 symmetry_core.vhd
vcom -2008 asp_signal_noc.vhd
vcom -2008 moving_average_noc_asp.vhd
vcom -2008 symmetry_noc_asp.vhd
vcom -2008 peak_detector_noc_asp.vhd
vcom -2008 gp2_asp_chain_stub.vhd
vcom -2008 tb_gp2_asp_chain_stub.vhd

vsim -voptargs=+acc work.tb_gp2_asp_chain_stub

# Top-level TB signals
add wave -radix binary sim:/tb_gp2_asp_chain_stub/clk
add wave -radix binary sim:/tb_gp2_asp_chain_stub/reset_n
add wave -radix binary sim:/tb_gp2_asp_chain_stub/tick_16khz
add wave -radix hexadecimal sim:/tb_gp2_asp_chain_stub/config_pkt
add wave -radix hexadecimal sim:/tb_gp2_asp_chain_stub/final_pkt
add wave -radix binary sim:/tb_gp2_asp_chain_stub/peak_irq

# Internal direct-chain packets inside DUT
add wave -divider "ASP chain packets"
add wave -radix hexadecimal sim:/tb_gp2_asp_chain_stub/dut/sig_to_avg
add wave -radix hexadecimal sim:/tb_gp2_asp_chain_stub/dut/avg_to_sym
add wave -radix hexadecimal sim:/tb_gp2_asp_chain_stub/dut/sym_to_peak
add wave -radix hexadecimal sim:/tb_gp2_asp_chain_stub/dut/peak_out

# Debug internals if names exist
add wave -divider "All DUT internals"
add wave -r sim:/tb_gp2_asp_chain_stub/dut/*

run 2 ms

wave zoom full