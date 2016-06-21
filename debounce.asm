; calls button change handlers after a level change
; and a set period of time has elapsed without further change

; defined in main file
;.def press_record_time  = r24
;.def press_trigger_time    = r25

; input register left containing 1 if edge detected and 0 otherwise
.macro edge_detect ; edge_handler, pin index, last state flag index
check_pin_%:
    sbis    PINB, @1
    rjmp    pin_is_low_%
pin_is_high_%:
    sbrs    state_flags, @2
    rjmp    edge_detect_end_%
    rjmp    @0
pin_is_low_%:
    sbrs    state_flags, @2
    rjmp    @0
    ; rjmp    pin_changed (unnecessary)
edge_detect_end_%:
.endm

; needs to end up in the timer ISR (include this file there)
debounce:
    ;edge_detect record_pin_same, PIN_RECORD, LAST_PIN_RECORD
    check_pin_record:
    sbis    PINB, PIN_RECORD
    rjmp    pin_is_low_record
pin_is_high_record:
    sbrs    state_flags, LAST_PIN_RECORD
    rjmp    edge_detect_end_record
    rjmp    record_pin_same
pin_is_low_record:
    sbrs    state_flags, LAST_PIN_RECORD
    rjmp    record_pin_same
    ; rjmp    pin_changed (unnecessary b/c can fall through)
edge_detect_end_record:

    ; record pin changed

    ; remember the time
    in      press_record_time, OCR0A

    ; mark unhandled
    cbr     state_flags, (1 << HANDLED_RECORD)

record_pin_same:
    ;edge_detect trigger_pin_changed, PIN_RECORD, LAST_PIN_RECORD
    check_pin_trigger:
    sbis    PINB, PIN_RECORD
    rjmp    pin_is_low_trigger
pin_is_high_trigger:
    sbrs    state_flags, LAST_PIN_RECORD
    rjmp    edge_detect_end_trigger
    rjmp    trigger_pin_same
pin_is_low_trigger:
    sbrs    state_flags, LAST_PIN_RECORD
    rjmp    trigger_pin_same
    ; rjmp    pin_changed (unnecessary b/c can fall through)
edge_detect_end_trigger:

    ; trigger in changed

    ; remember the time
    in      press_trigger_time, OCR0A

    ; mark unhandled
    cbr     state_flags, (1 << HANDLED_TRIGGER)

trigger_pin_same:
check_record_pin:
    sbrc    state_flags, HANDLED_RECORD
    rjmp    check_trigger_pin

    ; record pin change unhandled
    ; so check time elapsed since change
    mov     irq_scrap_a, tick_counter
    sub     irq_scrap_a, press_record_time

    ; run handler if elapsed time is greater than debounce time
    cpi     irq_scrap_a, DEBOUNCE_TICKS
    brlo    ignore_record_pin

    ; handle record pin change

    ; if record button pressed
    in      irq_scrap_a, PINB
    sbrs    irq_scrap_a, PIN_RECORD
    sbr     event_flags, (1 << RECORD_RELEASED)
    sbrc    irq_scrap_a, PIN_RECORD
    sbr     event_flags, (1 << RECORD_PRESSED)

ignore_record_pin:
check_trigger_pin:
    sbrc    state_flags, HANDLED_TRIGGER
    rjmp    debounce_done

    ; trigger pin change unhandled
    ; so check time elapsed since change
    mov     irq_scrap_a, tick_counter
    sub     irq_scrap_a, press_trigger_time

    ; run handler if elapsed time is greater than debounce time
    cpi     irq_scrap_a, DEBOUNCE_TICKS
    brlo    debounce_done

    ; handle trigger pin change

    ; if trigger button pressed
    in      irq_scrap_a, PINB
    sbrs    irq_scrap_a, PIN_TRIGGER
    sbr     event_flags, (1 << TRIGGER_RELEASED)
    sbrc    irq_scrap_a, PIN_TRIGGER
    sbr     event_flags, (1 << TRIGGER_PRESSED)

debounce_done:
    