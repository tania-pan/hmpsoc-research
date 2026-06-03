.ORG 0x0000

START:
    ; Wait for a live external event before starting the ASP pipeline.
    ; KEY1 is latched by recop_noc_wrapper and presented on SIP(0).
    ; PRESENT branches when R1 is zero, so it loops while no button is latched.

WAIT_BUTTON:
    LSIP R1
    ; PRESENT branches when R1 is ZERO.
    ; So if button/SIP is still 0, branch back and keep waiting.
    PRESENT R1 WAIT_BUTTON

SEND_CONFIG:

    ; ReCOP configures the GP2 NoC/ASP chain using memory-mapped registers.
    ; 0x3000 = NoC destination address
    ; 0x3001 = payload high word
    ; 0x3002 = payload low word
    ; 0x3003 = send trigger

    ; Send CONFIG packet to signal-generator ASP at NoC port 1.
    ; Payload = 0x40000001:
    ;   bits 31..29 = 010, next destination after signal ASP is port 2
    ;   bit 0       = 1, enable/start signal generation
    ; The wrapper/NoC adds a separate valid bit, so the full 32-bit payload is preserved.

    LDR R1, #0x0001
    STR R1, $0x3000      ; destination address = port 1

    LDR R1, #0x4000
    STR R1, $0x3001      ; payload high word

    LDR R1, #0x0001
    STR R1, $0x3002      ; payload low word

    LDR R1, #0x0001
    STR R1, $0x3003      ; trigger send

DONE:
    JMP DONE
