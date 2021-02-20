********************************
*      DOUBLE LORES GALTON     *
*                              *
*        & MOCKINGBOARD        *
*                              *
*      BY MARC GOLOMBECK       *
*                              *
*   VERSION 1.00 / 12.12.2020  *
********************************
*
 				DSK 	fire
 				MX 		%11
          		ORG 	$6000
*
KYBD      		EQU 	$C000     			; READ KEYBOARD
STROBE    		EQU 	$C010     			; CLEAR KEYBOARD
AUXMOVE			EQU		$C311				; move data to AUX mem
WRITERAM		EQU		$C081				; read ROM write RAM - toggle 2 times
READROM			EQU		$C082				; read ROM no write  - toggle 1 time
READWRITE		EQU		$C083				; read & write RAM   - toggle 2 times
READRAM			EQU		$C080				; read RAM no write  - toggle 1 time
HOME      		EQU 	$FC58     			; CLEAR SCREEN
VERTBLANK		EQU		$C019				; vertical blanking -> available only IIe and above
WAIT			EQU		$FCA8				; monitor ROM delay routine
VTAB			EQU		$FC22				; VTAB sets vertical cursor position
RDKEY			EQU		$FD0C				; get keyboard input, randomize $4E & $4F

FBASE			EQU		$1000				; flood filler table base
*
* DEMO VARS
RND1			EQU		$300				; random seed value
DIR				EQU		$301				; movement direction
GATE			EQU		$302				; toggle gate 
totPIX			EQU		#102				; number of pixels to animate
PIXCOL			EQU		#06					; color of animated pixel
* 
PT3_LOC 		EQU		$2000				; address of PT3-file 
ZP_SAVE			EQU		$1000				; zero page backup space
BUF1			EQU		$1100				; fire buffer of MAIN ram
BUF2			EQU		$1200				; fire buffer of AUX ram

* TEXT display VARS
WAITVAL			EQU		$325
TOGGLE			EQU		$320				; toggle fire

* math & MB zero page variables
TICKS			EQU		$10
INIT			EQU		$11	
D1				EQU		$12
CURHEAT			EQU		$13
B1				EQU		$14
B2				EQU		$15
B3				EQU		$16
B4				EQU		$17
FBUFIN			EQU		$18
XPB				EQU		$19					; xpos of background image
YPB				EQU		$1B					; ypos of background image
DPLT			EQU		$1D					; do plot the background image
SHOWFIRE		EQU		$1E
COLCYC			EQU		$1F					; cycle colors of FIRE logo
XCYC			EQU		$0F					; move X-position of logo
YCYC			EQU		$0E					; move Y-position of logo

BIW				EQU		#11					; width of back image
BIH				EQU		#3					; height of back image
;
;
;***************************************************************************************
; Init MB + Demo & show intro screen
;***************************************************************************************
START			LDA		#0
				STA		INIT				; INIT-phase active	
				JSR		DETECTA2			; get machine type
				JSR		INITSCRN
				JSR		LOADSONG			; load PT3-Song into memory
		  		JSR		DETECTCPU
		  		JSR		DETECTZIP
		  		JSR		DETECTFC
				JSR		DETECTLC			; can we also detect a language card?
				JSR		MB_DETECT			; get MockingBoard slot
          		JSR		SAVEzp				; save ZP vars into buffer				

				LDA		bMB					; check for mockingboard
				BNE		INITMB				; no MockingBoard -> sorry, no sound!
				JMP		noMB0
INITMB			JSR		MOCK_INIT			; init MockingBoard
				JSR 	SET_HANDLER			; hook up interrupt handler 
				JSR		INIT_ALGO			; init ZP + decoders vars	
				JSR		pt3_init_song		; init all variables needed for the player
				CLI
noMB0			LDA		#0
				STA		WAITVAL
				STA		TICKS
				STA		TOGGLE
				INC		TOGGLE				; fire is on
				;LDA		#4					; press a key message before starting the demo
				;STA		$24
				;LDA		#10
				;STA		$25
				;JSR		VTAB
				;LDX		#<T_SELECT	
				;LDY		#>T_SELECT
				;JSR		printCHAR
				;JSR		RDKEY				; press a key
				
				LDA		STROBE				; clear keypress
				
; DOLORES INIT
				JSR		SETUP				; setup AUX mem
				JSR		INITDLO				; init graphic
				LDA		#13
				JSR		GBOARD				; draw board
				
				LDA		bMB
				BEQ		noMB2
				;CLI
				
