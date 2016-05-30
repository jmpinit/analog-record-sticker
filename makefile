analog-sticker.hex: analog-sticker.asm
	avra analog-sticker.asm

flash: analog-sticker.hex
	avrdude -c usbtiny -p attiny85 -U flash:w:$<

clean:
	rm *.hex *.cof *.obj

.PHONY: clean flash