.petscii
.include "godotlib.lib"
.ob "mshowvdc,p,w"
; --------------------------------------
;
; mod.ShowVDCFloyd
;
;   0.99, 08.04.94: first release
;   1.00, 02.02.02: added Softlace 640x400
;   1.01, 03.02.02: added ability to view either 640x200
;                         or 640x400 (softlace)
; 
; --------------------------------------

		.ba $c000

		.eq adcnt	=$30
		.eq src		=$35
		.eq buf		=src
		.eq dst		=$37
		.eq ffo		=dst
		.eq linenr	=$39
		.eq blcnt	=$3a
		.eq val		=$3b
		.eq outval	=$3c
		.eq ffl		=$3d
		.eq bbuf	=$3e
		.eq ffbuf	=$3f
		.eq pflg	=$40
		.eq pass	=$41
		.eq btcnt	=$42

		.eq sprptr	=$07f8
		.eq spr255	=$3fc0
		.eq buf0	=$bd00
		.eq buf1	=$c400
		.eq byte 	=$c700

		.eq sprx2	=$d004
		.eq spry2	=$d005
		.eq sprhi	=$d010
		.eq spren	=$d015
		.eq sprxe	=$d01d
		.eq sprcol2	=$d029

		.eq vdcstat	=$d600
		.eq vdcdata	=$d601

		.eq update	= 18		; VDC registers
		.eq color	= 26
		.eq bytes	= 30
		.eq data	= 31

; -------------------------------------- Header

		jmp start
		.by $20		; type: module
		.by 0
		.by 1		; dirty
		.wo modend
		.wo 0
		.tx "show vdc ed mono"
		.tx "1.01"
		.tx "03.02.02"
		.tx "W.Kling/A.Dettke"

; -------------------------------------- Main

