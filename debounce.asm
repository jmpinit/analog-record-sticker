; calls button change handlers after a level change
; and a set period of time has elapsed without further change

; defined in main file
;.def press_record_time  = r24
;.def press_trigger_time    = r25

; TODO DRY the duplication with macros

; needs to end up in the timer ISR (include this file there)
debounce:
    in      irq_scrap_a, PINB
check_pin_record:
    sbrs    irq_scrap_a, PIN_RECORD
    rjmp    record_pin_is_low
record_pin_is_high:
    sbrs    state_flags, LAST_PIN_RECORD
    rjmp    edge_detect_end_record ; pin was low, edge detected
    rjmp    record_pin_same ; pin was high, no edge
record_pin_is_low:
    sbrs    state_flags, LAST_PIN_RECORD
    rjmp    record_pin_same ; pin was low, no edge
    ; rjmp    pin_changed (unnecessary b/c can fall through)
edge_detect_end_record:

    ; record pin changed

    ; remember the time
    mov     press_record_time, tick_counter

    ; save current state as previous state for next
    sbrs    irq_scrap_a, PIN_RECORD
    cbr     state_flags, (1 << LAST_PIN_RECORD)
    sbrc    irq_scrap_a, PIN_RECORD
    sbr     state_flags, (1 << LAST_PIN_RECORD)

    ; mark unhandled
    cbr     state_flags, (1 << HANDLED_RECORD)
record_pin_same:
handle_record_pin:
    sbrc    state_flags, HANDLED_RECORD
    rjmp    ignore_record_pin

    ; record pin change unhandled
    ; so check time elapsed since change
    mov     irq_scrap_b, tick_counter
    sub     irq_scrap_b, press_record_time

    ; run handler if elapsed time is greater than debounce time
    cpi     irq_scrap_b, DEBOUNCE_TICKS
    brlo    ignore_record_pin

    ; handle record pin change

    ; if record button pressed (assumes PINB was stored in irq_scrap_a above)
    sbrs    irq_scrap_a, PIN_RECORD
    sbr     event_flags, (1 << RECORD_RELEASED)
    sbrc    irq_scrap_a, PIN_RECORD
    sbr     event_flags, (1 << RECORD_PRESSED)

    ; mark as handled
    sbr     state_flags, (1 << HANDLED_RECORD)
ignore_record_pin:

check_pin_trigger:
    sbrs    irq_scrap_a, PIN_TRIGGER
    rjmp    trigger_pin_is_low
trigger_pin_is_high:
    sbrs    state_flags, LAST_PIN_TRIGGER
    rjmp    edge_detect_end_trigger
    rjmp    trigger_pin_same
trigger_pin_is_low:
    sbrs    state_flags, LAST_PIN_TRIGGER
    rjmp    trigger_pin_same
    ; rjmp    pin_changed (unnecessary b/c can fall through)
edge_detect_end_trigger:

    ; trigger pin changed

    ; remember the time
    mov     press_trigger_time, tick_counter

    ; save current state as previous state for next
    sbrs    irq_scrap_a, PIN_TRIGGER
    cbr     state_flags, (1 << LAST_PIN_TRIGGER)
    sbrc    irq_scrap_a, PIN_TRIGGER
    sbr     state_flags, (1 << LAST_PIN_TRIGGER)

    ; mark unhandled
    cbr     state_flags, (1 << HANDLED_TRIGGER)
trigger_pin_same:
handle_trigger_pin:
    sbrc    state_flags, HANDLED_TRIGGER
    rjmp    ignore_trigger_pin

    ; trigger pin change unhandled
    ; so check time elapsed since change
    mov     irq_scrap_b, tick_counter
    sub     irq_scrap_b, press_trigger_time

    ; run handler if elapsed time is greater than debounce time
    cpi     irq_scrap_b, DEBOUNCE_TICKS
    brlo    ignore_trigger_pin

    ; handle trigger pin change

    ; if trigger button pressed
    sbrs    irq_scrap_a, PIN_TRIGGER
    sbr     event_flags, (1 << TRIGGER_RELEASED)
    sbrc    irq_scrap_a, PIN_TRIGGER
    sbr     event_flags, (1 << TRIGGER_PRESSED)

    ; mark as handled
    sbr     state_flags, (1 << HANDLED_TRIGGER)

ignore_trigger_pin:
