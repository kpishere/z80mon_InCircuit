# z80mon_InCircuit
Use an Arduino Mega 2560 to replace the EEPROM in your Z80 device

Why would you do this? Well, you'd then be able to : 

- Update your Z80 device as easily as you update the program in an Arduino device
- Emulate a Z80 serial IO device from the EEPROM socket (with some extra jumper wires to the CPU)
- If you have space in your EEPROM, add a MON program in the code and step through and inspect memory as your program runs in your target device

Progress updates : 

- Initial timing tests look like this may only work for 2Mhz or slower Z80 clock CPUs.  I'll be continuing to test with a 4Mhz clock just to 'see what happens' but expect I'll have to replace the crystal shortly.
