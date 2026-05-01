; Picocomputer 6502 BASIC audio engine.
;
; Phase 1: audio_init + audio_allstop (safety skeleton).
; Phase 3: SFX_CMD — single-keyword subcommand dispatcher (GFX pattern).
;
; All audio commands go through one token (SFX) to avoid token-table
; instability. Each subcommand handler is a separate non-local label so that
; local branch targets stay within ±127 bytes (same technique as GFX).
;
; Syntax:
;   SFX n[,v]            play one-shot effect n [on voice v]
;   SFX STOP             silence all voices  (STOP tokenised → TOKEN_STOP)
;   SFX VOL,n            set master SFX volume 0..255
;   SFX BANK,n           select SFX bank
;   SFX STATUS           print audio state
;   SFX TEMPO,bpm        set music tempo 30..300
;   SFX VOICE,v,inst     set voice v (0..2) instrument
;   SFX NOTE,v,p,d[,vel] play note (Phase 4: will output PSG)
;
; Phase 4: add PSG register writes to audio_allstop, sfx_play, sfx_note.

.segment "CODE"

AUDIO_PSG_ADDR := $FD00

; ----------------------------------------------------------------------------
; audio_init -- Initialize all audio state to safe defaults.
; Called from COLD_START (init.s). Preserves no registers.
; ----------------------------------------------------------------------------
audio_init:
        jsr audio_psg_enable
        stz aud_enable
        lda #120              ; default TEMPO = 120 BPM
        sta aud_tempo_lo
        stz aud_tempo_hi
        stz aud_sfx_bank
        lda #$7F              ; default SFX master volume = 127
        sta aud_sfx_vol
        stz aud_v0_inst
        stz aud_v1_inst
        stz aud_v2_inst
        lda #$0F              ; default per-voice velocity = max (0..15)
        sta aud_v0_vel
        sta aud_v1_vel
        sta aud_v2_vel
        rts

; ----------------------------------------------------------------------------
; audio_allstop -- Silence all PSG voices immediately.
; Preserves X (ERROR uses X as the error-message table offset).
; Phase 4: add PSG register writes for voices 0..2.
; ----------------------------------------------------------------------------
audio_allstop:
        phx
        ldx #$00
@loop:
        jsr audio_psg_gate_off_voice
        inx
        cpx #$03
        bcc @loop
        stz aud_enable        ; mark all voices idle
        plx
        rts

; ============================================================================
; SFX_CMD -- dispatcher only.
; A = first char after SFX token; TXTPTR → that char.
; bne :+ / jmp pattern keeps every branch within ±127 bytes.
; ============================================================================
SFX_CMD:
        cmp #TOKEN_STOP           ; SFX STOP (STOP is tokenised)
        bne :+
        ; Move past the STOP token so TXTPTR lands on ':' or end-of-line
        ; before returning to the outer statement loop.
        jsr CHRGET
        jmp audio_allstop
:
        cmp #'S'
        bne :+
        ; @SFX path can present raw text (S/T/O/P). Distinguish STOP from
        ; STATUS by peeking ahead from TXTPTR, which points at this 'S'.
        ldy #$01
        lda (TXTPTR),y
        cmp #'T'
        bne @s_status
        iny
        lda (TXTPTR),y
        cmp #'O'
        bne @s_status
        iny
        lda (TXTPTR),y
        cmp #'P'
        bne @s_status
        ; Ensure STOP ends as a word, not STOP... prefix.
        iny
        lda (TXTPTR),y
        beq @s_stop
        cmp #':'
        beq @s_stop
        cmp #' '
        bne @s_status
@s_stop:
        ; Consume T/O/P and then advance once more so TXTPTR lands on the
        ; statement terminator (':' or 0), matching normal handler contract.
        jsr CHRGET
        jsr CHRGET
        jsr CHRGET
        jsr CHRGET
        jmp audio_allstop
@s_status:
        jmp sfx_status
:
        cmp #'T'
        bne :+
        jmp sfx_tempo
:
        cmp #'N'
        bne :+
        jmp sfx_note
:
        cmp #'V'
        bne :+
        jmp sfx_v
