.include "tn85def.inc"

; open questions
;  - after playback should it stay at the last value or zero?
;  - should the end of recording trigger a pulse on the "done" pin?

.define STACK_SIZE      12 ; bytes
.define DATA_END        (RAMEND-STACK_SIZE) ; end of buffer
.define SAMPLE_COUNT    (DATA_END-SRAM_START)
.define PTR_SAVE_H      510
.define PTR_SAVE_L      511

.define F_CPU           8000000
.define SAMPLE_TIME     30 ; seconds
.define SAMPLES_PER_SEC (SAMPLE_COUNT / SAMPLE_TIME)
.define SAMPLE_TOP      (F_CPU / 4096 / SAMPLES_PER_SEC)
.define DEBOUNCE_TICKS  0 ; sample ticks before firing input events

.define PIN_IN          PB2
.define PIN_OUT         PB0
.define PIN_RECORD      PB3
.define PIN_TRIGGER     PB1
.define PIN_DONE        PB4

; state flags
.define RECORDING           0
.define PLAYING             1
.define LAST_PIN_RECORD     2
.define LAST_PIN_TRIGGER    3
.define HANDLED_RECORD      4
.define HANDLED_TRIGGER     5

; event flags
.define RECORD_PRESSED      0
.define RECORD_RELEASED     1
.define TRIGGER_PRESSED     2
.define TRIGGER_RELEASED    3

; registers
.def eeprom_l           = r11
.def eeprom_h           = r12
.def done_pulse_timer   = r13
.def tick_counter       = r14
.def zero               = r15
.def press_record_time  = r18
.def press_trigger_time = r19
.def scrap              = r20
.def sreg_save          = r21
.def irq_scrap_a        = r22
.def irq_scrap_b        = r23
.def state_flags        = r24
.def event_flags        = r25 ; r25 is last available due to pointer regs

.macro reset_buffer_ptr
    ldi     XL, low(SRAM_START)
    ldi     XH, high(SRAM_START)
.endm

.macro brne_i_16
    cpi     @1, high(@3)
    brne    @0
    cpi     @2, low(@3)
    brne    @0
.endm

.macro brne_16
    cp      @1, @3
    brne    @0
    cp      @2, @4
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

    ; so we can keep track of time
    inc     tick_counter

    ; check pulse timer
    mov     irq_scrap_a, done_pulse_timer
    cpi     irq_scrap_a, 0
    breq    done_pulse_handling

    dec     done_pulse_timer
    brne    done_pulse_handling
end_pulse:
    cbi     PORTB, PIN_DONE
    cbi     DDRB, PIN_DONE ; leave hi-z

done_pulse_handling:

.include "debounce.asm"

    ; check if at end of buffer
    brne_i_16 timer_tick_sample, XH, XL, DATA_END

    ; at end of buffer
    ; so stop what we were doing
    clr     state_flags
    rjmp    timer_done

timer_tick_sample:
; if recording
    sbrs    state_flags, RECORDING
    rjmp    not_recording

    ; read adc
    in      irq_scrap_a, ADCH

    ; save adc reading at current buffer index
    ; and increment index
.include "eeprom-write.asm"
    st      X+, irq_scrap_a
    movw    YH:YL, XH:XL ; keep track of end of sample

not_recording:

; if playing back
    sbrs    state_flags, PLAYING
    rjmp    not_playing

    brne_16 play_sample, XH, XL, YH, YL

    ; at end of recorded sample
    ; so stop playing

    ; signal with done pin
    ldi     irq_scrap_a, DEBOUNCE_TICKS+1
    mov     done_pulse_timer, irq_scrap_a
    sbi     PORTB, PIN_DONE
    sbi     DDRB, PIN_DONE ; make output, normally hi-z

    ; mark not playing
    cbr     state_flags, (1 << PLAYING)

    rjmp    timer_done

play_sample:
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
    ldi     r16, 0
write_loop:
    st      X+, r16
    brne_i_16 write_loop, XH, XL, DATA_END
done_writing:
    reset_buffer_ptr
    ret

; restore the sample buffer from eeprom
restore_buffer:
    reset_buffer_ptr

    ; start at beginning of eeprom
    clr     ZH
    clr     ZL
restore_loop:
    ; wait for previous eeprom operation to finish
    sbic    EECR, EEPE
    rjmp    restore_loop

    ; set eeprom address
    out     EEARH, ZH
    out     EEARL, ZL

    ; start eeprom read by writing EERE
    ; read value from eeprom
    sbi     EECR, EERE ; trigger start
    in      r16, EEDR ; get data

    ; increment address
    adiw    r31:r30, 1

    st      X+, r16
    brne_i_16 restore_loop, XH, XL, DATA_END