noMB2			JSR		INITBUF				; init fire buffers
				INC		INIT				; INIT-Phase done
				
				LDA		#$4F				; init PRNG
        		STA		RND1
				
				;LDA		PIXCOL
				;STA		COLOR

				LDA		#15					; init position of FIRE sign
				STA		XPB
				LDA		#16
				STA		YPB
				STZ		SHOWFIRE
				STZ		COLCYC
				LDA		#7					; current value of heat source
				STA		CURHEAT
				STZ		XCYC				; x-position of logo
				STZ		YCYC
				
				
KPRESS			LDA		STROBE
				
;
;
;***************************************************************************************
; Particle movement
;***************************************************************************************

				; propagation state machine
				; check down -> if free move
MOVE			LDX		#254
mvlp			LDA		BUF1,X
				BEQ		dec1				; if BUF1 = 0 then do nothing
				TAY
        		LDA 	RND1				; add randomness here -> do propagation?	
        		ASL
        		;BEQ		noEor1
        		BCC 	noEor1
		 		EOR 	#$A9
noEor1			STA 	RND1
				CMP		#%10100000
				BGE		nodec1

				BRA		dodec1
				
				CMP     #%10000000			; check for side  shift
				BGE		dodec1
				STX		DUMMY				; save X-reg
				TXA
				CLC
				ADC		#16					; do a column shift
				TAX
				LDA		BUF2,X
				LDX		DUMMY
				BRA		dec1
				
dodec1			TYA
				DEC
				BRA		dec1
nodec1			TYA
dec1			INX
				STA		BUF1,X				; BUF1+1 = BUF1 - 1
				DEX

mbuf2			LDA		BUF2,X
				BEQ		dec2				; if BUF1 = 0 then do nothing
				TAY
        		LDA 	RND1				; add randomness here -> do propagation?	
        		ASL
        		;BEQ		noEor1
        		BCC 	noEor2
		 		EOR 	#$A9
noEor2			STA 	RND1
				CMP		#%10100000
				BGE		nodec2

				BRA		dodec2
				
				CMP     #%10000000			; check for side  shift
				BGE		dodec2
				STX		DUMMY				; save X-reg
				TXA
				CLC
				ADC		#16					; do a column shift
				TAX
				LDA		BUF1,X
				LDX		DUMMY
				BRA		dec2
				
dodec2			TYA
				DEC
				BRA		dec2
nodec2			TYA
dec2			INX
				STA		BUF2,X				; BUF1+1 = BUF1 - 1
				DEX



nob2			DEX
				TXA
				AND		#%00001111
				CMP		#%00001111
				BNE		noincx
				DEX
noincx			CPX		#254					; end of buffer reached?
				BNE		mvlp				


PLTSCR			
				LDX		XCYC
				LDA		XCYCLETAB,X
				STA		XPB					; make sinusoidal movement of backimage
				LDX		YCYC
				LDA		YCYCLETAB,X
				STA		YPB
				INC		XCYC
				LDA		XCYC
				CMP		#21
				BNE		noxcycRES		
				STZ		XCYC
noxcycRES		INC		YCYC
				LDA		YCYC
				CMP		#31
				BNE		noycycRES
				STZ		YCYC

noycycRES		LDX		#12					; x-offset / 2

				STZ		D1					; init counter		
				STZ		FBUFIN				; index into background framebuffer	
				STZ		DPLT				; no plotting
				
				LDA		XPB
				CLC
				ADC		BIW
				STA		XPB+1				; calc new positions
				INC		XPB+1
				
				LDA		YPB
				SEC
				SBC		BIH
				STA		YPB+1
				
pltlp			LDY		#16					; y-offset
											; generate output -> own fast plot routine
pltlp1			PHY
				PHX							;push X to stack for later -> x-coord

				LDA		SHOWFIRE			; shall we display the FIRE logo?
				BEQ		notinbuf
				
				TXA
				CMP		XPB
				BCC		notinbuf
				CMP		XPB+1
				BCS		notinbuf

				TYA
				CMP		YPB+1
				BCC		notinbuf
				CMP		YPB
				BCS		notinbuf
				INC		DPLT					; set to 1 -> plot pixels
				
