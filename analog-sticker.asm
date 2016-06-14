.include "tn85def.inc"

.define PIN_IN          PB2
.define PIN_OUT         PB0
.define PIN_RECORD      PB1
.define PIN_TRIGGER     PB4
.define PIN_DONE        PB3

.def scrap           = r19
.def irq_scrap       = r20
.def recording       = r21
.def buffer_ptr_l    = r22
.def buffer_ptr_h    = r23

    ;out     OCR0A, r20

.cseg
.org 0
    rjmp    reset
    nop     ; int0
    nop     ; pcint0
    rjmp    timer_tick
    nop     ; timer1 overflow
    nop     ; timer0 overflow
    nop     ; eeprom ready
    nop     ; analog comparator
    rjmp    conversion_done

conversion_done:
    in      irq_scrap, ADCH
    ; if recording
    ;   save to current position in buffer
    ;   increment position
    reti

timer_tick:
    sbi     PINB, PIN_DONE
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
    sbi     DDRB, PIN_OUT   ; PWM
    cbi     DDRB, PIN_IN    ; A1
    sbi     DDRB, PIN_DONE

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

    ; setup sample timer

    ; clear on match & prescaler set to divide by 4096
    ldi     r16, (1 << CTC1) | (1 << CS13) | (1 << CS12) | (0 << CS11) | (1 << CS10)
    out     TCCR1, r16

    ; interrupt on compare match
    ldi     r16, (1 << OCIE1A)
    out     TIMSK, r16

    ; interrupt 512 times in 60 seconds (with prescaler at 4096 and 8 MHz system clk)
    ; calculated by 8 MHz / 4096 / (512 bytes / 60 seconds)
    ldi     r16, 229
    out     OCR1C, r16

    ; setup application state

    clr     buffer_ptr_l
    clr     buffer_ptr_h

    ; enable interrupts
    sei

    rjmp    start

start_playback:
    rjmp    wait_loop

start_recording:
    rjmp    wait_loop

start:
    rjmp    start
wait_loop:
    sbic    PINB, PIN_RECORD
    rjmp    start_recording

    sbic    PINB, PIN_TRIGGER
    rjmp    start_playback

    rjmp    wait_loop
