; RP6502 graphics statements.
; MODE 180 enables 320x180 bitmap (8bpp).
; MODE 240 enables 320x240 bitmap (4bpp).
; PSET x,y,c plots one pixel (c is 0..255, low nibble used in 4bpp mode).
; CLS clears the active bitmap plane to color 0.

.segment "CODE"

GFX_CANVAS_320X240 := 1
GFX_CANVAS_320X180 := 2
GFX_MODE_BITMAP    := 3
GFX_CFG_ADDR       := $FF00
GFX_FB_ADDR        := $0000

; ----------------------------------------------------------
; gfx_xreg_canvas -- xreg(1,0,0,canvas)
; A = canvas value
; Returns C=0 on success, C=1 on failure.
; ----------------------------------------------------------
gfx_xreg_canvas:
        sta gfx_tmp

        lda #RIA_OP_ZXSTACK
        sta RIA_OP

        lda #$01
        sta RIA_XSTACK            ; device 1 (VGA)
        stz RIA_XSTACK            ; channel 0
        stz RIA_XSTACK            ; address 0 (CANVAS)
        stz RIA_XSTACK            ; int high
        lda gfx_tmp
        sta RIA_XSTACK            ; int low
        lda #RIA_OP_XREG
        sta RIA_OP
        jsr RIA_SPIN
        cpx #$FF
        bne @ok
        cmp #$FF
        bne @ok
        sec
        rts
@ok:
        clc
        rts

; ----------------------------------------------------------
; gfx_xreg_mode3 -- xreg(1,0,1,3,options,cfg,0,0)
; A = options (8bpp:3, 4bpp:2)
; Returns C=0 on success, C=1 on failure.
; ----------------------------------------------------------
gfx_xreg_mode3:
        sta gfx_tmp

        lda #RIA_OP_ZXSTACK
        sta RIA_OP

        lda #$01
        sta RIA_XSTACK            ; device 1 (VGA)
        stz RIA_XSTACK            ; channel 0
        lda #$01
        sta RIA_XSTACK            ; address 1 (MODE)

        stz RIA_XSTACK            ; MODE high
        lda #GFX_MODE_BITMAP
        sta RIA_XSTACK            ; MODE low

        stz RIA_XSTACK            ; OPTIONS high
        lda gfx_tmp
        sta RIA_XSTACK            ; OPTIONS low

        lda #>GFX_CFG_ADDR
        sta RIA_XSTACK            ; CONFIG high
        lda #<GFX_CFG_ADDR
        sta RIA_XSTACK            ; CONFIG low

        stz RIA_XSTACK            ; PLANE high
        stz RIA_XSTACK            ; PLANE low
        stz RIA_XSTACK            ; BEGIN high
        stz RIA_XSTACK            ; BEGIN low
        stz RIA_XSTACK            ; END high
        stz RIA_XSTACK            ; END low

        lda #RIA_OP_XREG
        sta RIA_OP
        jsr RIA_SPIN
        cpx #$FF
        bne @ok
        cmp #$FF
        bne @ok
        sec
        rts
@ok:
        clc
        rts

; ----------------------------------------------------------
; gfx_write_mode3_config
; Writes vga_mode3_config_t at XRAM GFX_CFG_ADDR:
;   x_wrap=0, y_wrap=0, x_px=0, y_px=0,
;   width=320, height=(180|240), data_ptr=$2000, palette_ptr=$FFFF.
; A = height (180 or 240)
; ----------------------------------------------------------
gfx_write_mode3_config:
        sta gfx_tmp

        lda #$01
        sta RIA_STEP0
        lda #<GFX_CFG_ADDR
        sta RIA_ADDR0
        lda #>GFX_CFG_ADDR
        sta RIA_ADDR0+1

        stz RIA_RW0               ; x_wrap
        stz RIA_RW0               ; y_wrap

        stz RIA_RW0               ; x_px low
        stz RIA_RW0               ; x_px high
        stz RIA_RW0               ; y_px low
        stz RIA_RW0               ; y_px high

        lda #$40                  ; width 320
        sta RIA_RW0               ; width low
        lda #$01
        sta RIA_RW0               ; width high

        lda gfx_tmp
        sta RIA_RW0               ; height low
        stz RIA_RW0               ; height high

        lda #<GFX_FB_ADDR
        sta RIA_RW0               ; data_ptr low
        lda #>GFX_FB_ADDR
        sta RIA_RW0               ; data_ptr high

        lda #$FF
        sta RIA_RW0               ; palette_ptr low
        sta RIA_RW0               ; palette_ptr high
        rts

