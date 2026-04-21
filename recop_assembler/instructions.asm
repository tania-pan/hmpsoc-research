.ORG 0x0000             ; set start address to 0
START:
    LSIP R1             ; Read the physical Switches into R1
    LDR R2 #1           ; Load the value 1
    ADD R3 R1 R2        ; R3 = Switches + 1
    SSOP R3             ; Output the result to the LEDs
    
    ; Test a branch
    SUB R1 #0           ; Check if switches are all at 0
    SZ IS_ZERO          ; If switches are 0, jump to IS_ZERO
    JMP START           ; Otherwise, keep looping

IS_ZERO:
    LDR R4 #0xAAAA      ; Load a pattern (10101010...)
    SSOP R4             ; Light up the LEDs in a pattern
    JMP START           ; Go back
