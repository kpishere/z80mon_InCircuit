#define __SFR_OFFSET 0x00
#include "avr/io.h"

#define PORT_TX PORTD
#define DDR_TX DDRD
#define PIN_TX PIND1

; 115200 baud with a 16 MHz clock (8.681e-6 seconds per bit required)
#define UART_WAIT 44

; Registers used:  
; r16 - byte to output
; r17 - delay count

.global uart_init
.global uart_tx

.macro  bitSendR l r
  lsr   \r 
  brcc  uart_tx_send_0_\l
uart_tx_send_1_\l: 
  sbi   PORT_TX, PIN_TX 
  rjmp  uart_tx_finish_\l
uart_tx_send_0_\l: 
  cbi   PORT_TX, PIN_TX 
  nop 
  nop
uart_tx_finish_\l: 
  ldi   r17, UART_WAIT 
uart_delay_\l: 
  dec   r17 
  brne  uart_delay_\l
.endm


.macro  bitSendL l r
  lsl   \r
  brcc  Luart_tx_send_0_\l
Luart_tx_send_1_\l: 
  sbi   PORT_TX, PIN_TX 
  rjmp  Luart_tx_finish_\l
Luart_tx_send_0_\l: 
  cbi   PORT_TX, PIN_TX 
  nop 
  nop
Luart_tx_finish_\l: 
  ldi   r17, UART_WAIT 
Luart_delay_\l: 
  dec   r17 
  brne  Luart_delay_\l
.endm

uart_init:
  ; Make TX pin output & set it high
  sbi DDR_TX,PIN_TX
  sbi PORT_TX, PIN_TX
  ret

uart_tx:
  push r16
  push r17
  
  ; Send start bit
  cbi   PORT_TX, PIN_TX
  ldi   r17, UART_WAIT
uart_delay_s:
  dec   r17
  brne  uart_delay_s

  bitSendR 0 r16
  bitSendR 1 r16
  bitSendR 2 r16
  bitSendR 3 r16
  bitSendR 4 r16
  bitSendR 5 r16
  bitSendR 6 r16
  bitSendR 7 r16

  ; Stop bit
  sbi   PORT_TX, PIN_TX
  ldi   r17, UART_WAIT
uart_delay_t:
  dec   r17
  brne  uart_delay_t

  ; Return state
  clc
  pop r17
  pop r16
  ret
