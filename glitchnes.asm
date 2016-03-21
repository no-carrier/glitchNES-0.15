;       ----------------------------------------------------

;    glitchNES - version 0.15
;    Copyright 2016 Don Miller
;    For more information, visit: http://www.no-carrier.com

;    This program is free software: you can redistribute it and/or modify
;    it under the terms of the GNU General Public License as published by
;    the Free Software Foundation, either version 3 of the License, or
;    (at your option) any later version.

;    This program is distributed in the hope that it will be useful,
;    but WITHOUT ANY WARRANTY; without even the implied warranty of
;    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;    GNU General Public License for more details.

;    You should have received a copy of the GNU General Public License
;    along with this program.  If not, see <http://www.gnu.org/licenses/>.

;       ----------------------------------------------------

tilenum = $c2
scroll_h = $c3
scroll_v = $c4
PPU_ADDR = $c5
delay = $d0
write_toggle = $d2

NewButtons = $41
OldButtons = $42
JustPressed = $43
NewButtons2 = $46
OldButtons2 = $47
JustPressed2 = $48

up = $49
down = $50
left = $51
right = $52

PaletteNumber = $54
flash = $57

tapThreshold = $e0
tapCounter = $e1
tapEnabled = $e2
toggleEffect = $e3
pause = $e4

bgTable = $e5
screenRedraw = $e6

;       ---------------------------------------------------- NES header

        .ORG $7ff0
Header:                         ;16 byte .NES header (iNES)
	.db "NES", $1a		;NES followed by MS-DOS end-of-file
	.db $02			;size of PRG ROM in 16kb units
	.db $01                 ;size of CHR ROM in 8kb units
	.db #%00000000		;flags 6, set to: mapper 0, HORZ mirroring
	.db #%00000000		;flags 7, set to: mapper 0
        .db $00                 ;size of PRG RAM in 8kb RAM
        .db $00                 ;flags 9 -- SET to 0 for NTSC
        .db $00                 ;flags 10, set to 0
        .db $00                 ;11 - the rest are zeroed out
        .db $00                 ;12
        .db $00                 ;13
        .db $00                 ;14
        .db $00                 ;15

;       ---------------------------------------------------- reset routine

Reset:
        SEI
        CLD
	LDX #$00
	STX $2000
	STX $2001
	DEX
	TXS
  	LDX #0
  	TXA
ClearMemory:
	STA 0, X
	STA $100, X
	STA $200, X
	STA $300, X
	STA $400, X
	STA $500, X
	STA $600, X
	STA $700, X
        STA $800, X
        STA $900, X
        INX
	BNE ClearMemory

;       ---------------------------------------------------- setting up variables

SET_VARI:

        lda #$00
        sta scroll_h
        sta scroll_v
        sta PPU_ADDR+1
        STA PaletteNumber
        sta up
        sta down
        sta left
        sta right
        sta toggleEffect
        sta write_toggle
        sta flash
        sta pause
        sta screenRedraw

        lda #$20
        sta PPU_ADDR+0

        lda #4
        sta delay

        lda #1
        sta bgTable

;       ---------------------------------------------------- warm up

	LDX #$02
WarmUp:
	bit $2002
	bpl WarmUp
	dex
	BNE WarmUp

       	LDA #$3F
	STA $2006
	LDA #$00
	STA $2006
load_pal:                       ; load palette
        LDA palette,x
        sta $2007
        inx
        cpx #$20
        bne load_pal

	LDA #$20
	STA $2006
	LDA #$00
	STA $2006

	ldy #$04                ; clear nametables
ClearName:
	LDX #$00
	LDA #$3B
PPULoop:
	STA $2007
	DEX
	BNE PPULoop

	DEY
	BNE ClearName

;       ----------------------------------------------------

        LDA #<pic0              ; load low byte of first picture
        STA $10

        LDA #>pic0              ; load high byte of first picture
        STA $11

;       ---------------------------------------------------- write the welcome message

        lda #$20
        sta $2006
        lda #$80
        sta $2006
        ldx #$00