; ----------------------------------------------------------
; MODE <expr>
;   MODE 180 -> 320x180 bitmap, 8bpp
;   MODE 240 -> 320x240 bitmap, 4bpp
; ----------------------------------------------------------
MODE:
        jsr FRMNUM
        jsr GETADR                ; LINNUM = mode value
        lda LINNUM+1
        bne @bad

        lda LINNUM
        cmp #180
        beq @m180
        cmp #240
        beq @m240
@bad:
        ldx #ERR_ILLQTY
        jmp ERROR

@m180:
        lda #180
        jsr gfx_write_mode3_config
        lda #GFX_CANVAS_320X180
        jsr gfx_xreg_canvas
        bcs @bad
        lda #$03                  ; 8bpp
        jsr gfx_xreg_mode3
        bcs @bad
        lda #$01
        sta gfx_mode
        rts

@m240:
        lda #240
        jsr gfx_write_mode3_config
        lda #GFX_CANVAS_320X240
        jsr gfx_xreg_canvas
        bcs @bad
        lda #$02                  ; 4bpp
        jsr gfx_xreg_mode3
        bcs @bad
        lda #$02
        sta gfx_mode
        rts

; ----------------------------------------------------------
; CLS
;   Clear active graphics framebuffer to color 0.
; ----------------------------------------------------------
CLS:
        lda gfx_mode
        beq @done

        lda #$01
        sta RIA_STEP0
        lda #<GFX_FB_ADDR
        sta RIA_ADDR0
        lda #>GFX_FB_ADDR
        sta RIA_ADDR0+1

        ldx #225                  ; 320*180 bytes
        lda gfx_mode
        cmp #$01
        beq @have_pages
        ldx #150                  ; 320*240/2 bytes
@have_pages:
        lda #$00
@page:
        ldy #$00
@byte:
        sta RIA_RW0
        iny
        bne @byte
        dex
        bne @page
@done:
        rts

; ----------------------------------------------------------
; gfx_validate_x_current
;   Validate current gfx_xlo/gfx_xhi is in range 0..319.
;   Returns C=0 if valid, C=1 if invalid.
; ----------------------------------------------------------
gfx_validate_x_current:
        lda gfx_xhi
        beq @ok
        cmp #$01
        bne @bad
        lda gfx_xlo
        cmp #$40
        bcc @ok
@bad:
        sec
        rts
@ok:
        clc
        rts

; ----------------------------------------------------------
; gfx_validate_y_current
;   Validate current gfx_y against active mode height.
;   Returns C=0 if valid, C=1 if invalid.
; ----------------------------------------------------------
gfx_validate_y_current:
        lda gfx_mode
        cmp #$01
        bne @chk240
        lda gfx_y
        cmp #180
        bcc @ok
        sec
        rts
@chk240:
        lda gfx_y
        cmp #240
        bcc @ok
        sec
        rts
@ok:
        clc
        rts

; ----------------------------------------------------------
; gfx_plot_current
;   Plot one pixel using gfx_xlo/gfx_xhi, gfx_y, gfx_color.
; ----------------------------------------------------------
gfx_plot_current:
        ; offset = x + y*256 + y*64
        lda gfx_xlo
        sta gfx_offlo
        lda gfx_xhi
        sta gfx_offhi

        lda gfx_y
        clc
        adc gfx_offhi
        sta gfx_offhi

        lda gfx_y
        sta gfx_tmp
        stz gfx_mulhi
        ldx #$06
@mul64:
        asl gfx_tmp
        rol gfx_mulhi
        dex
        bne @mul64

        clc
        lda gfx_offlo
        adc gfx_tmp
        sta gfx_offlo
        lda gfx_offhi
        adc gfx_mulhi
        sta gfx_offhi

        lda gfx_mode
        cmp #$01
        beq @plot8

        ; 4bpp: byte_index = offset>>1
        lsr gfx_offhi
        ror gfx_offlo

        clc
        lda gfx_offlo
        adc #<GFX_FB_ADDR
        sta RIA_ADDR0
        lda gfx_offhi
        adc #>GFX_FB_ADDR
        sta RIA_ADDR0+1

        stz RIA_STEP0
        lda RIA_RW0
        sta gfx_tmp

        lda gfx_color
        and #$0F
        sta gfx_color

        lda gfx_xlo
        and #$01
        bne @plot4_odd

        ; even x uses high nibble
        lda gfx_color
        asl
        asl
        asl
        asl
        sta gfx_mulhi
        lda gfx_tmp
        and #$0F
        ora gfx_mulhi
        sta RIA_RW0
        rts

