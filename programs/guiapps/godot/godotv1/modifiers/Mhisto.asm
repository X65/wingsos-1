.petscii
.include "godotlib.lib"
.ob "mHisto,p,w"
.ba $c000

; ------------------------------------------------------------ 
;
; mod.Histogram
; Module to retrieve information about the number of pixels of
; a particular color, and manipulate these data
;
;    0.99, 23.04.92: first release
;    1.00, 20.11.00, added: Join and Swap functionality
;    1.01, 21.01.02, added: Redisplay of rendered screen
;
; ------------------------------------------------------------ 

            .eq adcnt		=$30
            .eq hdone		=$31
            .eq cnt		=$32
            .eq joinbuf		=$33
            .eq ymerk		=$34
            .eq joinflag	=$35
            .eq join1		=$36
            .eq join2		=$37
            .eq where		=$38
            .eq therev1		=$3a
            .eq therev2		=$3b
            .eq therec		=$3c

            .eq offx		=$b2
            .eq offy		=$b3

            .eq src0		=$f7
            .eq lcnt8		=$fa
            .eq lcnt		=$fb
            .eq gbyte		=$fc
            .eq counter		=$fd

            .eq col0		=$0334

            .eq histlo		=$be00
            .eq histhi		=$be10

            .eq vram2		=$ce0b
            .eq vram1		=$de0b
            .eq cstart		=$ee0b

; --------------------------------------- Header

header      jmp start
            .by $20
            .by 0
            .by 0
            .wo modend
            .wo 0
            .tx "4BitHistogram   "
            .tx "1.01"
            .tx "21.01.02"
            .tx "A. Dettke       "

; --------------------------------------- Main

start       ldx sc_screenvek
            stx list
            ldx sc_screenvek+1
            stx list+1
            jsr showrequester	; display requester and show first histogram
            jsr gd_eloop		; wait for clicks

; --------------------------------------- Event: Exit
evexit      sec
            rts

; --------------------------------------- Textout

tabigad     .by <(blk),>(blk)		; 0
            .by <(blu),>(blu)		; 2
            .by <(bwn),>(bwn)		; 4
            .by <(gr1),>(gr1)		; 6
            .by <(red),>(red)		; 8
            .by <(pur),>(pur)		; 10
            .by <(ora),>(ora)		; 12
            .by <(gr2),>(gr2)		; 14
            .by <(lbl),>(lbl)		; 16
            .by <(lrd),>(lrd)		; 18
            .by <(grn),>(grn)		; 20
            .by <(gr3),>(gr3)		; 22
            .by <(cyn),>(cyn)		; 24
            .by <(yel),>(yel)		; 26
            .by <(lgr),>(lgr)		; 28
            .by <(wht),>(wht)		; 30
            .by <(box),>(box)		; 32
            .by <(black),>(black)	; 34
            .by <(grau1),>(grau1)	; 36
            .by <(grau2),>(grau2)	; 38
            .by <(grau3),>(grau3)	; 40
            .by <(white),>(white)	; 42
            .by <(blnk),>(blnk)		; 44
            .by <(blnk2),>(blnk2)	; 46
;
settab      lda #<(tabigad)
            sta sc_texttab
            lda #>(tabigad)
            sta sc_texttab+1
            rts
;
gettab      lda (sc_texttab),y
            sta sc_screentab
            iny
            lda (sc_texttab),y
            sta sc_screentab+1
            lda #0
            tax
            tay
gt0         jsr gd_setpos
            cpx #4
            bne gt0
            jsr gd_trim
            jmp gd_initmove

; --------------------------------------- Prepare Gauge Bar

initgauge   ldx #0		; prepare activity display (gauge bar)
            jsr tcopy
            jsr gd_clrms
            lda cntwert
            sta adcnt
            stx offy
            lda #7
            sta offx
            rts

; --------------------------------------- Finish Gauge

done        jsr settab		; Offset to "Done."
            ldx #9
            jsr tcopy
            jmp messout

; --------------------------------------- Show Requester