WriteWelcome:
        clc
        lda WelcomeText,x
        cmp #$0d
        beq DoneWelcome
        sta $2007
        INX
        JMP WriteWelcome
DoneWelcome:

;       ---------------------------------------------------- turn on screen

        JSR Vblank

;       ---------------------------------------------------- loop forever

InfLoop:

        inc tilenum

CheckPause:
        lda pause
        beq CheckWrite
        JMP InfLoop
CheckWrite:
        lda toggleEffect
        beq CheckWrite2
        jsr writer
CheckWrite2:
        lda write_toggle
        beq CheckUpTog
        jsr writer
CheckUpTog:
        lda up
        beq CheckDownTog
        inc scroll_v
CheckDownTog:
        lda down
        beq CheckLeftTog
        dec scroll_v
CheckLeftTog:
        lda left
        beq CheckRightTog
        dec scroll_h
CheckRightTog:
        lda right
        beq CheckFlash
        inc scroll_h
CheckFlash:
        lda flash
        beq CheckOver
        lda #$3f
        sta $2006
        lda #$00
        sta $2006
        ldx #0
        lda <32
FlashLoop:
        sta $2007
        inx
        inx
        inx
        inx
        cpx #32
        bne FlashLoop
        inc <32

CheckOver:

        jsr delay_loop

        JMP InfLoop

;       ---------------------------------------------------- magic delay loop

delay_loop:                     ; First delay subroutine
       ldx delay
LOOP1:
       NOP
       LDY #13                  ; Second delay parameter
LOOP2:
       NOP
       DEY
       BNE LOOP2

       DEX
       BNE LOOP1
       RTS

;       ---------------------------------------------------- palette loading routine

LoadNewPalette:
       	LDX PaletteNumber       ; load palette lookup value
        LDY #$00
        LDA #$3F
	STA $2006
	LDA #$00
	STA $2006
LoadNewPal:                     ; load palette
        LDA palette, x
        STA $2007
        INX
        INY
        CPY #$10
        BNE LoadNewPal
        RTS

;       ---------------------------------------------------- draw screen(s)

DrawScreen:

   	LDA #$20                ; set to beginning of first nametable
    	STA $2006
    	LDA #$00
    	STA $2006

        LDY #$00
        LDX #$04

NameLoop:                       ; loop to draw entire nametable
        LDA ($10),y
        STA $2007
        INY
        BNE NameLoop
        INC $11
        DEX
        BNE NameLoop

        RTS

;       ----------------------------------------------------

DrawScreen2:

   	LDA #$28                ; set to beginning of first nametable
    	STA $2006
    	LDA #$00
    	STA $2006

        LDY #$00
        LDX #$04

NameLoop2:                       ; loop to draw entire nametable
        LDA ($10),y
        STA $2007
        INY
        BNE NameLoop2
        INC $11
        DEX
        BNE NameLoop2

        RTS

;       ---------------------------------------------------- screen on: start the party

Vblank:
	bit $2002
	bpl Vblank

        ldx scroll_h
        stx $2005
        ldx scroll_v
        stx $2005

        lda bgTable             ; change CHR bank
        beq drawOneTable

       	LDA #%10001000          ; if 0, select first bg table
	STA $2000
	jmp restOfVblank

drawOneTable:                  ; if 1, select second bg table
        LDA #%10011000
	STA $2000

restOfVblank:
	;LDA #%10001000
	;STA $2000
        LDA #%00001110
	STA $2001

        RTS

;       ---------------------------------------------------- load new screen

LoadScreen:

        LDA #<pic0              ; load low byte of picture
        STA $10
        LDA #>pic0              ; load high byte of picture
        STA $11
        LDA #$00
        STA PaletteNumber       ; set palette lookup location
        RTS

;       ---------------------------------------------------- check for input

controller_test:

        LDA NewButtons
	STA OldButtons

        LDA NewButtons2
	STA OldButtons2

	LDA #$01		; strobe joypad
	STA $4016
	LDA #$00
	STA $4016

        LDX #$00
