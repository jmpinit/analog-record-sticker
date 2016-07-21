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