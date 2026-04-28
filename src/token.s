; Picocomputer keyword and operator tables. Replaces upstream
; src/msbasic/token.s.
;
; Modern keyword set:
; - INPUT#/SYS/OPEN/CLOSE tokenize but dispatch to rp6502_rts_stub
;   (reserved names, no-op for now — future file support will fill
;   them in). PRINT#/GET#/CMD have real handlers in misc1.s/input.s,
;   but those reach into CHKIN/CHKOUT/CLRCH which are also stubs, so
;   they're effectively no-ops too until file I/O is wired.
; - No VERIFY (Commodore CBM_ALL).
; - No PLT/TEX/PLOD/PSAV/VLOD/VSAV/SLOD/PRT (Apple/KBD).
; - No NULL (CONFIG_NULL — hardcopy-terminal padding).
; - No USR (no user-defined-machine-code-call vector — irrelevant on RP6502).
; - "CLEAR" instead of "CLR".
; - Same general layout/order so token numbers align with upstream where
;   meaningful (TOKEN_PRINT, TOKEN_GOTO, etc.). GFX is our addition,
;   placed last so it doesn't perturb upstream-compatible token numbers.

        init_token_tables

        keyword_rts "END", END
        keyword_rts "FOR", FOR
        keyword_rts "NEXT", NEXT
        keyword_rts "DATA", DATA
        keyword_rts "INPUT#", INPUTH
        keyword_rts "INPUT", INPUT
        keyword_rts "DIM", DIM
        keyword_rts "READ", READ
        keyword_rts "LET", LET
        keyword_rts "GOTO", GOTO, TOKEN_GOTO
        keyword_rts "RUN", RUN
        keyword_rts "IF", IF
        keyword_rts "RESTORE", RESTORE
        keyword_rts "GOSUB", GOSUB, TOKEN_GOSUB
        keyword_rts "RETURN", POP
        keyword_rts "REM", REM, TOKEN_REM
        keyword_rts "STOP", STOP
        keyword_rts "ON", ON
        keyword_rts "WAIT", WAIT
        keyword_rts "LOAD", LOAD
        keyword_rts "SAVE", SAVE
        keyword_rts "DEF", DEF
        keyword_rts "POKE", POKE
        keyword_rts "PRINT#", PRINTH
        keyword_rts "PRINT", PRINT, TOKEN_PRINT
        keyword_rts "CONT", CONT
        keyword_rts "LIST", LIST
        keyword_rts "CLEAR", CLEAR, TOKEN_CLEAR
        keyword_rts "CMD", CMD
        keyword_rts "SYS", SYS
        keyword_rts "OPEN", OPEN
        keyword_rts "CLOSE", CLOSE
        keyword_rts "GET", GET
        keyword_rts "NEW", NEW
        keyword_rts "GFX", GFX

        count_tokens

        keyword "TAB(", TOKEN_TAB
        keyword "TO", TOKEN_TO
        keyword "FN", TOKEN_FN
        keyword "SPC(", TOKEN_SPC
        keyword "THEN", TOKEN_THEN
        keyword "NOT", TOKEN_NOT
        keyword "STEP", TOKEN_STEP
        keyword "+", TOKEN_PLUS
        keyword "-", TOKEN_MINUS
        keyword "*"
        keyword "/"
        keyword "^"
        keyword "AND"
        keyword "OR"
        keyword ">", TOKEN_GREATER
        keyword "=", TOKEN_EQUAL
        keyword "<"

        .segment "VECTORS"
UNFNC:

        keyword_addr "SGN", SGN, TOKEN_SGN
        keyword_addr "INT", INT
        keyword_addr "ABS", ABS
        keyword_addr "FRE", FRE
        keyword_addr "POS", POS
        keyword_addr "SQR", SQR
        keyword_addr "RND", RND
        keyword_addr "LOG", LOG
        keyword_addr "EXP", EXP
        keyword_addr "COS", COS
        keyword_addr "SIN", SIN
        keyword_addr "TAN", TAN
        keyword_addr "ATN", ATN
        keyword_addr "PEEK", PEEK
        keyword_addr "LEN", LEN
        keyword_addr "STR$", STR
        keyword_addr "VAL", VAL
        keyword_addr "ASC", ASC
        keyword_addr "CHR$", CHRSTR
        keyword_addr "LEFT$", LEFTSTR, TOKEN_LEFTSTR
        keyword_addr "RIGHT$", RIGHTSTR
        keyword_addr "MID$", MIDSTR

        keyword "GO", TOKEN_GO

        .segment "KEYWORDS"
        .byte 0

; ============================================================
; Math operator dispatch table (used by FRMEVL).
; Format: precedence byte, then 2-byte routine address (-1 because
; the dispatch RTS-jumps via the address).
; ============================================================

        .segment "VECTORS"
MATHTBL:
        .byte $79
        .word FADDT-1
        .byte $79
        .word FSUBT-1
        .byte $7B
        .word FMULTT-1
        .byte $7B
        .word FDIVT-1
        .byte $7F
        .word FPWRT-1
        .byte $50
        .word TAND-1
        .byte $46
        .word OR-1
        .byte $7D
        .word NEGOP-1
        .byte $5A
        .word EQUOP-1
        .byte $64
        .word RELOPS-1