ConLoop:
	LDA $4016		; check the state of each button
	LSR
	ROR NewButtons
        INX
        CPX #$08
        bne ConLoop

        LDX #$00
ConLoop2:
	LDA $4017		; check the state of each button
	LSR
	ROR NewButtons2
        INX
        CPX #$08
        bne ConLoop2

	LDA OldButtons          ; invert bits
	EOR #$FF
	AND NewButtons
	STA JustPressed

        LDA OldButtons2          ; invert bits
	EOR #$FF
	AND NewButtons2
	STA JustPressed2

CheckSelect:
	LDA #%00000100
	AND JustPressed
	BEQ CheckStart

        lda write_toggle        ; toggle tile writing routine
        eor #$01
        sta write_toggle

CheckStart:
	LDA #%00001000
	AND JustPressed
	BEQ CheckLeft

        lda bgTable             ; change CHR bank
        bne oneTable

       	LDA #%10001000          ; if 0, select first bg table
	STA $2000
	lda #1
	sta bgTable
	jmp CheckLeft

oneTable:                       ; if 1, select second bg table
        LDA #%10011000
	STA $2000
	lda #0
	sta bgTable

CheckLeft:
	LDA #%01000000
	AND JustPressed
	BEQ CheckRight

	lda left                ; toggles LEFT movement, turns off RIGHT
	eor #$01
	sta left
	lda #$00
	sta right

CheckRight:
	LDA #%10000000
	AND JustPressed
	BEQ CheckDown

	lda right               ; toggles RIGHT movement, turns off LEFT
	eor #$01
	sta right
	lda #$00
	sta left

CheckDown:
	LDA #%00100000
	AND JustPressed
	BEQ CheckUp

	lda down                ; toggles DOWN movement, turns off UP
	eor #$01
	sta down
	lda #$00
	sta up

CheckUp:
	LDA #%00010000
	AND JustPressed
	BEQ CheckB

	lda up                  ; toggles UP movement, turns off DOWN
	eor #$01
	sta up
	lda #$00
	sta down

CheckB:
	LDA #%00000010
	AND JustPressed
	BEQ CheckA

	dec delay               ; slows down things, kind of...
	lda delay
	cmp #255
	bne CheckA
	lda #0
	sta delay

CheckA:
	LDA #%00000001
	AND JustPressed
	BEQ CheckSelect2

        inc delay               ; speeds things up, pretty much...

;       ---------------------------------------------------- controller #2

CheckSelect2:
	LDA #%00000100
	AND JustPressed2
	BEQ CheckStart2

        lda flash               ; toggles flashing background color #0
        eor #$01
        sta flash

CheckStart2:
	LDA #%00001000
	AND NewButtons2         ; notice this is NewButtons2
        BEQ NoPause

        lda #1                  ; if start is held, pause everything
        sta pause
        jmp CheckLeft2

NoPause:
        lda #0
        sta pause

CheckLeft2:
	LDA #%01000000
	AND JustPressed2
	BEQ CheckRight2

        ; DO SOMETHING HERE

CheckRight2:
	LDA #%10000000
	AND JustPressed2
	BEQ CheckDown2

        ; DO SOMETHING HERE, TOO

CheckDown2:
	LDA #%00100000          ; changes the screen / NAM & CHR bank
	AND JustPressed2
	BEQ CheckUp2

	; DO SOMETHING HERE, TOO

CheckUp2:
	LDA #%00010000
	AND JustPressed2
	BEQ CheckB2

	lda #1                 ; redraw screen
	sta screenRedraw

;       ---------------------------------------------------- tap tempo

CheckB2:
	LDA #%00000010          ; tap tempo feature by Batsly Adams - hell, yeah!
        AND OldButtons2
	BNE JHigh

JLow:
        LDA #%00000010
        AND NewButtons2
        BEQ ButtonIdle          ; J/C = 0/0 -> The button is idle
        JMP ButtonHit           ; J/C = 0/1 -> The button is newly hit

JHigh:
        LDA #%00000010
        AND NewButtons2
        BEQ ButtonReleased      ; J/C = 1/0 -> The button was just released
        JMP ButtonHeld          ; J/C = 1/1 -> The button is being held