showrequester: ldx #<(hstlst)	; display requester
            ldy #>(hstlst)
            jsr gd_screen
            ldy #32		; colorize inner box
            jsr settab
            jsr gettab
            ldx #2
            jsr gd_fcol

            stx sc_loop		; care for text mode
            lda #2		; prepare for colorbar
            sta sc_br
            jsr gd_initmove
            jsr gd_invert

            ldx #1		; show palette
            stx sc_ho
            dex
            stx sc_merk
            stx hdone
ep2         lda paldflt,x
            sta col0+4
            ldx #4
            jsr gd_fcol
            inc sc_zl
            inc sc_merk
            ldx sc_merk
            cpx #16
            bcc ep2

            ldy #34		; hilite patterns
ep3         sty sc_merk
            jsr gettab
            ldx #3
            jsr gd_fcol
            ldy sc_merk
            iny
            iny
            cpy #44
            bne ep3
       
; --------------------------------------- Event: Histogram

evhist      jsr initgauge
            ldy #0		; set address of histogram table
            sty sc_merk
            sty hdone
            lda #>(histlo)
            sta sc_merk+1           
            tya			; clear histogram table at $be00
            ldx #$20
ht0         sta (sc_merk),y
            iny
            dex
            bpl ht0
; --------------------------------------- 
            lda #$40		; start at $4000 (4Bit)
            sta sc_merk+1
            lda #$7d		; 32000 bytes
            sta ls_vekta8+1
            ldy #0
            sty ls_vekta8

hloop       lda (sc_merk),y	; count colors
            pha
            lsr
            lsr
            lsr
            lsr
            tax
            inc histlo,x
            bne ht1
            inc histhi,x
ht1         pla
            and #$0f
            tax
            inc histlo,x
            bne ht2
            inc histhi,x
ht2         jsr action		; display activity
            ldy #0
            inc sc_merk
            bne ht3
            inc sc_merk+1
ht3         lda ls_vekta8
            bne ht4
            dec ls_vekta8+1
ht4         dec ls_vekta8
            lda ls_vekta8
            ora ls_vekta8+1	; until 32000 bytes counted
            bne hloop
; --------------------------------------- 
            jsr done
            stx sc_merk
ht5         lda histhi,x
            tay
            lda histlo,x
            sty $62
            sta $63
            ldy #5
            lda #32
sr4         sta sy_numbers,y
            sta sc_movetab,y
            dey
            bpl sr4
            inc 1
            ldx #$90
            sec
            jsr $bc49
            jsr $bddf
            dec 1

            ldy #6		; display digits (# of pixels/color)
sr5         dey
            lda sy_numbers,y
            bne sr5
            ldx #6
sr6         dex
            sta sc_movetab,x
            dey
            bmi sr7
            lda sy_numbers,y
            bne sr6
sr7         lda sc_merk
            asl
            tay
            jsr gettab
            jsr gd_xtxout3
            inc sc_merk
            ldx sc_merk
            cpx #16
            bne ht5
            stx hdone
            clc			; until finished
            rts
; --------------------------------------- Apply new palette

applypal    jsr initgauge	; init activity display
            lda #125		; 125 pages (32000 bytes)
            sta cnt
            ldx #<($4000)	; from $4000 (4Bit)
            lda #>($4000)
            stx ls_vekta8
            sta ls_vekta8+1
            inx
            stx adcnt		; activity from scratch

            ldy #0
            sty ymerk
ap0         lda (ls_vekta8),y	; compare left nibble...
            pha
            lsr
            lsr
            lsr
            lsr
            pha
            tax
            lda paldflt,x
            cmp newpal,x	; ...whether modified
            beq ap1
            pla			; yes, replace
            lda newpal,x
            tax
            lda c64pal,x
            pha
ap1         pla
            asl
            asl
            asl
            asl
            sta joinbuf		; write back

            pla			; compare right nibble
            and #15
            pha
            tax
            lda paldflt,x
            cmp newpal,x	; whether modified
            beq ap2
            pla			; yes, replace
            lda newpal,x
            tax
            lda c64pal,x
            pha
ap2         pla
            ora joinbuf	

            sta (ls_vekta8),y	; write back
            jsr action		; activity
            inc ymerk
            ldy ymerk		; one page processed?
            bne ap0		; no, loop
            inc ls_vekta8+1	; next page
            dec cnt		; count pages
            bne ap0
            jmp done		; close activity display