@plot4_odd:
        lda gfx_tmp
        and #$F0
        ora gfx_color
        sta RIA_RW0
        rts

@plot8:
        clc
        lda gfx_offlo
        adc #<GFX_FB_ADDR
        sta RIA_ADDR0
        lda gfx_offhi
        adc #>GFX_FB_ADDR
        sta RIA_ADDR0+1

        lda gfx_color
        sta RIA_RW0
        rts

; ----------------------------------------------------------
; GFX subcommand dispatcher
;   GFX M,<mode>        (mode: 180 or 240)
;   GFX C               (clear)
;   GFX P,<x>,<y>,<c>   (pixel)
;   GFX H,<x1>,<y>,<x2>,<c>
;   GFX V,<x>,<y1>,<y2>,<c>
;   GFX R,<x1>,<y1>,<x2>,<y2>,<c>
; ----------------------------------------------------------
GFX:
        cmp #'M'
        beq @mode
        cmp #'C'
        beq @cls
        cmp #'P'
        beq @pset
        cmp #'H'
        beq @hline
        cmp #'V'
        beq @vline
        cmp #'R'
        beq @rect
        jmp GFX_BAD

@mode:
        jsr CHRGET
        lda #','
        jsr SYNCHR
        jmp MODE

@cls:
        jsr CHRGET
        beq @cls_ok
        jmp GFX_BAD
@cls_ok:
        jmp CLS

@pset:
        jsr CHRGET
        lda #','
        jsr SYNCHR
        jmp PSET

@hline:
        jsr CHRGET
        lda #','
        jsr SYNCHR
        jmp HLINE

@vline:
        jsr CHRGET
        lda #','
        jsr SYNCHR
        jmp VLINE

@rect:
        jsr CHRGET
        lda #','
        jsr SYNCHR
        jmp GFX_RECT

; ----------------------------------------------------------
; PSET x,y,c
; ----------------------------------------------------------
PSET:
        lda gfx_mode
        bne @mode_ok
        ldx #ERR_ILLQTY
        jmp ERROR

@mode_ok:
        jsr FRMNUM
        jsr GETADR
        lda LINNUM
        sta gfx_xlo
        lda LINNUM+1
        sta gfx_xhi

        jsr COMBYTE               ; y in X
        stx gfx_y

        jsr COMBYTE               ; color in X
        stx gfx_color

        jsr gfx_validate_x_current
        bcc :+
        jmp GFX_BAD
:       
        jsr gfx_validate_y_current
        bcc :+
        jmp GFX_BAD
:       
        jsr gfx_plot_current
        rts

; ----------------------------------------------------------
; HLINE x1,y,x2,c
; ----------------------------------------------------------
HLINE:
        lda gfx_mode
        bne @mode_ok
        ldx #ERR_ILLQTY
        jmp ERROR

@mode_ok:
        jsr FRMNUM
        jsr GETADR
        lda LINNUM
        sta gfx_xlo
        lda LINNUM+1
        sta gfx_xhi

        jsr COMBYTE               ; y in X
        stx gfx_y

        jsr CHKCOM
        jsr FRMNUM
        jsr GETADR                ; x2 in LINNUM
        lda LINNUM
        sta gfx_x2lo
        lda LINNUM+1
        sta gfx_x2hi

        jsr COMBYTE               ; color in X
        stx gfx_color

        jsr gfx_validate_x_current
        bcc :+
        jmp GFX_BAD
:       
        jsr gfx_validate_y_current
        bcc :+
        jmp GFX_BAD
:       

        ; validate x2 in gfx_x2lo/gfx_x2hi
        lda gfx_x2hi
        beq @x2_ok
        cmp #$01
        beq :+
        jmp GFX_BAD
:       
        lda gfx_x2lo
        cmp #$40
        bcc @x2_ok
        jmp GFX_BAD
@x2_ok:

        ; require x1 <= x2
        lda gfx_xhi
        cmp gfx_x2hi
        bcc @draw
        beq :+
        jmp GFX_BAD
:       
        lda gfx_xlo
        cmp gfx_x2lo
        bcc @draw
        beq @draw
        jmp GFX_BAD

@draw:
        jsr gfx_plot_current
        lda gfx_xhi
        cmp gfx_x2hi
        bne @step
        lda gfx_xlo
        cmp gfx_x2lo
        beq @done