notinbuf		LDX		D1
				LDA		BUF2,X
				STA		B3
				LDA		BUF1,X
				TAX
				LDA		PLTPALHI,X			; get first nibble
				STA		B1
				LDX		B3
				LDA		PLTPALHIA,X			; for AUX mem
				STA		B3
				
				INC		D1
				LDX		D1
				LDA		BUF2,X
				STA		B4
				LDA		BUF1,X
				TAX
				LDA		PLTPALLO,X			; get second nibble
				CLC
				ADC		B1					; screen byte now in ACCU
				STA		B2					; save it
				LDX		B4
				LDA		PLTPALLOA,X			; for AUX mem
				CLC
				ADC		B3
				STA		B4					; second screen byte for AUX
				
				INC		D1
				
				TYA							; get y-coordinate
				TAX
				LDA		YLOOKLO,X			; lookup row index adress
				STA		BASELINE
				LDA		YLOOKHI,X
				STA		BASELINE+1

				PLX							; read back X-coord
				TXA
				PHX
				TAY							; push x-index in Y-reg
				LDA		DPLT
				BEQ		nbim1
				LDX		FBUFIN
smbi1			LDA		BACKIM3,X
				LDX		B2
				AND		PATMASK,X
				CLC
				ADC		B2
				INC		FBUFIN
				BRA		nbim1a
nbim1			LDA		B2
nbim1a			STA		(BASELINE),Y		; draw 2 pixels
				
				LDA		DPLT
				BEQ		nbim2
				LDX		FBUFIN
smbi2			LDA		BACKIM3,X
				LDX		B4
				AND		PATMASK,X
				CLC
				ADC		B4
				STZ		DPLT
				INC		FBUFIN
				BRA		nbim2a

nbim2			LDA		B4
nbim2a			STA		WRITEAUX
				STA		(BASELINE),Y		; draw 2 pixels AUX
				STA		WRITEMAIN
				
				PLX
				PLY							; read back Y-coord
				;DEY
				DEY
				CPY		#8					; check if one column is done
				BEQ		pltlp1e
				JMP 	pltlp1
pltlp1e			INX
				;INX
				CPX		#28					; check if first buffer is done
				BEQ		pltlp1f		
				JMP		pltlp				; no -> next column

pltlp1f			INC		RND1
				
				LDA		#20
				JSR		WAIT				
				
chkKEY			LDA		KYBD
				BPL		anim
				BIT 	STROBE
KEYQ      		CMP 	#$D1       			; KEY 'Q' IS PRESSED
          		BEQ 	ENDE
KEYR			CMP		#$D2				; key "R" .-> reverse direction
				BNE		KEYT
				JMP		anim
KEYT        	CMP		#$D4				; toggle FIRE on/off
				BNE		KEYN
				LDA		INIT
				BNE		anim
				LDA		TOGGLE
				BEQ		tglon
				DEC		TOGGLE
				JSR		FIREOFF
				BRA		anim
tglon			INC		TOGGLE			
				JSR		FIREON
				BRA		anim
KEYN			CMP		#$CE				; decrease HEAT
				BNE		KEYM
				LDA		INIT
				BNE		anim				; don't do this during initialisation
				LDA		CURHEAT				; check if minimum HEAT reached
				CMP		#3
				BEQ		anim
				DEC		CURHEAT
				LDA		CURHEAT
				JSR		INJECTBUF			; set new heat
				BRA		anim
KEYM			CMP		#$CD				; increase HEAT
				BNE		anim
				LDA		INIT
				BNE		anim				; don't do this during initialisation
				LDA		CURHEAT				; check if maximum HEAT reached
				CMP		#7
				BEQ		anim
				INC		CURHEAT
				LDA		CURHEAT
				JSR		INJECTBUF			; set new heat
								
anim			
				JMP		MOVE				; move next particle
	
ENDE			LDA		STROBE
				JSR		EXITDLO
				;JMP		ENDE1
				;to be included
				LDA		#14				; HTAB 14
				STA		$24
				LDX		#<T_SHACK		; 8-Bit-Shack
				LDY		#>T_SHACK
				JSR		printCHAR
				JSR		LFEED
				JSR		LFEED
				JSR		LFEED
				;LDA		#1
				;STA		$24
				;LDX		#<T_END		
				;LDY		#>T_END
				;JSR		printCHAR
				JSR		LFEED
				JSR		LFEED
				JSR		LFEED
				JSR		LFEED
				LDA		#6
				STA		$24
				LDX		#<T_INFO		
				LDY		#>T_INFO
				JSR		printCHAR
				JSR		LFEED
				JSR		LFEED
				JSR		LFEED
				JSR		LFEED
				LDA		#13
				STA		$24
				LDX		#<T_END2		
				LDY		#>T_END2
				JSR		printCHAR
				JSR		LFEED
