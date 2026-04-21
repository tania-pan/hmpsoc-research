.ORG 0x0000             ; Set start of code at memory address 0

START:
    ; --- 1. Find the Max ---
    LDR R1, #10         ; R1 = 10
    LDR R2, #50         ; R2 = 50
    MAX R1, R2          ; R1 = max(10, 50) -> R1 is now 50

    ; --- 2. Store and Load (The Memory Loop) ---
    STR R1, $128        ; Write 50 into Data Memory address 128
    LDR R1, #0          ; Clear R1 to 0 (to prove the next load actually works)
    LDR R1, $128        ; Load from address 128 back into R1
                        ; If hardware is correct, R1 is 50 again

    ; --- 3. The Comparison Logic ---
    SUB R1, #50         ; R1 = 50 - 50.
                        ; This result is 0, which sets the ALU Z-flag.

    ; SZ (Skip/Jump if Zero) 
    ; If Z=1, jump to SUCCESS. If Z=0, it falls through to FAILURE.
    SZ SUCCESS        

FAILURE:
    LDR R1, #111      ; Hex displays show 111 if memory/MAX failed
    JMP START           ; Loop back to reset

SUCCESS:
    LDR R1, #999      ; Hex displays show 999 if the whole chain works
    SSOP R1             ; Displays 999 on LEDs in binary