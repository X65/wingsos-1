.petscii
.include "godotlib.lib"

; ---------------------------
;
;    ldr.Artist64
;  Loader for Artist64 multicolor pictures
;
;    1.00: 13.05.02, first release
;
; ---------------------------

         .ob "l_artist,p,w"
;
            .ba $c000
;
            .eq byte		=$34
            .eq cnt		=byte
            .eq gmode		=$35
            .eq vr		=$36
            .eq cr		=$38
            .eq vv		=$3a
            .eq status		=$90

            .eq offx		=$b2
            .eq offy		=offx+1
;
            .eq vrbuf		=$c600
            .eq crbuf		=vrbuf+1000
            .eq col0		=vrbuf+2000
            .eq sprite		=$d015
;
; --------------------------- Header

            jmp start
            .by $80
            .by $00,$00
            .by <(modend),>(modend)
            .by $00,$00
;
;              0123456789abcdef
;
            .tx "Artist64        "
            .tx "1.00"
            .tx "13.05.02"
            .tx "A.Dettke        "

; --------------------------- Main
;
jerror      jmp error
;
start       jsr getname		; store name
;
stt2        jsr gd_xopen	; open file
            jsr basin		; skip start address ($7800)
            bcs jerror
            jsr basin
            bcs jerror

; --------------------------- Get Multicolor Image

stt3        jsr gd_clrms	; clear message bar

            lda #50		; activity counter to 50
            sta cntwert
            sta $ff
            ldx #30		; "Bitmap"
            jsr tcopy
;
            lda #<(8192)	; count 8192 bytes (bitmap)
            sta ls_vekta8
            lda #>(8192)
            sta ls_vekta8+1
            ldx #0		; destination $4000
            ldy #$40
            stx sc_texttab
            sty sc_texttab+1
;
loop        jsr basin		; get bitmap
jerr2       bcs jerror
            sta byte
            jsr action
            ldy #0
            ldx #4		; convert to 4bit indexes
bloop       lda #0
            asl byte
            rol
            asl byte
            rol
            sta (sc_texttab),y
            inc sc_texttab
            bne sk
            inc sc_texttab+1
sk          dex
            bne bloop
            lda ls_vekta8
            bne sk1
            dec ls_vekta8+1
sk1         dec ls_vekta8
            lda ls_vekta8
            ora ls_vekta8+1
            beq sk2
            lda status
            beq loop
;
sk2         lda #7		; get multi mode colors
            sta cntwert
            sta $ff
            ldx #0		; out: "Colors 1"
            jsr tcopy

            lda #<(1024)	; count 1024 bytes (video RAM)
            sta ls_vekta8
            lda #>(1024)
            sta ls_vekta8+1
            lda #<(vrbuf)
            sta sc_texttab
            lda #>(vrbuf)
            sta sc_texttab+1
;
loop1       jsr basin		; get color RAM (no conversion)
jerr3       bcs jerr2
            sta (sc_texttab),y
            jsr action
            ldy #0
            inc sc_texttab
            bne sk3
            inc sc_texttab+1
sk3         lda ls_vekta8
            bne sk4
            dec ls_vekta8+1
sk4         dec ls_vekta8
            lda ls_vekta8
            ora ls_vekta8+1
            beq sk21
            jmp loop1
;
sk21        lda #7		; out: "Colors 2"
            sta cntwert
            sta $ff
            ldx #10
            jsr tcopy

            lda #<(1024)	; count 1024 bytes (color RAM)
            sta ls_vekta8
            lda #>(1024)
            sta ls_vekta8+1
            lda #<(crbuf)
            sta sc_texttab
            lda #>(crbuf)
            sta sc_texttab+1
;
loop2       jsr basin		; get color RAM (no conversion)
            bcs jerr3
            sta (sc_texttab),y
            jsr action
            ldy #0
            inc sc_texttab
            bne sk31
            inc sc_texttab+1
sk31        lda ls_vekta8
            bne sk41
            dec ls_vekta8+1
sk41        dec ls_vekta8
            lda ls_vekta8
            ora ls_vekta8+1
            beq sk42
            jmp loop2
