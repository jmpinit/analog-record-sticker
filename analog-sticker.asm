.include "tn85def.inc"

.cseg
.org 0
    rjmp    reset
    nop     ; int0
    nop     ; pcint0
    nop     ; timer1 compare
    nop     ; timer1 overflow
    nop     ; timer0 overflow
    nop     ; eeprom ready
    nop     ; analog comparator
    nop     ; conversion_done

delay:
    clr     r0
delay_loop:
    dec     r0
    brne    delay_loop
    dec     r16
    brne    delay
    ret

reset:
    ; setup the stack
    ldi     r16, low(RAMEND)
    out     SPL, r16

    ; setup pins for IO
    ldi     r16, 0xff
    out     DDRB, r16

    ; setup PWM

    ; non-inverting fast PWM mode
    ldi     r16, (1 << COM0A1) | (1 << COM0A0) | (3 << WGM00)
    out     TCCR0A, r16

    ; clock pwm with system clock (no prescaling)
    ldi     r16, (0 << WGM02) | (1 << CS00)
    out     TCCR0B, r16

    ; set frequency
    ldi     r16, 127
    out     OCR0A, r16

blink_loop:
    dec     r17
    out     OCR0A, r17

    ldi     r16, 250
    rcall   delay

    cpi     r17, 0
    brne    blink_loop

    sbi     PINB, PB1

    rjmp    blink_loop