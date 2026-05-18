vlib work
vmap work work

vcom -2008 symmetry_core.vhd
vcom -2008 tb_symmetry_core.vhd

vsim work.tb_symmetry_core

add wave -r /*
run 300 us