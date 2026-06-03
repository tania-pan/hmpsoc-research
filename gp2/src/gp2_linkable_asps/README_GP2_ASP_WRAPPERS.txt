GP2 linkable ASP wrappers
=========================

These files turn the standalone ASP/core designs into linkable GP2-style NoC nodes.

Compile/add order in Quartus:
1. gp2_packet_pkg.vhd
2. signal_rom.vhd
3. signal_gen.vhd
4. symmetry_core.vhd
5. asp_signal_noc.vhd
6. moving_average_noc_asp.vhd
7. symmetry_noc_asp.vhd
8. peak_detector_noc_asp.vhd
9. gp2_asp_chain_stub.vhd   optional direct-chain test top

Common 40-bit packet format:
- bit 39      = valid
- bits 38..35 = message type
    1000 = DATA
    1111 = CONFIG
    1100 = EVENT
- bits 34..32 = destination port, 0 to 7
- bits 31..0  = payload

Config payload convention:
- bits 31..29 = next destination port
- bits 3..2   = moving average window select
    00 = L4
    01 = L8
    10 = L16
- bit 1       = signal generator resolution mode
    0 = 10-bit style
    1 = 8-bit style
- bit 0       = enable

The direct-chain stub is only for proving the ASPs link together.
For final GP2, replace the direct wires with TDMA-MIN NoC ports.
