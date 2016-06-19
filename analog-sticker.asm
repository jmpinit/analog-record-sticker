.include "tn85def.inc"

.define STACK_SIZE      12 ; bytes
.define DATA_END        (RAMEND-STACK_SIZE) ; end of buffer

.define PIN_IN          PB2
.define PIN_OUT         PB0
.define PIN_RECORD      PB1
.define PIN_TRIGGER     PB4
.define PIN_DONE        PB3

.define RECORDING       0
.define PLAYING         1

.def zero            = r15
.def scrap           = r19
.def sreg_save       = r20
.def irq_scrap_a     = r21
.def irq_scrap_b     = r22
.def flags           = r23

.macro reset_buffer_ptr
    ldi     XL, low(SRAM_START)
    ldi     XH, high(SRAM_START)
.endm

.macro brne_16
    cpi     XH, high(@1)
    brne    @0
    cpi     XL, low(@1)
    brne    @0
.endm

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
    nop     ; conversion_done

timer_tick:
    in      sreg_save, SREG

    ; check if at end of buffer
    brne_16 timer_tick_sample, DATA_END

    ; at end of buffer
    ; so stop what we were doing
    clr     flags
    rjmp    timer_done

timer_tick_sample:
; if recording
    sbrs    flags, RECORDING
    rjmp    not_recording

    sbi     PINB, PIN_DONE ; FIXME

    ; read adc
    in      irq_scrap_a, ADCH

    ; save adc reading at current buffer index
    ; and increment index
    st      X+, irq_scrap_a

not_recording:

; if playing back
    sbrs    flags, PLAYING
    rjmp    not_playing

    ; read data from buffer
    ld      irq_scrap_a, X+

    ; playback via pwm

    ; linearize output using lookup table
    ldi     ZH, high(analog_out_lookup << 1)
    ldi     ZL, low(analog_out_lookup << 1)
    add     ZL, irq_scrap_a
    adc     ZH, zero

    lpm     irq_scrap_a, Z

    out     OCR0A, irq_scrap_a

not_playing:

timer_done:
    out     SREG, sreg_save
    reti

; delay by time proportional to contents of r16
delay:
    clr     r0
delay_loop:
    dec     r0
    brne    delay_loop
    dec     r16
    brne    delay
    ret

; overwrite the sample buffer with zeroes
clear_buffer:
    reset_buffer_ptr
    ldi     r17, 1
    ldi     r16, 0
write_loop:
    add     r16, r17
    st      X+, r16
    brne_16 write_loop, DATA_END
done_writing:
    reset_buffer_ptr
    ret

reset:
    ; setup the stack
    ldi     r16, low(RAMEND)
    out     SPL, r16

    ; setup pins for IO
    cbi     DDRB, PIN_IN
    sbi     DDRB, PIN_OUT
    cbi     DDRB, PIN_RECORD
    cbi     DDRB, PIN_TRIGGER
    sbi     DDRB, PIN_DONE

    ; setup ADC

    ; left adjusted
    ldi     r16, (1 << ADLAR) | (1 << MUX0)
    out     ADMUX, r16

    ; enable, start, run free, divide clock by 128
    ldi     r16, (1 << ADEN) | (1 << ADSC) | (1 << ADATE) | (7 << ADPS0)
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

    ; start at 0 volts
    ldi     r16, 255
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
    ldi     r16, 57;229
    out     OCR1C, r16

    ; setup application state

    ; initialize buffer
    rcall   clear_buffer

    ; enable interrupts
    sei

    rjmp    start

; MAIN PROGRAM

start_playback:
    sbrc    flags, RECORDING
    rjmp    blocked_by_recording

    reset_buffer_ptr
    sbr     flags, (1 << PLAYING)
    rjmp    wait_loop

start_recording:
    sbrc    flags, RECORDING
    rjmp    blocked_by_recording

    sbi     PINB, PIN_DONE
    rcall   clear_buffer

    sbr     flags, (1 << RECORDING)
    cbr     flags, (1 << PLAYING)
blocked_by_recording:
    rjmp    wait_loop

start:
wait_loop:
    ;sbic    PINB, PIN_RECORD
    ;rjmp    start_recording
    ;sbis    PINB, PIN_RECORD ; when record button not pressed
    ;cbr     flags, (1 << RECORDING) ; not recording

    ;sbic    PINB, PIN_TRIGGER
    ;rjmp    start_playback
    sbr     flags, (1 << PLAYING)

    rjmp    wait_loop

.include "lookup.asm"