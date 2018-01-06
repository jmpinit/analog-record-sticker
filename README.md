# Analog Record Sticker

A [circuit sticker](https://chibitronics.com/) which can record an analog signal and then play it back. Runs on the awesome microcontroller sticker from Chibitronics.

**Features:**

* Looping
* Persistently remember pattern (in EEPROM)

## Hardware

* Pattern is recorded on PB2
* Pattern is played back on PB0
* While PB3 is high a pattern is recorded
* A pulse on PB1 will trigger playback
* PB4 pulses when playback finishes so if it is connected to PB1 then playback will loop

An RC low-pass filter is connected to PB0 to create a smooth analog signal.

* 390 Ohm resistor
* 10uF capacitor
