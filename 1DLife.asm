; ============================================================
; 1D Life - Hardware 40x24 Text Mode (Tatung Einstein)
; ============================================================

VDP_DATA:   EQU 08H
VDP_CTRL:   EQU 09H

    ORG     0100H

START:
    LD      HL, START_MESSAGE_TEXT
START_MESSAGE:
    LD      A, (HL)
    OR      A
    JR      Z, END_OF_MESSAGE
    CALL    PRINT_CHAR
    INC     HL
    JR      START_MESSAGE

END_OF_MESSAGE:
    RST     08H
    DEFB    156                 ; Wait for key press
    CALL    INIT_TEXT_MODE      ; Switch VDP to 40x24 Text Mode & load font
    CALL    INIT_RNG

MAIN_LOOP:
    LD      B, 39
    LD      HL, DATA_X+38
    LD      DE, NEW_LINE_BUFFER+38

SEED_DATA:
    CALL    GET_RANDOM
    CP      128
    JR      C, SET_STAR
    LD      A, ' '
    JR      STORE_VALUE

SET_STAR:
    LD      A, '*'

STORE_VALUE:
    LD      (HL), A
    LD      (DE), A
    DEC     HL
    DEC     DE
    DJNZ    SEED_DATA
    CALL    UPDATE_DISPLAY
    LD      A, 26
    LD      (GEN_COUNT), A

GENERATION_LOOP:
    LD      IX, DATA_X+37
    LD      IY, DATA_Y+37
    LD      B, 35               ; Update cells 37 down to 3

CELL:
    LD      C, 0
    LD      A, (IX+2)
    CP      '*'
    JR      NZ, I_PLUS_ONE
    INC     C
I_PLUS_ONE:
    LD      A, (IX+1)
    CP      '*'
    JR      NZ, I_MINUS_ONE
    INC     C
I_MINUS_ONE:
    LD      A, (IX-1)
    CP      '*'
    JR      NZ, I_MINUS_TWO
    INC     C
I_MINUS_TWO:
    LD      A, (IX-2)
    CP      '*'
    JR      NZ, CURRENT_CELL
    INC     C

CURRENT_CELL:
    LD      A, (IX+0)
    CP      '*'
    JR      Z, CURRENTLY_STAR

CURRENTLY_BLANK:
    LD      A, C
    CP      2
    JR      Z, SET_Y_STAR
    CP      3
    JR      Z, SET_Y_STAR
    JR      SET_Y_BLANK

CURRENTLY_STAR:
    LD      A, C
    CP      2
    JR      Z, SET_Y_STAR
    CP      4
    JR      Z, SET_Y_STAR

SET_Y_BLANK:
    LD      A, ' '
    JR      STORE_LIFE_VALUE

SET_Y_STAR:
    LD      A, '*'

STORE_LIFE_VALUE:
    LD      (IY+0), A
    DEC     IX
    DEC     IY
    DJNZ    CELL

    ; Copy DATA_Y -> DATA_X and DATA_Y -> NEW_LINE_BUFFER (40 bytes)
    LD      HL, DATA_Y
    LD      DE, DATA_X
    LD      BC, 40
    LDIR

    LD      HL, DATA_Y
    LD      DE, NEW_LINE_BUFFER
    LD      BC, 40
    LDIR

    ; Scroll screen up and draw new generation at row 23
    CALL    UPDATE_DISPLAY

END_OF_GENERATION_LOOP:
    LD      A, (GEN_COUNT)
    DEC     A
    LD      (GEN_COUNT), A
    JR      NZ, GENERATION_LOOP
    JP      MAIN_LOOP

; ============================================================
; INITIALISE TMS9929A 40x24 HARDWARE TEXT MODE
; ============================================================
INIT_TEXT_MODE:
    DI

    ; 1. Clear shadow buffer with spaces
    LD      HL, SCREEN_BUF
    LD      DE, SCREEN_BUF + 1
    LD      BC, 959
    LD      (HL), ' '
    LDIR

    ; 2. Configure VDP Registers for 40x24 Text Mode
    LD      HL, VDP_TEXT_REGS
    LD      B, 8                ; 8 registers (R0..R7)
    LD      C, 80H              ; Start at Register 0 (80H = reg write bit)

SET_VDP_REGS:
    LD      A, (HL)
    OUT     (VDP_CTRL), A       ; Write register value
    LD      A, C
    OUT     (VDP_CTRL), A       ; Write register number | 80H
    INC     HL
    INC     C
    DJNZ    SET_VDP_REGS

    ; 3. Zero out Pattern Generator Table at VRAM 0x0800 (2048 bytes)
    LD      HL, 0800H
    CALL    SET_VRAM_WRITE
    LD      DE, 2048
    XOR     A