; --------------------------------------- Init variables for Join and Swap

joininit    lda #0		; set flag: get source colors
            sta joinflag
            sta join1		; init variables
            sta join2
            sta joins
            sta sc_stop
            ldx #15		; clear mark table
jn1         lda #0
            sta jointab,x
            lda paldflt,x
            sta newpal,x
            dex
            bpl jn1
            rts
; --------------------------------------- Event: Join

ev_join     jsr joininit	; init variables
            lda sc_screenvek	; save vector to current screenlist
            pha
            lda sc_screenvek+1
            pha
            ldx #<(joinlst)	; display new reqester (within the old one)
            ldy #>(joinlst)
sw0         jsr gd_screen
            jsr gd_eloop		; wait for clicks
            pla			; restore old screenlist
            sta sc_screenvek+1
            pla 
            sta sc_screenvek
            lda sc_stop		; break? (STOP/Cancel?)
            beq jn0
            jsr blankscr1	; yes, just blank message
            clc			; finish, stay in requester
            rts

jn0         jsr applypal	; no, modify 4Bit data
            jsr blankscr1	; blank new requester
            jmp evhist		; compute new histogram, finish

; --------------------------------------- Event: Swap

evswap      jsr joininit
            lda sc_screenvek	; save vector to current screenlist
            pha
            lda sc_screenvek+1
            pha
            ldx #<(swaplst)	; display new reqester (within the old one)
            ldy #>(swaplst)
            bne sw0

; --------------------------------------- Subevent: Set Swap Colors

se_setsw    lda sc_merk		; which line did you click?
            sta joins
            sec
            sbc #5		; ...is now number of color
            ldx sc_stop		; Cancel/STOP?
            bne sw4		; yes, finish
            ldx joinflag	; no, get source colors?
            bne sw5
            sta join1		; yes, store number
            jsr blankscr2	; blank lower right
            beq sw1		; unconditional branch

sw5         sta join2		; no, get target color, store number
sw1         lda joins
            sta sc_zl
            ldx #20		; column 20, width/height 1
            stx sc_sp
            ldx #1
            stx sc_br
            stx sc_ho
            dex
            stx sc_loop		; care for text mode
            jsr gd_initmove	; compute screen address (returns .y=0)
            ldx joinflag	; get source colors?
            beq sw2
            iny			; no, left arrow
sw2         lda arrows,y	; yes, right arrow
            jsr gd_fi0		; write to screen
            ldx #3		; highlite it
            jsr gd_fcol

            lda joinflag	; get source colors?
            beq sw3

            sta gr_redisp		; no, Target, set re-render flag
            ldy join2		; load target color index to .a
            lda paldflt,y
            pha
            ldx join1
            lda paldflt,x
            sta newpal,y
            pla
            sta newpal,x
sw4         sec
            rts

sw3         inc joinflag	; yes, switch to target
            clc 
            rts

; --------------------------------------- Event: Rate

evrate      jsr initgauge
            jsr done
            clc 
            rts

; --------------------------------------- Subevent: De-Select colors

se_deslctj  lda #2		; set flag
            sta joinflag
            clc 
            rts

; --------------------------------------- 

deselect    lda #32		; blank position
            jsr gd_fi0		; write to screen
            lda joins		; any colors marked?
            beq sj8		; no, leave
            ldx join2		; index to color
            lda jointab,x	; already marked?
            beq sj8		; no, leave
            dec joins		; yes, unmark
            dec jointab,x
sj8         lda #0		; re-adjust flag
            sta joinflag
            clc
            rts

; --------------------------------------- Subevent: Select Target color for Join

se_targetj  lda joins		; already colors selected?
            beq tg0
            inc joinflag	; yes, switch to target
            jsr blankscr2	; blank lower right
tg0         clc
            rts

; --------------------------------------- Subevent: Cancel Join

se_cancelj  inc sc_stop		; set flag
            sec
            rts

; --------------------------------------- Subevent: Set Join Colors

