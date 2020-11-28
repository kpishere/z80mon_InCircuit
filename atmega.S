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
.extern uart_tx

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
PWM_timer:
  ; 
  ldi r16, 0x00       ; Clear timer config
  ldi r17, 7          ; toggle after counting to 8
  mov r18, r16  
  ori r18, ((1<<COM1A0))            ; Toggle OC1A on Compare Match.
  mov r19, r16  
  ori r19, ((1<<WGM12)|(1<<CS10)) ; CTC mode | clock on, no pre-scaler  
  sts _SFR_IO_ADDR(TCCR1A), r16 ; clear
  sts _SFR_IO_ADDR(TCCR1A), r18 ; set new value
  sts _SFR_IO_ADDR(TCCR1B), r16 ; clear
  sts _SFR_IO_ADDR(TCCR1B), r19 ; set new value
  sts _SFR_IO_ADDR(TCNT1), r16  ; clear
  sts _SFR_IO_ADDR(OCR1AH), r16  ; Set output compare value
  sts _SFR_IO_ADDR(OCR1AL), r17  ; 
  ;
  ; Update port or output
  sbi _SFR_IO_ADDR(DDRB), DDB5  ; Pin 11 on atmel2560
  ;
  ret         ; return to calling program

// Watch **very closely** for /MREQ or /IOREQ to go low, set wait state, return
// Response time here is 300 to 600 e-9 seconds -- ideally under 375 e-9 seconds.
watchBus:
  ldi r16, 0x00 ; data sample
  ldi r17, 0x00 ; ddr input
  ldi r18, 0xff ; ddr output
  ldi r19, MASK_MREQ_IOREQ  ; test condition
  ldi r20, 0x03 ; no MREQ or IOREQ
  ldi Xh,hi8(eprom) ; base of rom
  ldi Xl,lo8(eprom) ; base of rom
watchBus_loop:
  in r21, PINB        ; source for MASK_MREQ_IOREQ  
  sbrs r21, IORQ_PIN ; skip next instruction of bit is high
  rjmp watchBus_io    ; is IOREQ
  sbrc r21, MREQ_PIN  ; skip out of loop if MREQ is low
  rjmp watchBus_loop  ; bit is high, stay in loop
  cbi PORTG, WAIT_PIN ; Set /WAIT LOW immediately  
  in r21, PING        ; souce for WR/RD
  sbrc r21,RD_PIN    ; If RD pin low, skip next jump and do mem read
  rjmp watchBus_memwrite
  ; set data output for read request  
  in Zh,PINC   ; get Addr
  in Zl,PINA   ; get Addr  
  add Zl,Xl    ; add rom base addr
  adc Zh,Xh  
  lpm r16, Z   ; get eprom memory in register
  ;
  ; call uart_tx  ; debug - byte read is in r16
  ;
  ; Set Z pointer for output register
  ldi Zh,(DBUSPINL>>8)  ; port addr
  ldi Zl,(DBUSPINL&0xFF); port addr
  ;
  std Z+2,r16  ; PORTL Set data bus value  
  sts _SFR_IO_ADDR(DDRL), r18 ; assert data line
  ;
  ; fall thru as nonthing done with memwrite
watchBus_memwrite:  
  ;
  ; write to memory not supported
  ; 
  sbi PORTG, WAIT_PIN ; Set /WAIT HI
  ; Wait until MREQ or IORQ ends
watchBus_MREQ_done:
  in r21, PINB        ; source for MASK_MREQ_IOREQ  
  sbrs r21, MREQ_PIN  ; skip out of loop if MREQ is high
  rjmp watchBus_MREQ_done  ; bit is low, stay in loop  
  rjmp watchBus_end
watchBus_io:
  cbi PORTG, WAIT_PIN ; Set /WAIT LOW immediately  
  ;
  ; TODO -- stuff like read/write serial port 
  ;
  sbi PORTG, WAIT_PIN ; Set /WAIT HI
  ; Wait until IORQ ends
watchBus_IORQ_done:
  in r21, PINB        ; source for MASK_MREQ_IOREQ  
  sbrs r21, IORQ_PIN ; skip next instruction of bit is high
  rjmp watchBus_IORQ_done 
  ; fall thru to end  
watchBus_end:
  sts _SFR_IO_ADDR(DDRL), r17 ; set high impedence data lines, read is done
  ;
  ; debug show end where data lines are released 
  ;cbi   PORTD, PIND1
  ;sbi   PORTD, PIND1
  ;
  ret

// Contents of memory
eprom:  .byte 0x21,0x0a,0x00,0x76