@step:
        inc gfx_xlo
        bne @draw
        inc gfx_xhi
        bra @draw
@done:
        rts

; ----------------------------------------------------------
; GFX_RECT x1,y1,x2,y2,c
; ----------------------------------------------------------
GFX_RECT:
        lda gfx_mode
        bne @mode_ok
        ldx #ERR_ILLQTY
        jmp ERROR

@mode_ok:
        jsr FRMNUM
        jsr GETADR
        lda LINNUM
        sta gfx_x1lo
        lda LINNUM+1
        sta gfx_x1hi

        jsr COMBYTE               ; y1 in X
        stx gfx_y1

        jsr CHKCOM
        jsr FRMNUM
        jsr GETADR                ; x2 in LINNUM
        lda LINNUM
        sta gfx_x2lo
        lda LINNUM+1
        sta gfx_x2hi

        jsr COMBYTE               ; y2 in X
        stx gfx_y2

        jsr COMBYTE               ; color in X
        stx gfx_color

        ; validate x1
        lda gfx_x1lo
        sta gfx_xlo
        lda gfx_x1hi
        sta gfx_xhi
        jsr gfx_validate_x_current
        bcc :+
        jmp GFX_BAD
:
        ; validate y1
        lda gfx_y1
        sta gfx_y
        jsr gfx_validate_y_current
        bcc :+
        jmp GFX_BAD
:
        ; validate x2
        lda gfx_x2lo
        sta gfx_xlo
        lda gfx_x2hi
        sta gfx_xhi
        jsr gfx_validate_x_current
        bcc :+
        jmp GFX_BAD
:
        ; validate y2
        lda gfx_y2
        sta gfx_y
        jsr gfx_validate_y_current
        bcc :+
        jmp GFX_BAD
:

        ; require x1 <= x2
        lda gfx_x1hi
        cmp gfx_x2hi
        bcc :+
        beq :++
        jmp GFX_BAD
:
        bra @xy_ok
:
        lda gfx_x1lo
        cmp gfx_x2lo
        bcc @xy_ok
        beq @xy_ok
        jmp GFX_BAD

@xy_ok:
        ; require y1 <= y2
        lda gfx_y1
        cmp gfx_y2
        bcc @draw_rows
        beq @draw_rows
        jmp GFX_BAD

@draw_rows:
        lda gfx_y1
        sta gfx_y

@row:
        lda gfx_x1lo
        sta gfx_xlo
        lda gfx_x1hi
        sta gfx_xhi

@col:
        jsr gfx_plot_current
        lda gfx_xhi
        cmp gfx_x2hi
        bne @step_col
        lda gfx_xlo
        cmp gfx_x2lo
        beq @next_row
@step_col:
        inc gfx_xlo
        bne @col
        inc gfx_xhi
        bra @col

@next_row:
        lda gfx_y
        cmp gfx_y2
        beq @done
        inc gfx_y
        bra @row

@done:
        rts

; ----------------------------------------------------------
; VLINE x,y1,y2,c
; ----------------------------------------------------------
VLINE:
        lda gfx_mode
        bne @mode_ok
        ldx #ERR_ILLQTY
        jmp ERROR

@mode_ok:
        jsr FRMNUM
        jsr GETADR
        lda LINNUM
        sta gfx_xlo
        lda LINNUM+1
        sta gfx_xhi

        jsr COMBYTE               ; y1 in X
        stx gfx_y

        jsr CHKCOM
        jsr FRMNUM
        jsr GETADR                ; y2 in LINNUM
        lda LINNUM+1
        beq :+
        jmp GFX_BAD
:       
        lda LINNUM
        sta gfx_y2

        jsr COMBYTE               ; color in X
        stx gfx_color

        jsr gfx_validate_x_current
        bcc :+
        jmp GFX_BAD
:       
        jsr gfx_validate_y_current
        bcc :+
        jmp GFX_BAD
:       

        ; validate y2
        lda gfx_y
        pha
        lda gfx_y2
        sta gfx_y
        jsr gfx_validate_y_current
        pla
        sta gfx_y
        bcc :+
        jmp GFX_BAD
:       

        ; require y1 <= y2
        lda gfx_y
        cmp gfx_y2
        bcc @draw
        beq @draw
        jmp GFX_BAD

@draw:
        jsr gfx_plot_current
        lda gfx_y
        cmp gfx_y2
        beq @done
        inc gfx_y
        bra @draw
@done:
        rts

GFX_BAD:
        ldx #ERR_ILLQTY
        jmp ERROR
