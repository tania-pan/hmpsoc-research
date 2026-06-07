GP2 linkable ASP wrappers
=========================
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