start		jsr checkvdc		; VDC available? (if not: doesn't return!)

            ldx #36		; get current VDC register settings
st0         jsr readvdc
            sta vdctab,x	; and store them
            dex
            bpl st0
            lda vdctype
            bpl st2
            lda vdctab+28
            sta vdctab2+28
            sta vdctab3+28

st2		ldx #2			; which VDC?
		stx adcnt		; (set activity counter)
		lda vdctype
		bmi pskip		; 64K?
		dex			; 16K?
pskip		stx dbly		; set vertical factor (200 or 400 pixels)
		jsr initad		; init activity display

		lda #0			; clear buffer ($c400-$c6ff)
		tay
cloop		sta buf1,y
		sta buf1+256,y
		sta buf1+512,y
		iny
		bne cloop

; -------------------------------------- Render pixels

		sta linenr		; line counter (0 - 199)
loop00		jsr getline		; get data of one raster line (to BUF0)
		lda dbly		; set number of passes (depending on VDC type)
		sta pass

again		lda #<buf0		; (entry for second pass)
		ldx #>buf0		; set address values of buffers
		sta buf			; source buffer
		stx buf+1
		lda #<buf1
		ldx #>buf1
		sta ffo			; destination buffer (just cleared)
		stx ffo+1
		ldx #0			; counts 80 bytes (stretched raster line: 640 pixels)
		ldy #0
		sty ffl
		lda #$80		; set bitmask to %10000000
		sta btcnt

; -------------------------------------- Error Distribution

edloop		lda (ffo),y		; get byte from destination buffer (is zero)
		clc
		adc ffl			; add current error (zero at first time)
		sta ffbuf		; store 

		lda (buf),y		; get byte from source buffer (4Bit data byte; double pixel!)
		asl			; times 8
		asl
		asl
		sta bbuf		; store

		bit ffbuf		; ms bit set?
		bmi negff
		adc ffbuf		; no, add current error sum and...
		sec
		ror pflg		; set bit in flag
		jmp valok

negff		lda ffbuf		; yes, add current error sum and...
		adc bbuf
		ror pflg		; clear bit in flag
valok		sta val			; store as value

		bit pflg		; negative?
		bpl null		; no, branch
		cmp #60			; < $3c? 
		bcc null		; yes, branch

		lda #15			; delimit to 4Bit
		.by $2c
null		lda #0

		cmp #1			; >1 or <1?
		rol byte,x		; generate next pixel in result buffer
		lsr btcnt		; next bit
		bcc btskip		; 8 bits processed?
		ror btcnt		; yes, set mask to %10000000 again
		inx			; advance in result buffer

btskip		asl			; compute new error value:
		asl
		asl
		sta outval		; and store

		lda val			; subtract from error value
		sec 
		sbc outval
		clc			; result positive?
		bpl posit		; yes, clear bit
		sec			; no, set bit
posit		ror
		sta (ffo),y		; and store to error buffer
		sta ffl

		iny			; advance in buffers
		bne edskip0

		inc buf+1
		inc ffo+1
edskip0		cpx #80			; 80 cards?
		bne edloop		; no, loop

; -------------------------------------- next line

		jsr moveline		; yes, write rendered ed-line to VDC
		dec pass		; second pass to go (VDC64K)?
		bne again		; yes, loop (don't clear buffer)

		inc linenr		; advance to next raster line
		dec adcnt		; care for activity display
		bne adskip

		inc spry2		; move activity bar
		inc spry2+2
		lda #5
		sta adcnt

adskip		lda linenr		; last raster line?
		cmp #200
		beq exit0		; yes, finish
		jmp loop00		; no, next line

exit0		jsr clearad		; clear activity bar
		jsr softlace		; show 640x400
		clc			; leave module
		rts

; -------------------------------------- Get one raster line of data

getline		lda linenr		; number of raster line 
		pha
		lsr			; divided by 8
		lsr
		lsr
		tax			; as index in table of hibytes
		pla
		and #7			; number AND 7
		asl			; times 4 (4Bit!)
		asl
		sta dst			; is low byte of source (!) address
		lda line8,x
		sta dst+1		; set hibyte

		lda #<buf0		; destination: buf0
		ldx #>buf0
		sta src
		stx src+1
		ldx #0
		lda #40			; 40 cards (source)
		sta blcnt		; (stretch to 80 cards)

loop0		ldy #0			; get 4Bit value
loop1		lda (dst),y
		pha 
		lsr			; left nibble
		lsr
		lsr
		lsr
		sta (src,x)		; store to buffer
		inc src
		bne skip0
		inc src+1
skip0		sta (src,x)		; twice
		inc src
		bne skip01
		inc src+1
skip01		pla			; right nibble
		and #15
		sta (src,x)		; store to buffer
		inc src
		bne skip1
		inc src+1
skip1		sta (src,x)		; twice
		inc src
		bne skip11
		inc src+1
skip11		iny			; 8 pixels per card
		cpy #4
		bne loop1

		lda dst			; next card
		clc
		adc #32
		sta dst
		bcc skip2
		inc dst+1
skip2		dec blcnt		; count cards
		bne loop0
		rts			; until finished

; -------------------------------------- Hibytes of 4Bit card lines

line8		.by $40, $45, $4a, $4f, $54
		.by $59, $5e, $63, $68, $6d
		.by $72, $77, $7c, $81, $86
		.by $8b, $90, $95, $9a, $9f
		.by $a4, $a9, $ae, $b3, $b8

; ----------------------------------- Activity Display

initad      ldy #60		; create bright bar
            lda #0
adl0        sta spr255+3,y
            dey
            bpl adl0
            sty spr255
            sty spr255+1
            sty spr255+2

            lda #15		; light gray
            sta sprcol2
            sta sprcol2+1
            lda sprxe		; expand x
            ora #12
            sta sprxe

            lda sprhi		; sprites 2 & 3 beyond 255
            ora #12
            sta sprhi
            lda #8		; x position: 33 & 36
            sta sprx2
            lda #32
            sta sprx2+2
            lda #144		; y position: 18
            sta spry2
            sta spry2+2

            lda #$ff		; sprite 2 & 3 at area 255 ($3fc0)
            sta sprptr+2
            sta sprptr+3

            lda spren		; activate sprites
            ora #12
            sta spren
            rts

; ----------------------------------- 

clearad     lda spren		; display mouse pointer only
            and #$f3
            sta spren
            lda sprhi
            and #$f3
            sta sprhi
            rts

; ----------------------------------- VDC Softlace 640x400

swapsl      lda vdctab+1
            sta vdctab3+1
            sta vdctab3+27
            lda vdctab+27
            sta skipmk

reswap      ldx #36
swsl        lda vdctab3,x
            pha
            lda vdctab,x
            sta vdctab3,x
            pla
            sta vdctab,x
            dex
            bpl swsl
            jmp setvdcsl

; ----------------------------------- 

softlace    lda vdctype		; check type
            bpl ehl1		; negative? (VDC 64K?)
            sei			; yes, then lace
            lda $d011
            pha
            jsr swapsl
            ldx #0
            stx $d011
            inx
            stx $d030
ehl0        ldy #0
            jsr laceit
            ldy vdctab+27
            jsr laceit
            lda $dc01
            cmp #$ff
            beq ehl0
            ldx #0
            stx $d030
            lda skipmk
            sta vdctab3+27
            jsr reswap
            pla
            sta $d011
            jsr iv2
            cli
ehl1        clc
            rts
;
laceit      lda #32
li0         bit vdcstat
            beq li0
li1         bit vdcstat
            bne li1
            ldx #13
            tya
            stx vdcstat
li2         bit vdcstat
            bpl li2
            sta vdcdata
            rts

; -------------------------------------- Check for VDC

checkvdc	lda rm_vdcflag		; get GoDot VDC value
		ldx sc_merk+1		; get column of mouseclick
		cpx #31			; <31?
		bcs chv0		; no, lace if possible
		and #$7f		; yes, fake 16K VDC
chv0		sta vdctype
		and #1			; any VDC available?
		beq novdc		; no

		jsr initvdc		; yes, init
		bcs novdc		; locked?
		rts			; no

novdc		pla			; yes, leave module
		pla
		clc
		rts

; -------------------------------------- Initialize VDC

initvdc		lda vdctype		; VDC locked? (No graphics use?)
		and #$40
		bne errr2		; yes, leave (not implemented yet)

		sei
		lda vdctype		; re-get type
		bmi iv0			; negative? (VDC 64K?)
iv2		ldy #9			; no, standard 16K
		.by $2c
iv0		ldy #19			; yes

		ldx #9			; write appropriate settings to VDC
iv1		lda regs,y
		jsr setvdc
		dey
		dex
		bpl iv1

		lda #0			; graphics start at $0000
		ldx #update
		jsr setvdc
		inx
		jsr setvdc
		cli
		clc
		rts

; --------------------------------------

errr2		sec
		rts

; -------------------------------------- VDC settings

regs		.by 126, 80, 100, $19, 79, $e0, 49, 0 ,$ff, $e7 ; 16K
		.by 126, 80, 100, $19, 83, $e0, 83, 0, $ff, $37 ; 64K

skipmk      .by 0

; -------------------------------------- 

vdctab      .by 0,0,0,0,0,0,0,0
            .by 0,0,0,0,0,0,0,0
            .by 0,0,0,0,0,0,0,0
            .by 0,0,0,0,0,0,0,0
            .by 0,0,0,0,0
;
vdctab2     .by 127,80,102,73,38,0,25,32
            .by 0,231,160,231,0,0,0,0
            .by 0,0,0,0,8,0,120,232
            .by 32,135,240,0,47,231,0,0
            .by 0,0,125,100,245
;
vdctab3     .by 127,80,102,143,81,7,50,65
            .by 255,231,160,231,0,0,0,0
            .by 0,0,0,0,8,0,120,232
            .by 32,135,240,80,47,231,0,0
            .by 0,0,125,100,245

; -------------------------------------- Write to VDC

writedata	ldx #data
setvdc		stx vdcstat
wll		bit vdcstat
		bpl wll
		sta vdcdata
		rts

; -------------------------------------- Write all registers

setvdcsl    ldx #0
wr1         lda vdctab,x
write       stx vdcstat
wr2         bit vdcstat
            bpl wr2
            sta vdcdata
            inx
            cpx #37
            bne wr1
            clc
            rts

; -------------------------------------- Read from VDC

readvdc     stx vdcstat
tv2         bit vdcstat
            bpl tv2
            lda vdcdata
            rts

; -------------------------------------- Copy rendered line to VDC

moveline	sei
		ldy #0
mll		lda byte,y
		jsr writedata
		iny
		cpy #80
		bne mll
		cli 
		rts

; -------------------------------------- Values

vdctype		.by 0
dbly		.by 0

offs		.by 0, 16, 32, 48
		.by 0, 16, 32, 48

; --------------------------------------

modend		.en