se_setj     lda sc_merk		; which line did you click?
            sta sc_zl
            sec
            sbc #5		; ...is now number of color
            ldx sc_stop		; Cancel/STOP?
            bne sj4		; yes, finish
            ldx joinflag	; no, get source colors?
            bne sj0
            sta join1		; yes, store number
            jmp sj1

sj0         sta join2		; no, get target color, store number
sj1         ldx #20		; column 20, width/height 1
            stx sc_sp
            ldx #1
            stx sc_br
            stx sc_ho
            dex
            stx sc_loop		; care for text mode
            jsr gd_initmove	; compute screen address (returns .y=0)
            ldx joinflag	; get source colors?
            beq sj2
            cpx #2 		; deselect?
            beq deselect        ; yes, branch
            iny			; no, left arrow
sj2         lda arrows,y	; yes, right arrow
            jsr gd_fi0		; write to screen
            ldx #3		; highlite it
            jsr gd_fcol

            lda joinflag	; get source colors?
            beq sj3

            sta gr_redisp		; no, Target, set re-render flag
            ldx join2		; load target color index to .y
            ldy paldflt,x
            ldx #15		; counter, 15 downto 0
            stx joins
sj7         ldx joins
            lda jointab,x	; marked color?
            beq sj6
            tya			; yes, write target to modified palette
            sta newpal,x
sj6         dec joins
            bpl sj7		; until finished
sj4         sec
            rts

sj3         lda joins		; yes, (get source) how many colors marked?
            cmp #15		; maximum is 15
            beq sj5
            ldx join1		; mark color
            lda jointab,x	; already marked?
            bne sj5
            inc joins		; no, count marks
            inc jointab,x	; mark
sj5         clc
            rts

; --------------------------------------- Blank Screen area

blankscr1   ldy #44		; blank new requester
            .by $2c
blankscr2   ldy #46		; blank message
            jsr settab
            lda #0
            sta sc_loop
            jsr gettab
            lda #32
            jmp gd_fi0

; --------------------------------------- Standard C64 Palette
;
paldflt     .by 00,06,09,11,02,04,08,12,14,10,05,15,03,07,13,01
newpal      .by 00,06,09,11,02,04,08,12,14,10,05,15,03,07,13,01
c64pal      .by 00,15,04,12,05,10,01,13,06,02,09,03,07,14,08,11
jointab     .by 00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00
joins       .by 0
list        .wo 0
;
arrows      .by 94,91

; --------------------------------------- Screenlist for Histogram

hstlst      .by 0
            .by 0,2,36,25,$91,0,0
            .ts "Histogram@"
box         .by 4,3,14,18,$20,0,0
            .by 10,31,6,3,$c0,<(evview),>(evview)
            .ts "View@"
            .by 13,31,6,3,$c0,<(evswap),>(evswap)
            .ts "Swap@"
            .by 16,31,6,3,$c0,<(ev_join),>(ev_join)
            .ts "Join@"
            .by 19,31,6,3,$c0,<(evexit),>(evexit)
            .ts "Exit@"
            .by 22,3,34,3,$0c,0,0
            .by $c0,2,3,6
            .ts "Colors@"
            .by $c0,2,11,3
            .ts "Pix@"
            .by $c0,04,3,7
            .ts "  blk"
            .by          224,224,0
            .by $c0,05,3,7
            .ts "  blu"
            .by          225,225,0
            .by $c0,06,3,7
            .ts "  bwn"
            .by          226,226,0
            .by $c0,07,3,7
            .ts "  gr1"
            .by          227,227,0
            .by $c0,08,3,7
            .ts "  red"
            .by          228,228,0
            .by $c0,09,3,7
            .ts "  pur"
            .by          229,229,0
            .by $c0,10,3,7
            .ts "  ora"
            .by          230,230,0
            .by $c0,11,3,7
            .ts "  gr2"
            .by          231,231,0
            .by $c0,12,3,7
            .ts "  lbl"
            .by          232,232,0
            .by $c0,13,3,7
            .ts "  lrd"
            .by          233,233,0
            .by $c0,14,3,7
            .ts "  grn"
            .by          234,234,0
            .by $c0,15,3,7
            .ts "  gr3"
            .by          235,235,0
            .by $c0,16,3,7
            .ts "  cya"
            .by          236,236,0
            .by $c0,17,3,7
            .ts "  yel"
            .by          237,237,0
            .by $c0,18,3,7
            .ts "  lgr"
            .by          238,238,0
            .by $c0,19,3,7
            .ts "  wht"
            .by          239,239,0
            .by $80

