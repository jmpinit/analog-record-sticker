.include "tn85def.inc"

.cseg
.org 0
    rjmp    reset

reset:
    ; setup the stack
    ldi     r16, low(RAMEND)
    out     SPL, r16

    ; setup pins for io
    sbi     DDRB, PB0

blink_loop:
    sbi     PORTB, PB0
    nop
    cbi     PORTB, PB0
    nop

    rjmp    blink_loop