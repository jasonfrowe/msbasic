; Picocomputer 6502 BASIC reset shim. Replaces the variant-specific
; src/msbasic/header.s (which is empty for non-variant builds).
;
; The 6502 lands here on every reset. We unconditionally set SP=$FF,
; clear decimal mode, and (re)open tty:/con: first, then use a one-
; byte CLC/SEC flag to detect cold vs warm: $18 (CLC) on a fresh
; image load, self-modified to $38 (SEC) once the cold path has run,
; so subsequent 6502 resets (RAM still alive) fall through to warm.

.segment "HEADER"

rp6502_start:
        ldx #STACK_TOP
        txs
        cld
        jsr rp6502_init_io        ; open tty: and con: — both paths need it

rp6502_flag:
        clc                       ; $18 fresh; → $38 after cold init
        bcs rp6502_warm           ; SEC ⇒ warm; CLC falls through to cold

        lda #$38                  ; SEC opcode
        sta rp6502_flag
        jmp COLD_START

rp6502_warm:
        jmp RESTART