; --------------------------------------- Screenlist for Join

joinlst     .by 0
            .by 4,18,5,18,$70,<(se_setj),>(se_setj)
            .by 07,23,8,3,$c0,<(se_targetj),>(se_targetj)
            .ts "Target@"
            .by 10,23,8,3,$c0,<(se_deslctj),>(se_deslctj)
            .ts "DeSlct@"
            .by 13,23,8,3,$c0,<(se_cancelj),>(se_cancelj)
            .ts "Cancel@"
            .by $c0,2,18,3,31,31,31,0
            .by $c0,3,23,5
            .ts "Click@"
            .by $c0,4,22,8
            .ts "in here.@"
            .by $c0,15,23,6
            .ts "Select@"
            .by $c0,16,23,6
            .ts "one or@"
            .by $c0,17,23,4
            .ts "more@"
            .by $c0,18,23,6
            .ts "colors@"
            .by $c0,19,23,6
            .ts "to re-@
            .by $c0,20,23,5
            .ts "move.@"
            .by $80

; --------------------------------------- 

swaplst     .by 0
            .by 4,18,5,18,$70,<(se_setsw),>(se_setsw)
            .by 13,23,8,3,$c0,<(se_cancelj),>(se_cancelj)
            .ts "Cancel@"
            .by $c0,2,18,3,31,31,31,0
            .by $c0,3,23,5
            .ts "Click@"
            .by $c0,4,22,8
            .ts "in here.@"
            .by $c0,15,23,6
            .ts "Select@"
            .by $c0,16,23,6
            .ts "colors@"
            .by $c0,17,23,7
            .ts "to swap@
            .by $80

; --------------------------------------- 

blk         .by 4,10,7,1
blu         .by 5,10,7,1
bwn         .by 6,10,7,1
gr1         .by 7,10,7,1
red         .by 8,10,7,1
pur         .by 9,10,7,1
ora         .by 10,10,7,1
gr2         .by 11,10,7,1
lbl         .by 12,10,7,1
lrd         .by 13,10,7,1
grn         .by 14,10,7,1
gr3         .by 15,10,7,1
cyn         .by 16,10,7,1
yel         .by 17,10,7,1
lgr         .by 18,10,7,1
wht         .by 19,10,7,1
black       .by 4,5,5,3
grau1       .by 7,5,5,3
grau2       .by 11,5,5,3
grau3       .by 15,5,5,3
white       .by 19,5,5,3
blnk        .by 2,17,15,21
blnk2       .by 15,23,9,8

; --------------------------------------- Activity (Gauge)

messout     ldx #<(message)
            ldy #>(message)
            jmp gd_xtxout2
;
tcopy       ldy #0
tc0         lda txt,x
            beq clrmess
            sta message,y
            inx
            iny
            bne tc0
;
action      dec adcnt
            bne ld4
            lda cntwert
            sta adcnt
            ldy offy
            ldx offx
            lda filltab,x
            sta mess,y
            jsr messout
            dec offx
            bpl ld4
            inc offy
            lda #7
            sta offx
ld4         rts
;
clrmess     ldx #20
            lda #32
cl0         sta mess,x
            dex
            bpl cl0
            ldy #0
            ldx #7
            sty offy
            stx offx
            rts
;
filltab     .by 160,93,103,127,126,124,105,109
;
cntwert     .by 200
;
txt         .ts " Working@"
            .ts " Done.  @"
message     .ts " Working   "
mess        .ts "                     @"

; ------------------------------------------ Display graphics