CLEAR_PGT:
    OUT     (VDP_DATA), A
    NOP                         ; Safe VDP write delay
    DEC     DE
    LD      A, D
    OR      E
    LD      A, 0
    JR      NZ, CLEAR_PGT

    ; 4. Upload glyph for '*' (ASCII 42 = 0x2A -> 0x0800 + 42*8 = 0x0950)
    ; (Space 0x20 is already all zeros from step 3)
    LD      HL, 0800H + ('*' * 8)
    CALL    SET_VRAM_WRITE
    LD      HL, GLYPH_STAR
    LD      B, 8

LOAD_STAR:
    LD      A, (HL)
    OUT     (VDP_DATA), A
    NOP
    INC     HL
    DJNZ    LOAD_STAR

    ; 5. Clear Name Table at VRAM 0x0000 (960 spaces)
    LD      HL, 0000H
    CALL    SET_VRAM_WRITE
    LD      DE, 960

CLEAR_NT:
    LD      A, ' '
    OUT     (VDP_DATA), A
    NOP
    DEC     DE
    LD      A, D
    OR      E
    JR      NZ, CLEAR_NT
    EI
    RET

; Helper: Set VDP VRAM write pointer to address in HL
SET_VRAM_WRITE:
    LD      A, L
    OUT     (VDP_CTRL), A
    LD      A, H
    OR      40H                 ; Bit 6 = 1 for VRAM Write
    OUT     (VDP_CTRL), A
    RET

; VDP Register values for 40x24 Text Mode:
VDP_TEXT_REGS:
    DEFB    00H                 ; R0: Text mode (M3=0)
    DEFB    0F0H                ; R1: 16K VRAM, Display ON, IE=1, Text Mode (M1=1)
    DEFB    00H                 ; R2: Name Table at 0x0000 (0 * 0x0400)
    DEFB    00H                 ; R3: Colour Table unused in Text Mode
    DEFB    01H                 ; R4: Pattern Table at 0x0800 (1 * 0x0800)
    DEFB    00H                 ; R5: Sprite Attribute Table unused
    DEFB    00H                 ; R6: Sprite Pattern Table unused
    DEFB    0F4H                ; R7: White text (0xF) on Dark Blue backdrop (0x4)

; 6x8 glyph for '*' (left-aligned in top 6 bits of each byte)
GLYPH_STAR:
    DEFB    00100000B           ;   *
    DEFB    10101000B           ; * * *
    DEFB    01110000B           ;  ***
    DEFB    11111000B           ; *****
    DEFB    01110000B           ;  ***
    DEFB    10101000B           ; * * *
    DEFB    00100000B           ;   *
    DEFB    00000000B           ;

; ============================================================
; UPDATE_DISPLAY (Scrolls buffer & blasts 960 bytes to VRAM)
; ============================================================
UPDATE_DISPLAY:
    LD      HL, SCREEN_BUF + 40
    LD      DE, SCREEN_BUF
    LD      BC, 920
    LDIR
    LD      HL, NEW_LINE_BUFFER
    LD      DE, SCREEN_BUF + 920
    LD      BC, 40
    LDIR
    IN      A, (VDP_CTRL)       ; Clear stale VBLANK flag

WAIT_VBLANK:
    IN      A, (VDP_CTRL)
    RLCA
    JR      NC, WAIT_VBLANK
    DI							;disable interrupts
    LD      HL, 0000H
    CALL    SET_VRAM_WRITE
    LD      HL, SCREEN_BUF
    LD      C, VDP_DATA
    LD      D, 3                ; 3 * 256 = 768 bytes
    LD      B, 0

DUMP_256:
    OTIR
    DEC     D
    JR      NZ, DUMP_256
    LD      B, 192              ; + 192 = 960 bytes
    OTIR
    EI							;enable interrupts again
    RET

; ============================================================
; SUPPORT ROUTINES & DATA
; ============================================================
PRINT_CHAR:
    PUSH    AF
    PUSH    BC
    PUSH    DE
    PUSH    HL
    PUSH    IX
    PUSH    IY
    RST     8
    DEFB    158
    POP     IY
    POP     IX
    POP     HL
    POP     DE
    POP     BC
    POP     AF
    RET

INIT_RNG:
    LD      A, R
    OR      A
    JR      NZ, STORE_SEED
    LD      A, 055H
STORE_SEED:
    LD      (SEED), A
    RET

GET_RANDOM:
    LD      A, (SEED)
    SRL     A
    JR      NC, NO_TAP
    XOR     0B8H
NO_TAP:
    LD      (SEED), A
    RET

SEED:               DEFB 055H
GEN_COUNT:          DEFB 0
DATA_X:             DEFS 40, 32
DATA_Y:             DEFS 40, 32
START_MESSAGE_TEXT: DEFB '--- Press Any Key To Start ---', 0
NEW_LINE_BUFFER:    DEFS 40, 32
SCREEN_BUF:         DEFS 960

    END