:
        cmp #'B'
        bne :+
        jmp sfx_bank
:
        cmp #'S'
        bne :+
        jmp sfx_status
:
        ; Not a recognised subcommand letter → play numeric effect id.

; ============================================================================
; sfx_play -- SFX n[,v]
; ============================================================================
sfx_play:
        jsr GETBYT                ; X = effect id 0..255
        stx aud_arg1
        ldx #$00                  ; default auto voice for now
        stx aud_arg0
        jsr CHRGOT
        beq @emit
        cmp #','
        bne @emit
        jsr COMBYTE               ; X = voice 0..2
        cpx #$03
        bcs @qty
        stx aud_arg0
@emit:
        lda aud_arg1
        and #$7F
        sta aud_arg1
        jsr audio_pitch_to_freq
        jsr audio_load_default_vel
        jsr audio_psg_note_voice
        lda #$01
        sta aud_enable
        rts
@qty:
        ldx #ERR_ILLQTY
        jmp ERROR

; ============================================================================
; sfx_tempo -- SFX TEMPO,bpm   (bpm: 30..300)
; ============================================================================
sfx_tempo:
        jsr CHRGET
        cmp #'E'
        bne @syn
        jsr CHRGET
        cmp #'M'
        bne @syn
        jsr CHRGET
        cmp #'P'
        bne @syn
        jsr CHRGET
        cmp #'O'
        bne @syn
        jsr CHRGET                ; A=',', TXTPTR→','
        lda #','
        jsr SYNCHR                ; verify+consume ','; TXTPTR→value
        jsr FRMNUM
        jsr GETADR                ; LINNUM = 16-bit value
        lda LINNUM+1
        beq @check_lo
        cmp #$01
        bne @qty
        lda LINNUM
        cmp #45                   ; hi=1: only 256..300 legal (300 & $FF=44)
        bcs @qty
        bra @store
@check_lo:
        lda LINNUM
        cmp #30
        bcc @qty
@store:
        lda LINNUM
        sta aud_tempo_lo
        lda LINNUM+1
        sta aud_tempo_hi
        rts
@qty:
        ldx #ERR_ILLQTY
        jmp ERROR
@syn:
        ldx #ERR_SYNTAX
        jmp ERROR

; ============================================================================
; sfx_note -- SFX NOTE,v,pitch,dur[,vel]
; Phase 3: parse + range-check only; no PSG output.
; ============================================================================
sfx_note:
        jsr CHRGET
        cmp #'O'
        bne @syn
        jsr CHRGET
        cmp #'T'
        bne @syn
        jsr CHRGET
        cmp #'E'
        bne @syn
        jsr CHRGET                ; A=',', TXTPTR→','
        jsr COMBYTE               ; X = voice 0..2
        cpx #$03
        bcs @qty
        stx aud_arg0
        jsr COMBYTE               ; X = pitch 0..127
        cpx #$80
        bcs @qty
        stx aud_arg1
        jsr COMBYTE               ; X = duration 1..255
        beq @qty                  ; dur=0 illegal
        stx aud_arg2
        jsr CHRGOT
        beq @emit_default
        cmp #','
        bne @emit_default
        jsr COMBYTE               ; X = velocity 0..15
        cpx #$10
        bcs @qty
        stx aud_tmp
        bra @emit
@emit_default:
        jsr audio_load_default_vel
@emit:
        jsr audio_pitch_to_freq
        jsr audio_psg_note_voice
        lda #$01
        sta aud_enable
        rts
@qty:
        ldx #ERR_ILLQTY
        jmp ERROR
@syn:
        ldx #ERR_SYNTAX
        jmp ERROR

; ============================================================================
; sfx_v -- dispatch VOICE or VOL based on third letter (I vs L).
; ============================================================================
sfx_v:
        jsr CHRGET
        cmp #'O'
        bne @syn
        jsr CHRGET
        cmp #'I'
        beq @voice
        cmp #'L'
        bne @syn
        jsr CHRGET                ; VOL: A=',', TXTPTR→','
        jsr COMBYTE               ; X = volume 0..255
        stx aud_sfx_vol
        rts
