analog-sticker.bin: analog-sticker.hex
	avr-objcopy -I ihex -O binary analog-sticker.hex analog-sticker.bin

analog-sticker.elf: analog-sticker.bin
	avr-objcopy -I binary -O elf32-avr analog-sticker.bin analog-sticker.elf

analog-sticker.hex: analog-sticker.asm
	avra analog-sticker.asm

flash: analog-sticker.hex
	avrdude -c usbtiny -p attiny85 -U flash:w:$<

clean:
	rm *.hex *.cof *.obj

.PHONY: clean flash