;
sk42        lda crbuf+$03ff	; get background color
            and #15		; isolate color value
            sta col0

sk5         jsr gd_xclose	; close file

            lda #<(vrbuf)	; convert to 4bit (set start addresses)
            sta vr
            lda #>(vrbuf)
            sta vr+1
            lda #<(crbuf)
            sta cr
            lda #>(crbuf)
            sta cr+1
            lda #<($4000)
            sta sc_texttab
            lda #>($4000)
            sta sc_texttab+1
            lda #<(1000)	; count 1000
            sta ls_vekta8
            lda #>(1000)
            sta ls_vekta8+1
;
            lda #200
            sta cntwert
            sta $ff
            ldx #20
            jsr tcopy
;
loop3       lda (vr),y		; convert video RAM colors to 4bit
            pha
            lsr
            lsr
            lsr
            lsr
            sta col0+1
            pla
            and #$0f
            sta col0+2
            lda (cr),y		; convert color RAM colors to 4bit
            and #$0f
            sta col0+3
            lda #32
            sta cnt
bloop1      jsr action
            ldy #0
            lda (sc_texttab),y	; get values from 4bit (0-3)
            tax
            lda col0,x		; get color values from table
            tax
            lda dnib,x		; get conversion values to GoDot palette from table
            sta (sc_texttab),y	; write back to 4bit (double nibbles)
            inc sc_texttab	; advance
            bne sk6
            inc sc_texttab+1
sk6         dec cnt		; one tile
            bne bloop1
            inc vr		; next tile
            bne sk7
            inc vr+1
sk7         inc cr
            bne sk8
            inc cr+1
sk8         lda ls_vekta8	; 1000 tiles
            bne sk9
            dec ls_vekta8+1
sk9         dec ls_vekta8
            lda ls_vekta8
            ora ls_vekta8+1
            bne loop3

; --------------------------- Close File

sk11        ldx #30		; reset text to default ("Bitmap")
            jsr tcopy
            jsr setinfo		; set filename
;
sk10        jsr gd_xmess	; error message from drive
            jsr gd_spron	; sprite pointer on
            sec			; leave loader
            rts

; --------------------------- 
error       jsr gd_xclose
            jsr sk10
            clc
            rts

; --------------------------- Activity Display

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
action      dec $ff
            bne ld4
            lda cntwert
            sta $ff
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
cntwert     .by 50
;
txt         .ts " Colors 1@"	; 0
            .ts " Colors 2@"	; 10
            .ts " Convert @"	; 20
            .ts " Bitmap  @"    ; 30
            .ts " Move    @"    ; 40
;
message     .ts " Bitmap    "
mess        .tx "                     "
            .by 0

; --------------------------- Palette Table for MC double pixels
;
dnib        .by $00,$ff,$44,$cc,$55,$aa,$11,$dd
            .by $66,$22,$99,$33,$77,$ee,$88,$bb

; --------------------------- Save Filename
;
getname     ldx #0
si0         lda ls_lastname,x
            beq si1
            sta nbuf,x
            inx
            cpx #16
            bcc si0
si1         rts
;
; --------------------------- Image Information

setinfo     jsr setname
            jsr setloader
            jsr setmode
            jmp setdata
;
setname     lda #0
            ldx #<(ls_picname)
            ldy #>(ls_picname)
            bne si3
setloader   lda #17
            ldx #<(ls_iloader)
            ldy #>(ls_iloader)
            bne si3
setmode     lda #25
            ldx #<(ls_imode)
            ldy #>(ls_imode)
            bne si3
setdata     lda #33
            ldx #<(ls_idrive)
            ldy #>(ls_idrive)
si3         stx sc_texttab
            sty sc_texttab+1
            tax
            ldy #0
si4         lda nbuf,x
            beq si5
            sta (sc_texttab),y
            inx
            iny
            bne si4
si5         rts
;
nbuf        .by 32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,0
            .ts "Artist @"		; 17
modetx      .ts "160x200@"		; 25
datatype    .ts "Color@"		; 33

modend      .en
