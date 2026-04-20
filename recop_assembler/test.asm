; =========================================================
; ReCOP demo program for board demo
; =========================================================

; -------------------------------
; Demo 1: basic arithmetic
; R1 = 12
; R2 = 8
; R3 = 20
; LEDs show 20
; -------------------------------
LDR R1 #12
LDR R2 #8
LDR R3 #12
ADD R3 R2
SSOP R3

; -------------------------------
; Demo 2: MAX
; R5 starts at 15, MAX with 20 -> 20
; -------------------------------
LDR R5 #15
MAX R5 #20

; -------------------------------
; Demo 3: direct store/load
; store R3 (=20) into memory[100]
; load back into R6
; -------------------------------
STR R3 $100
LDR R6 $100

; -------------------------------
; Demo 4: indirect load
; memory[101] = 55
; R7 = 101
; R8 = M[R7] = 55
; -------------------------------
LDR R9 #55
STR R9 $101
LDR R7 #101
LDR R8 R7

; -------------------------------
; Demo 5: branch on zero
; SUB does not store result, only sets Z
; if 20 - 20 = 0, branch taken
; -------------------------------
SUB R6 #20
SZ ZERO_TAKEN
LDR R11 #111
JMP AFTER_ZERO

ZERO_TAKEN:
LDR R11 #222

AFTER_ZERO:

; -------------------------------
; Demo 6: CLFZ stops branch
; clear Z, then SZ should not jump
; -------------------------------
CLFZ
SZ SHOULD_NOT_TAKE
LDR R13 #333
JMP AFTER_CLFZ

SHOULD_NOT_TAKE:
LDR R13 #999

AFTER_CLFZ:

; -------------------------------
; Demo 7: PRESENT
; if R14 = 0, jump
; -------------------------------
LDR R14 #0
PRESENT R14 #PRESENT_TAKEN
LDR R15 #444
JMP END_DEMO

PRESENT_TAKEN:
LDR R15 #555

END_DEMO:
JMP END_DEMO