restore_ptr_h:
    ; wait for previous eeprom operation to finish
    sbic    EECR, EEPE
    rjmp    restore_ptr_h

    ; set eeprom address
    ldi     r16, high(PTR_SAVE_H)
    out     EEARH, r16
    ldi     r16, low(PTR_SAVE_H)
    out     EEARL, r16

    ; start eeprom read by writing EERE
    ; read value from eeprom
    sbi     EECR, EERE ; trigger start
    in      YH, EEDR ; get data
restore_ptr_l:
    ; wait for previous eeprom operation to finish
    sbic    EECR, EEPE
    rjmp    restore_ptr_l

    ; set eeprom address
    ldi     r16, high(PTR_SAVE_L)
    out     EEARH, r16
    ldi     r16, low(PTR_SAVE_L)
    out     EEARL, r16

    ; start eeprom read by writing EERE
    ; read value from eeprom
    sbi     EECR, EERE ; trigger start
    in      YL, EEDR ; get data
done_restoring:
    ret

reset:
    ; setup the stack
    ldi     r16, low(RAMEND)
    out     SPL, r16

    ; setup pins for IO
    ldi     r16, (1 << PIN_OUT)
    out     DDRB, r16

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

    ; interrupt 500 times in RECORD_TIME seconds (with prescaler at 4096 and 8 MHz system clk)
    ; calculated by 8 MHz / 4096 / (SAMPLE_COUNT bytes / RECORD_TIME seconds)
    ldi     r16, SAMPLE_TOP
    out     OCR1C, r16

    ; setup application state

    ; initialize buffer
    rcall   restore_buffer

    ; enable interrupts
    sei

    rjmp    start

; MAIN PROGRAM

start_playback:
    sbrc    state_flags, RECORDING
    rjmp    blocked_by_recording

    ; go back to beginning of buffer
    reset_buffer_ptr

    sbr     state_flags, (1 << PLAYING)
blocked_by_recording:
    rjmp    wait_loop

start_recording:
    ; signal to stop playing
    cbr     state_flags, (1 << PLAYING)

    rcall   clear_buffer

    ; signal to start recording
    sbr     state_flags, (1 << RECORDING)

    rjmp    wait_loop

stop_recording:
    cbr     state_flags, (1 << RECORDING)
eeprom_write_ptr_h: ; save where we stopped recording in case of power loss
    ; wait for completion of previous write
    sbic    EECR, EEPE
    rjmp    eeprom_write_ptr_h

    ; set programming mode
    ldi     r16, (0 << EEPM1) | (0 << EEPM0)
    out     EECR, r16

    ; write address
    ldi     r16, high(PTR_SAVE_H)
    out     EEARH, r16
    ldi     r16, low(PTR_SAVE_H)
    out     EEARL, r16

    ; do EEPROM write
    out     EEDR, YH ; data to write
    sbi     EECR, EEMPE ; master program enable
    sbi     EECR, EEPE ; start write
eeprom_write_ptr_l:
    ; wait for completion of previous write
    sbic    EECR, EEPE
    rjmp    eeprom_write_ptr_l

    ; set programming mode
    ldi     r16, (0 << EEPM1) | (0 << EEPM0)
    out     EECR, r16

    ; write address
    ldi     r16, high(PTR_SAVE_L)
    out     EEARH, r16
    ldi     r16, low(PTR_SAVE_L)
    out     EEARL, r16

    ; do EEPROM write
    out     EEDR, YL ; data to write
    sbi     EECR, EEMPE ; master program enable
    sbi     EECR, EEPE ; start write

    rjmp    wait_loop

; input handlers

handle_record_pressed:
    cbr     event_flags, (1 << RECORD_PRESSED)
    rjmp    start_recording

handle_record_released: ; works fine
    cbr     event_flags, (1 << RECORD_RELEASED)
    rjmp    stop_recording

handle_trigger_pressed:
    cbr     event_flags, (1 << TRIGGER_PRESSED)
    rjmp    start_playback

start:
wait_loop:
    sbrc    event_flags, RECORD_PRESSED
    rjmp    handle_record_pressed

    sbrc    event_flags, RECORD_RELEASED
    rjmp    handle_record_released

    sbrc    event_flags, TRIGGER_PRESSED
    rjmp    handle_trigger_pressed

    rjmp    wait_loop

.include "lookup.asm"