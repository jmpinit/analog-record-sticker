eeprom_write:
    ; wait for completion of previous write
    sbic EECR, EEPE
    rjmp eeprom_write

    ; set programming mode
    ldi irq_scrap_b, (0 << EEPM1) | (0 << EEPM0)
    out EECR, irq_scrap_b

    ; temporarily save pointer into buffer
    mov     eeprom_h, XH
    mov     eeprom_l, XL

    ; remove offset to make EEPROM address
    ldi     ZH, high(SRAM_START)
    ldi     ZL, low(SRAM_START)
    sub     XL, ZL
    sbc     XH, ZH

    ; write address
    out EEARH, XH
    out EEARL, XL

    ; restore old address
    mov     XH, eeprom_h
    mov     XL, eeprom_l

    ; do EEPROM write
    out EEDR, irq_scrap_a ; data to write is adc value
    sbi EECR, EEMPE ; master program enable
    sbi EECR, EEPE ; start write