getKEY			LDA		KYBD
				BPL		getKEY
				LDA		STROBE
				SEI
          		;LDA		READROM				; language card off
ENDE1			JSR		CLEAR_LEFT			; mute MockingBoard
          		JSR		RESTzp				; get back original ZP values
				JMP		$3d0				; reset
				RTS
								

								
RANDOM01        					; changes Accu
        		LDA 	RND1
        		ASL
        		BCC 	noEor2R1
doEor2R1 		EOR 	#$1D
noEor2R1		STA 	RND1
        		AND 	#%1      	; between 0 and 1
        		RTS

ANIMGATE

INITBUF			LDX		#0
				LDA		#0
inlp1			STA		BUF1,X
				STA		BUF2,X
				TAY
				TXA
				AND		#%00001111			; set bottom lines to #6
				BNE		noinit
				LDA		#3
				STA		BUF1,X
				STA		BUF2,X
noinit			TYA
				INX
				BNE		inlp1		
				LDA		#3					; also set index 0
				STA		BUF1
				STA		BUF2					

				RTS
				
FIREOFF			LDX		#0
fofflp			TXA
				ASL
				ASL
				ASL	
				ASL						; * 16
				TAY
				LDA		#0
				STA		BUF1,Y
				STA		BUF2,Y
				INX
				CPX		#16				
				BNE		fofflp
				RTS

FIREON			LDX		#0
fonlp			TXA
				ASL
				ASL
				ASL	
				ASL						; * 16
				TAY
				LDA		CURHEAT
				STA		BUF1,Y
				STA		BUF2,Y
				INX
				CPX		#16				
				BNE		fonlp
				RTS
;	
;
;***************************************************************************************
; Show welcome screen
;***************************************************************************************
INITSCRN
          		JSR	$FB39			; command TEXT
				JSR	HOME			; clear text screen
				LDA		#0
				STA		WAITVAL
				LDA	#14				; HTAB 14
				STA	$24
				LDX	#<T_SHACK		; 8-Bit-Shack
				LDY	#>T_SHACK
				JSR	printCHAR
				
				LDA		#80
				STA		WAITVAL
				LDA	#16				; Options menu
				STA	$24
				LDA	#18
				STA	$25
				JSR	VTAB
				LDX	#<T_OPT1
				LDY	#>T_OPT1
				JSR	printCHAR
							
				LDA	#4
				STA	$24
				LDA	#20
				STA	$25
				JSR	VTAB
				LDX	#<T_OPT3
				LDY	#>T_OPT3
				JSR	printCHAR
				
				LDA	#4
				STA	$24
				LDA	#21
				STA	$25
				JSR	VTAB
				LDX	#<T_OPT4
				LDY	#>T_OPT4
				JSR	printCHAR
				
				LDA	#4
				STA	$24
				LDA	#22
				STA	$25
				JSR	VTAB
				LDX	#<T_OPT2
				LDY	#>T_OPT2
				JSR	printCHAR
							

				LDA	#11
				STA	$24
				LDA	#10
				STA	$25
				JSR	VTAB
				LDX	#<T_LOAD		
				LDY	#>T_LOAD
				JSR	printCHAR

				RTS
;
;
;***************************************************************************************
; GALTON board drawing routine
;***************************************************************************************
				PUT		gboard.s
;
;
;***************************************************************************************
; Demo control - stuff that is done during interrupt handler activity
;***************************************************************************************
DEMOINTSTUFF		
					INC		RND1

					LDA		SHOWFIRE			; check if FIRE logo is shown
					CMP		#1
					BLT		cntFIRE

					INC		TICKS
					LDA		TICKS
					CMP		#8
					BNE		cntFIRE
					LDA		SHOWFIRE
					CMP		#5
					BNE		incFIRE
					
					LDA		COLCYC				; color cycle FIRE logo
					BNE		chkCYC1
					LDA		#>BACKIM2
					STA		smbi1+2
					STA		smbi2+2
					LDA		#<BACKIM2
					STA		smbi1+1
					STA		smbi2+1
					INC		COLCYC
					BRA		cycRTS				
							
chkCYC1				CMP		#1
					BNE		chkCYC2	
					LDA		#>BACKIM3
					STA		smbi1+2
					STA		smbi2+2
					LDA		#<BACKIM3
					STA		smbi1+1
					STA		smbi2+1
					INC		COLCYC
					BRA		cycRTS				
					