@voice:
        jsr CHRGET
        cmp #'C'
        bne @syn
        jsr CHRGET
        cmp #'E'
        bne @syn
        jsr CHRGET                ; A=',', TXTPTR→','
        jsr COMBYTE               ; X = voice 0..2
        cpx #$03
        bcs @qty
        stx aud_tmp
        jsr COMBYTE               ; X = instrument id 0..255
        lda aud_tmp
        bne @v1v2
        stx aud_v0_inst
        rts
@v1v2:
        cmp #$01
        bne @v2
        stx aud_v1_inst
        rts
@v2:
        stx aud_v2_inst
        rts
@qty:
        ldx #ERR_ILLQTY
        jmp ERROR
@syn:
        ldx #ERR_SYNTAX
        jmp ERROR

; ============================================================================
; sfx_bank -- SFX BANK,n
; ============================================================================
sfx_bank:
        jsr CHRGET
        cmp #'A'
        bne @syn
        jsr CHRGET
        cmp #'N'
        bne @syn
        jsr CHRGET
        cmp #'K'
        bne @syn
        jsr CHRGET                ; A=',', TXTPTR→','
        jsr COMBYTE               ; X = bank id 0..255
        stx aud_sfx_bank
        rts
@syn:
        ldx #ERR_SYNTAX
        jmp ERROR

; ============================================================================
; sfx_status -- SFX STATUS  (no args)
; ============================================================================
sfx_status:
        jsr CHRGET
        cmp #'T'
        bne @syn
        jsr CHRGET
        cmp #'A'
        bne @syn
        jsr CHRGET
        cmp #'T'
        bne @syn
        jsr CHRGET
        cmp #'U'
        bne @syn
        jsr CHRGET
        cmp #'S'
        bne @syn
        ; Move past STATUS so caller sees ':' or end-of-line at TXTPTR.
        jsr CHRGET
        lda #<aud_str_bank
        ldy #>aud_str_bank
        jsr STROUT
        ldx aud_sfx_bank
        lda #$00
        jsr rp6502_linprt
        jsr CRDO
        lda #<aud_str_vol
        ldy #>aud_str_vol
        jsr STROUT
        ldx aud_sfx_vol
        lda #$00
        jsr rp6502_linprt
        jsr CRDO
        lda #<aud_str_tempo
        ldy #>aud_str_tempo
        jsr STROUT
        ldx aud_tempo_lo
        lda aud_tempo_hi
        jsr rp6502_linprt
        jsr CRDO
        rts
@syn:
        ldx #ERR_SYNTAX
        jmp ERROR

; ----------------------------------------------------------------------------
; audio_psg_enable -- map RIA PSG config block to XRAM AUDIO_PSG_ADDR.
; xreg(0,1,0,AUDIO_PSG_ADDR)
; ----------------------------------------------------------------------------
audio_psg_enable:
        lda #RIA_OP_ZXSTACK
        sta RIA_OP
        stz RIA_XSTACK            ; device 0 (RIA)
        lda #$01
        sta RIA_XSTACK            ; channel 1 (audio)
        stz RIA_XSTACK            ; address 0x00 (PSG config base)
        lda #>AUDIO_PSG_ADDR
        sta RIA_XSTACK            ; value high
        lda #<AUDIO_PSG_ADDR
        sta RIA_XSTACK            ; value low
        lda #RIA_OP_XREG
        sta RIA_OP
        jsr RIA_SPIN
        rts

; ----------------------------------------------------------------------------
; audio_psg_addr_voice -- point RW0 stream at oscillator X (0..2 currently).
; ----------------------------------------------------------------------------
audio_psg_addr_voice:
        txa
        asl a
        asl a
        asl a
        clc
        adc #<AUDIO_PSG_ADDR
        sta RIA_ADDR0
        lda #>AUDIO_PSG_ADDR
        adc #$00
        sta RIA_ADDR0+1
        lda #$01
        sta RIA_STEP0
        rts

