; Helper routines for simulating EPROM on Z80 system

; Special Function Register for AVR, for better backward compatibility as
; used by avr-libc's register definitions (default value is 0x20)
#define __SFR_OFFSET 0x00

; If we use Arduino-style references (eg PORTB, DDRB etc) include this library
#include "avr/io.h"

//Eprom-IO-Control Lines Port G (In)
#define WR_PIN PING0 
#define RD_PIN PING1
//Eprom-IO-Control Lines Port G (Out)
#define WAIT_PIN PING2

//IO-Control Lines Port D (Out)
#define RST_PIN PIND7 

//Control Lines PortB (In)
#define MREQ_PIN PINB0
#define IORQ_PIN PINB1
#define MASK_MREQ_IOREQ ((1<<IORQ_PIN)|(1<<MREQ_PIN))

#define DBUSPINL 0x109

// Make them accessible from the Arduino sketch so we can call them
.global initPorts
.global watchBus


// A bit like setup()
initPorts:
  ; set high impedance
  ldi r16, 0x00
  mov _SFR_IO_ADDR(DDRA), r16  ; ADDR LO
  mov _SFR_IO_ADDR(DDRC), r16  ; ADDR HI
  sts _SFR_IO_ADDR(DDRL), r16  ; DATA 
  cbi DDRG, WR_PIN
  cbi DDRG, RD_PIN
  sbi DDRG, WAIT_PIN
  sbi DDRD, RST_PIN
  cbi DDRB, MREQ_PIN
  cbi DDRB, IORQ_PIN   
  ; set output hi
  sbi PORTG, WAIT_PIN
  sbi PORTD, RST_PIN
WDT_off:
  in r17, SREG     ; save state of registers
  ; Turn off global interrupt
  cli
  ; Reset Watchdog Timer
  wdr
  ; Clear WDRF in MCUSR
  in r16, MCUSR
  andi r16, (0xff & (0<<WDRF))
  out MCUSR, r16
  ; Write logical one to WDCE and WDE
  ; Keep old prescaler setting to prevent unintentional time-out ldi r16, WDTCSR
  ori r16, (1<<WDCE) | (1<<WDE)
  sts WDTCSR, r16
  ; Turn off WDT
  ldi r16, (0<<WDE)
  sts WDTCSR, r16
  out SREG, r17   ; restore state, including interrupt if it was enabled

  cli               ; Disable interrupts -- want maximum response when watching following pins

  ret         ; return to calling program

// Watch **very closely** for /MREQ or /IOREQ to go low, set wait state, return
// Response time here is 300 to 600 e-9 seconds -- ideally under 375 e-9 seconds.
watchBus:
  ldi r16, 0x00 ; data sample
  ldi r17, 0x00 ; ddr input
  ldi r18, 0xff ; ddr output
  ldi r19, MASK_MREQ_IOREQ  ; test condition
  ldi Zh,(DBUSPINL>>8)  ; port addr
  ldi Zl,(DBUSPINL&0xFF); port addr
  ldi Xh,hi8(eprom) ; base of rom
  ldi Xl,lo8(eprom) ; base of rom
watchBus_loop:
  in r21, PINB ; source for MASK_MREQ_IOREQ  
  and r21, r19
  sub r21, r19
  breq watchBus_loop  ; loop until IORQ or MREQ low
  // Is memory read request
  cbi PORTG, WAIT_PIN        ; Set /WAIT LOW immediately
  /*
  in Yh,PINC             ; get Addr
  in Yl,PINA             ; get Addr
  add Yl,Xl ; add rom base addr
  adc Yh,Xh
  ld r16, Y
  std Z+2,r16 ; PORTL Set data bus value
  std Z+1,r18 ; DDRL Assert data bus  
  std Z+1,r17 ; release data baus
  */
  sbi PORTG, WAIT_PIN        ; Set /WAIT HI immediately
  ret

.data
// Contents of memory
eprom:  .byte 0x21
        .byte 0x0a
        .byte 0x00
        .byte 0x76