chkCYC2				LDA		#>BACKIM4
					STA		smbi1+2
					STA		smbi2+2
					LDA		#<BACKIM4
					STA		smbi1+1
					STA		smbi2+1
					STZ		COLCYC
					
cycRTS				STZ		TICKS
cycRTS1				RTS

incFIRE				INC		SHOWFIRE
					DEC		YPB					; move FIRE logo one step up	
					STZ		TICKS
					RTS
					
cntFIRE				LDA		INIT				; check if INIT was done before changing the frame!
					BNE		cntINT
					RTS
cntINT
					INC		TICKS
					LDA		TICKS
					CMP		#240
					BEQ		cntINT2
					RTS
cntINT2
					
					LDX		#0
					INC		BUF1,X
					INC		BUF2,X
					LDX		#16
					INC		BUF1,X
					INC		BUF2,X
					LDX		#32
					INC		BUF1,X
					INC		BUF2,X
					LDX		#48
					INC		BUF1,X
					INC		BUF2,X
					LDX		#64
					INC		BUF1,X
					INC		BUF2,X
					LDX		#80
					INC		BUF1,X
					INC		BUF2,X
					LDX		#96
					INC		BUF1,X
					INC		BUF2,X
					LDX		#112
					INC		BUF1,X
					INC		BUF2,X
					LDX		#128
					INC		BUF1,X
					INC		BUF2,X
					LDX		#144
					INC		BUF1,X
					INC		BUF2,X
					LDX		#160
					INC		BUF1,X
					INC		BUF2,X
					LDX		#176
					INC		BUF1,X
					INC		BUF2,X
					LDX		#192
					INC		BUF1,X
					INC		BUF2,X
					LDX		#208
					INC		BUF1,X
					INC		BUF2,X
					LDX		#224
					INC		BUF1,X
					INC		BUF2,X
					LDX		#240
					INC		BUF1,X
					INC		BUF2,X
					

					LDA		#0					; reset counter
					STA		TICKS
					INC		INIT
					LDA		INIT
					CMP		#5
					BNE		dintRTS
					LDA		#0
					STA		INIT				; switch off increase routine
					LDA		#1
					STA		SHOWFIRE
dintRTS				RTS


INJECTBUF

					LDX		#0
					STA		BUF1,X
					STA		BUF2,X
					LDX		#16
					STA		BUF1,X
					STA		BUF2,X
					LDX		#32
					STA		BUF1,X
					STA		BUF2,X
					LDX		#48
					STA		BUF1,X
					STA		BUF2,X
					LDX		#64
					STA		BUF1,X
					STA		BUF2,X
					LDX		#80
					STA		BUF1,X
					STA		BUF2,X
					LDX		#96
					STA		BUF1,X
					STA		BUF2,X
					LDX		#112
					STA		BUF1,X
					STA		BUF2,X
					LDX		#128
					STA		BUF1,X
					STA		BUF2,X
					LDX		#144
					STA		BUF1,X
					STA		BUF2,X
					LDX		#160
					STA		BUF1,X
					STA		BUF2,X
					LDX		#176
					STA		BUF1,X
					STA		BUF2,X
					LDX		#192
					STA		BUF1,X
					STA		BUF2,X
					LDX		#208
					STA		BUF1,X
					STA		BUF2,X
					LDX		#224
					STA		BUF1,X
					STA		BUF2,X
					LDX		#240
					STA		BUF1,X
					STA		BUF2,X

					RTS
;
;
; Text output strings
;
T_SHACK		ASC "8-BIT-SHACK"
			HEX	00
T_SELECT	ASC	"Press a key to start the demo..."
			HEX	00		
T_LOAD		ASC	"Loading demo data..."
			HEX	00		
T_OPT1		ASC	"Options:"
			HEX	00
T_OPT2		ASC	"  <Q>:   Quit FIRE-Demo"
			HEX	00
T_OPT3		ASC	"  <T>:   Toggle fire ON/OFF"
			HEX	00
T_OPT4		ASC	"  <M/N>: Increase/Decrease heat"
			HEX	00
T_END		ASC "MERRY X-MAS 2020 AND A HAPPY NEW YEAR!"
			HEX 00
T_END2		ASC "<PRESS A KEY>"
			HEX 00
T_INFO		ASC "MORE INFO: WWW.GOLOMBECK.EU"
			HEX 00


