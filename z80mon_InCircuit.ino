#include "src/eprom.h"

/*
Target: Arduino Mega 2560
==================================================
Wiring:
Address Lines (In):
Arduino PA0-7 Pin 22..29   <--->   Z80 A0..A7 Eprom Pins 10-3
Arduino PC0-5 Pin 37..28   <--->   Z80 A8..A13 Eprom Pins 25,24,21,23,2,26 
*Arduino PC6-7 Pin 29..30   <--->   Z80 A14..A15 CPU Pins 4,5 

Eprom/IO/Control lines (In):
*Arduino PG0 Pin 41 <---> Z80 /WR CPU Pin 22
Arduino PG1 Pin 40 <---> Z80 /RD CPU Pin 21 -OR- /OE Eprom Pin 22 (Confirm on your target system these are the same) 
Eprom/IO/Control lines (Out):
Arduino PG2 Pin 39 <---> Z80 /WAIT CPU Pin 24 

IO/Control lines (Out):
Arduino PD7 Pin 38 <---> Z80 /RESET CPU PIN 26

Control lines (In):
Arduino PB0 Pin 53 <---> Z80 /MREQ CPU Pin 19 -OR- /CE Eprom Pin 20 
Arduino PB1 Pin 52 <---> Z80 /IORQ CPU Pin 20

Data Lines (In/Out):
Arduino PL0-7 Pin 49..42   <--->   Z80 D0..D7 Eprom Pins 11-13,15-19

==================================================
* - If A14,A15 are NOT connected, Eprom /CE must be connected 
  - If A14,A15 ARE connected, CPU /MREQ must be connected 
    and address mapping BY SOFTWARE required
*/

// TODO: Support Arduino hosted RAM
//Working memory
//uint8_t memory[1024 * 4]; // use 4k block for off-target system ram

typedef enum IODevice:byte { SC16C550B = 0 } IODeviceType;
uint16_t addrReq = 0x00;

// From/To memory or I/O Locations
uint16_t eprom_loc[] = {0x0000, 0x3fff};
uint16_t io_loc[] = {0x0020,0x0007};
#define LOC_FIRST(x) (x*2)
#define LOC_SIZE(x) (x*2+1)

// IO Devices supported
IODeviceType io_type[] = { IODevice::SC16C550B };

// registers for this IO device
byte io_SC16C550B[] = {0,0,0,0 ,0,0,0,0};

extern "C" {
  void initPorts();
  void watchBus();
  void uart_init();
}

// the setup function runs once when you press reset or power the board
void setup() {
  initPorts();
  uart_init();
}

// the loop is empty, because this is interrupt-driven
void loop() {
  watchBus();
}