ButtonIdle:                     ; Do nothing
        JMP CheckA2

ButtonHit:

        lda #0
        sta write_toggle        ; turn off writing routine if its toggled on

        LDA #$00
        STA tapThreshold        ; Reset the threshold
        STA tapCounter          ; Reset the counter
        STA tapEnabled          ; Disable the effect in infloop for now to avoid concurrency
        LDA #$01
        STA toggleEffect        ; Enable the effect immediately
        JMP CheckA2 ;Over

ButtonReleased:
        LDA #$00
        STA tapCounter          ; Reset the tapCounter
        STA toggleEffect        ; Bring the toggleEffect low to show immediate change

        LDA #$01
        STA tapEnabled          ; Enable the tap routine in infloop
        JMP CheckA2 ;Over

ButtonHeld:
        INC tapThreshold        ; Increase the length of the effect
        LDA #$01
        STA toggleEffect        ; Make sure the effect stays high for visual feedback

;       ----------------------------------------------------

CheckA2:
	LDA #%00000001          ; turn off all tile writing routines
	AND JustPressed2
	BEQ EndDrawChk

        lda #0
        sta tapThreshold        ; Reset the threshold
        sta tapCounter          ; Reset the counter
        sta tapEnabled          ; Disable the effect in infloop for now to avoid concurrency
        sta toggleEffect        ; Might already be defined in your glitchnes code
        sta write_toggle        ; turn this off so its not doubled up

EndDrawChk:                     ; check to see if its time to draw a new screen

        lda screenRedraw
        beq noScreenRedraw

    	LDA #%00000000          ; disable NMI's and screen display
 	STA $2000
   	LDA #%00000000
   	STA $2001

        JSR LoadNewPalette      ; load new palette
        JSR LoadScreen          ; turn off and load new screen data
        JSR DrawScreen          ; draw new screen
        JSR LoadScreen          ; turn off and load new screen data
        JSR DrawScreen2         ; draw new screen

        lda #$00                ; reset scroll
        sta scroll_h
        sta scroll_v

        JSR Vblank              ; turn the screen back on
        lda #0
        sta screenRedraw

noScreenRedraw:

        RTS

;       ---------------------------------------------------- tile writing routine

writer:                         ; this routine increases tile number and screen location
        ldy #$ff                ; then draws to the screen
write_tile:
        LDA PPU_ADDR+0
    	STA $2006
    	LDA PPU_ADDR+1
    	STA $2006

        inc tilenum
        lda tilenum
        sta $2007

        inc PPU_ADDR+1
        lda PPU_ADDR+1
        bne end_write
        inc PPU_ADDR+0

end_write:
        dey
        bne write_tile
        RTS

;       ---------------------------------------------------- <3 the NMI

NMI:
        jsr controller_test

        ldx scroll_h
        stx $2005
        ldx scroll_v
        stx $2005

;       ---------------------------------------------------- tap tempo handler

        LDA tapEnabled          ; This controls the tap tempo effects
        BEQ Over1               ; Skip routine if tapEnabled = 0

        LDA tapCounter
        CMP tapThreshold
        BNE TempLabel           ; If tapCounter = tapThreshold

        LDA toggleEffect        ; Toggle the effect
        EOR #$01
        STA toggleEffect
        LDA #$00
        STA tapCounter          ; Reset the counter
        JMP Over1

TempLabel:
        INC tapCounter          ; Else increase the tapCounter

Over1:

;       ----------------------------------------------------

        RTI
IRQ:
        RTI

;       ----------------------------------------------------  data

palette:                        ; palette data

        .INCBIN "pal0.pal" ; palette 0 - aligns with pic0 below

;       ----------------------------------------------------

pic0:
        .INCBIN "order.nam"

WelcomeText:
        .db "  GLITCHNES 0*15 BY NO CARRIER  ",$0D

;       ----------------------------------------------------

	.ORG $fffa
	.dw NMI
	.dw Reset
	.dw IRQ