chkmod	    sei
	    ldx #0
            stx $01
	    lda #$d0		; check saver area
	    ldy #3
	    sty where
	    sta where+1
	    jsr getwhere
	    sta therev1		; vram1?
            lda #$e0		; check modifier area
	    sta where+1
	    jsr getwhere
	    sta therev2		; vram2?
            lda #$c0
            sta therec		; cram?
	    lda #$36
	    sta $01
	    cli
	    rts

getwhere    lda (where,x)
	    tay
            and #$40		; saver where saver should be?
	    beq chm0
	    lda #$d0
	    bne chm2
chm0	    tya
	    bpl chm1
	    lda #$c0
	    bne chm2
chm1	    lda #$e0
chm2	    rts

; ----------------------------------------- Counters

count       inc sc_vekt20
            bne cou5
            inc sc_vekt20+1
cou5        inc offx
            bne cou6
            inc offy
cou6        lda ls_vekta8
            bne cou7
            dec ls_vekta8+1
cou7        dec ls_vekta8
            lda ls_vekta8
            ora ls_vekta8+1
            rts

; ------------------------------------------ Redisplay routines

redis:  ldx gr_palette
        stx $d020
        jsr setcolors
        lda gr_cmode
        beq rp4
        lda #$18
        sta $d016
rp4:    lda #$1b
        sta $d018
        lda #$3b
        sta $d011
        lda gr_redisp 	; leave if flag set
        bne rp3

rp1:    lda sc_keyprs	; wait for stop key
        ora sc_stop
        beq rp1

rp2:    jsr getcolors
        jsr tmode
        ldx list
        ldy list+1
        jsr gd_screen
rp3:    clc
        rts

tmode:  ldx #$13
        lda #$1b
        stx $d018
        sta $d011
        lda #$08
        sta $d016
        lda sc_maincolor
        sta $d020
        sta $d021
        rts
; ------------------------------------------ 
setcveks: sei
        lda #$35
        sta 1
        lda #>(cstart)
        ldx #$d8
        bne scv0
; ------------------------------------------ 
setbveks: lda #>(vram1)
        ldx #4
        dec 1
scv0:   stx $b3
        ldy #0
        sty sc_merk
        sty $b2
        dey
; ------------------------------------------ 
setlast: sty gr_bkcol
        ldy #<(cstart)
        sty $20
        sta $21
        lda #<(500)
        sta $a8
        lda #>(500)
        sta $a9
        ldy #0
        rts
; ------------------------------------------ 
getcolors: jsr setcveks
stco:   lda ($b2),y
        sta sc_merk
        inc $b2
        bne stc0
        inc $b3
stc0:   lda ($b2),y
        lsr
        rol sc_merk
        lsr
        rol sc_merk
        lsr
        rol sc_merk
        lsr
        rol sc_merk
        lda sc_merk
        sta ($20),y
        jsr count
        bne stco
        jsr setbveks
stc1:   lda ($b2),y
        sta ($20),y
        jsr count
        bne stc1
        ldy gr_bkcol
        bpl scv1
        ldy #0
        lda #>(vram2)
        jsr setlast
        beq stc1
scv1:   lda #$36
        sta 1
        cli
        lda $d021
        and #15
        sta gr_bkcol
        rts
; ------------------------------------------ 
setcolors: lda gr_bkcol
        sta $d021
        pha
        jsr setcveks
stc2:   sty sc_merk
        lda ($20),y
        lsr
        rol sc_merk
        lsr
        rol sc_merk
        lsr
        rol sc_merk
        lsr
        rol sc_merk
        sta ($b2),y
        inc $b2
        bne stc3
        inc $b3
stc3:   lda sc_merk
        sta ($b2),y
        jsr count
        bne stc2
        jsr setbveks
stc4:   lda ($20),y
        sta ($b2),y
        jsr count
        bne stc4
        ldy gr_bkcol
        bpl scv1
        pla
        tay
        lda #>(vram2)
        jsr setlast
        beq stc4

; ------------------------------------------ Switch Graphics/Text

evview: lda gr_redisp
        pha
        ldx #1
        stx gr_redisp
        dex
        stx sc_stop
        jsr redis
        jsr rp1
        pla
        sta gr_redisp		; restore auto render 
        jmp showrequester	; redisplay color chooser

; --------------------------------------- 

modend      .en