; ----------------------------------------------------------------------------
; audio_psg_gate_off_voice -- release/quiet one oscillator (X=voice).
; ----------------------------------------------------------------------------
audio_psg_gate_off_voice:
        jsr audio_psg_addr_voice
        stz RIA_RW0               ; freq lo
        stz RIA_RW0               ; freq hi
        lda #$80
        sta RIA_RW0               ; duty = 50%
        lda #$F2
        sta RIA_RW0               ; attack: silent attenuation, quick rate
        lda #$F6
        sta RIA_RW0               ; decay: silent attenuation
        lda #$06
        sta RIA_RW0               ; sine + medium release
        stz RIA_RW0               ; pan center + gate off
        stz RIA_RW0               ; unused
        rts

; ----------------------------------------------------------------------------
; audio_load_default_vel -- aud_tmp = default velocity for aud_arg0 voice.
; ----------------------------------------------------------------------------
audio_load_default_vel:
        ldx aud_arg0
        cpx #$01
        beq @v1
        cpx #$02
        beq @v2
        lda aud_v0_vel
        sta aud_tmp
        rts
@v1:
        lda aud_v1_vel
        sta aud_tmp
        rts
@v2:
        lda aud_v2_vel
        sta aud_tmp
        rts

; ----------------------------------------------------------------------------
; audio_pitch_to_freq -- aud_arg1 (0..127) -> aud_freq_{lo,hi}.
; Coarse Phase 4 mapping: freq3 = pitch * 12 + 60.
; ----------------------------------------------------------------------------
audio_pitch_to_freq:
        lda aud_arg1
        sta aud_freq_lo
        stz aud_freq_hi
        asl aud_freq_lo           ; *2
        rol aud_freq_hi
        asl aud_freq_lo           ; *4
        rol aud_freq_hi
        lda aud_freq_lo
        sta LINNUM                ; save *4
        lda aud_freq_hi
        sta LINNUM+1
        asl aud_freq_lo           ; *8
        rol aud_freq_hi
        clc
        lda aud_freq_lo
        adc LINNUM                ; *12
        sta aud_freq_lo
        lda aud_freq_hi
        adc LINNUM+1
        sta aud_freq_hi
        clc
        lda aud_freq_lo
        adc #60                   ; keep very low pitches audible
        sta aud_freq_lo
        lda aud_freq_hi
        adc #$00
        sta aud_freq_hi
        rts

; ----------------------------------------------------------------------------
; audio_psg_note_voice -- gate on voice aud_arg0 using aud_freq and aud_tmp vel.
; ----------------------------------------------------------------------------
audio_psg_note_voice:
        ldx aud_arg0
        jsr audio_psg_addr_voice

        lda aud_freq_lo
        sta RIA_RW0               ; freq lo
        lda aud_freq_hi
        sta RIA_RW0               ; freq hi
        lda #$80
        sta RIA_RW0               ; duty = 50%

        lda #$0F
        sec
        sbc aud_tmp               ; attenuation = 15 - velocity
        asl a
        asl a
        asl a
        asl a
        ora #$02                  ; quick attack
        sta RIA_RW0               ; vol_attack

        lda #$0F
        sec
        sbc aud_tmp
        asl a
        asl a
        asl a
        asl a
        ora #$06                  ; medium decay
        sta RIA_RW0               ; vol_decay

        ldx aud_arg0
        cpx #$01
        beq @inst1
        cpx #$02
        beq @inst2
        lda aud_v0_inst
        bra @inst_mod
@inst1:
        lda aud_v1_inst
        bra @inst_mod
@inst2:
        lda aud_v2_inst
@inst_mod:
        cmp #$05
        bcc @inst_ok
@inst_loop:
        sec
        sbc #$05
        cmp #$05
        bcs @inst_loop
@inst_ok:
        asl a
        asl a
        asl a
        asl a
        ora #$06                  ; medium release
        sta RIA_RW0               ; wave_release

        lda #$01
        sta RIA_RW0               ; pan center + gate on
        stz RIA_RW0               ; unused
        rts

; ----------------------------------------------------------------------------
; String constants for SFX STATUS output.
; ----------------------------------------------------------------------------
aud_str_bank:
        .byte "SFX BANK=",0
aud_str_vol:
        .byte "SFX VOL=",0
aud_str_tempo:
        .byte "SFX TEMPO=",0
