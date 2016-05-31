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
    rjmp    conversion_done

conversion_done:
    in      r20, ADCH
    out     OCR0A, r20
    reti

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
    sbi     DDRB, PB0   ; PWM
    cbi     DDRB, PB2   ; A1

    ; setup ADC

    ; left adjusted
    ldi     r16, (1 << ADLAR) | (1 << MUX0)
    out     ADMUX, r16

    ; enable, start, run free, enable interrupt, divide clock by 128
    ldi     r16, (1 << ADEN) | (1 << ADSC) | (1 << ADATE) | (1 << ADIE) | (7 << ADPS0)
    out     ADCSRA, r16

    ; reduce power consumption by disabling digital in
    ldi     r16, (1 << ADC1D)
    out     DIDR0, r16

    ; setup PWM

    ; non-inverting fast PWM mode
    ldi     r16, (1 << COM0A1) | (1 << COM0A0) | (3 << WGM00)
    out     TCCR0A, r16

    ; clock pwm with system clock (no prescaling)
    ldi     r16, (0 << WGM02) | (1 << CS00)
    out     TCCR0B, r16

    ; set frequency
    ldi     r16, 0
    out     OCR0A, r16

    ; enable interrupts
    sei

blink_loop:
    rjmp    blink_loop