;
;***************************************************************************************
; include MockingBoard-support & helper routines
;***************************************************************************************

				PUT 	mbdetect.s
				PUT 	ihandler.s
				PUT 	pt3lib.s

COLPAL			DFB		0,5,10,8,1,9,13,15		; color propagation palette
PLTPALLO		HEX		0008080101090D0F		; palette for LO nibble
PLTPALHI		HEX		008080101090D0F0		; palette for HI nibble
PLTPALLOA		HEX		00040408080C0E0F		; palette for LO nibble AUX
PLTPALHIA		HEX		0040408080C0E0F0		; palette for HI nibble AUX
;PLTPALLO		HEX		00050A0801090D0F		; palette for LO nibble
;PLTPALHI		HEX		0050A0801090D0F0		; palette for HI nibble
;PLTPALLOA		HEX		000A0504080C0E0F		; palette for LO nibble AUX
;PLTPALHIA		HEX		00A0504080C0E0F0		; palette for HI nibble AUX
				
				DS	\
PATMASK											; masking out the foreground fire pixels
				HEX		FFF0F0F0F0F0F0F0F0F0F0F0F0F0F0F0
				HEX		0F000000000000000000000000000000
				HEX		0F000000000000000000000000000000
				HEX		0F000000000000000000000000000000
				HEX		0F000000000000000000000000000000
				HEX		0F000000000000000000000000000000
				HEX		0F000000000000000000000000000000
				HEX		0F000000000000000000000000000000
				HEX		0F000000000000000000000000000000
				HEX		0F000000000000000000000000000000
				HEX		0F000000000000000000000000000000
				HEX		0F000000000000000000000000000000
				HEX		0F000000000000000000000000000000
				HEX		0F000000000000000000000000000000
				HEX		0F000000000000000000000000000000
				HEX		0F000000000000000000000000000000

BACKIM
				HEX		0000000000FF0F0F0F0F00000FFF0F0000FF0F0F0FF000FF0F0F0F0F00000000
				HEX		0000000000FFF0F0F000000000FF000000FFF0F0F00F00FFF0F0F00000000000
				HEX		0000000000FF000000000000F0FFF00000FF00000FF000FFF0F0F0F000000000
				HEX		0000000000000000000000000000000000000000000000000000000000000000
				HEX		0000000000000000000000000000000000000000000000000000000000000000
				HEX		0000000000000000000000000000000000000000000000000000000000000000
				HEX		0000000000000000000000000000000000000000000000000000000000000000
				HEX		0000000000000000000000000000000000000000000000000000000000000000

BACKIM2							
				HEX		00FFF0FF0FFF
				HEX		0000F0F00F0F
				HEX		00000000000F

				HEX		FFF0FF00FF0F
				HEX		00F00000000F
				
				HEX		00FFF0FF0FFF
				HEX		0F00F0F00F0F
				HEX		00F0000F00F0
				
				HEX		F0FFF0FF0FFF
				HEX		F0F0F0F00F0F
				HEX		00F00000000F
				HEX		000000000000						
				
BACKIM3							
				HEX		00EED0EE0DEE
				HEX		0000D0E00D0E
				HEX		00000000000E

				HEX		DDE0DD00DD0E
				HEX		00E00000000E
				
				HEX		00EED0EE0DEE
				HEX		0D00D0E00D0E
				HEX		00E0000E00E0
				
				HEX		D0EED0EE0DEE
				HEX		D0E0D0E00D0E
				HEX		00E00000000E
				HEX		000000000000						
				
BACKIM4							
				HEX		00CC90CC09CC
				HEX		000090C0090C
				HEX		00000000000C

				HEX		99C09900990C
				HEX		00C00000000C
				
				HEX		00CC90CC09CC
				HEX		090090C0090C
				HEX		00C0000C00C0
				
				HEX		90CC90CC09CC
				HEX		90C090C0090C
				HEX		00C00000000C
				HEX		000000000000						
				
XCYCLETAB		DFB		15,16,17,17,18,18,18,18,17,17,16
				DFB		15,14,13,13,12,12,12,12,13,13,14				

YCYCLETAB		DFB		12,12,12,13,14,15,15,15,14,13,12
				DFB		12,12,13,14,15,15,15,14,13,12,12
				DFB		12,13,14,15,15,15,14,13
								
;
;****************************************************************************************
; end of demo code
;****************************************************************************************

;
; DOLORES SECTION
;

				PUT	dolores.s				
				

          		
          		