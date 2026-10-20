.feature line_continuations +

PPUCTRL = $2000
PPUMASK = $2001
PPUSTATUS = $2002
OAMADDR = $2003
OAMDATA = $2004
PPUSCROLL = $2005
PPUADDR = $2006
PPUDATA = $2007
OAMDMA = $4014
JOY1 = $4016
JOY2 = $4017
JMP_OPCODE = $4C
RTI_OPCODE = $40
OAMBUFFER = $0200
BUTTON_A =      %10000000
BUTTON_B =      %01000000
BUTTON_SELECT = %00100000
BUTTON_START =  %00010000
BUTTON_UP =     %00001000
BUTTON_DOWN =   %00000100
BUTTON_LEFT =   %00000010
BUTTON_RIGHT =  %00000001
MMC3_BANK_SELECT = $8000
MMC3_BANK_DATA = $8001
MMC3_NAMETABLE_ARRANGEMENT = $A000
MMC3_PRG_RAM_PROTECT = $A001
MMC3_IRQ_LATCH = $C000
MMC3_IRQ_RELOAD = $C001
MMC3_IRQ_DISABLE = $E000
MMC3_IRQ_ENABLE = $E001

.zeropage
    scratch:            .res 16
    nmi_jump:           .res 3
    irq_jump:           .res 3
    next_irq:           .res 2
    current_ppu_ctrl:   .res 1
    current_ppu_mask:   .res 1
    x_scroll:           .res 1
    y_scroll:           .res 1

.segment "HEADER"  
    .byte $4E, $45, $53, $1A    ; iNES header identifier
    .byte 3                     ; 3x 16KB PRG code
    .byte 0                     ; No CHR ROM
    .byte $40, $08              ; MMC3, NES 2.0
    .byte $00                   ; No submapper
    .byte $00                   ; ???
    .byte $00                   ; No PRG RAM
    .byte $07                   ; 8KB CHR RAM

.segment "STARTUP"

.macro update_nmi NewAddr
    lda #RTI_OPCODE
    sta nmi_jump ; Replace JMP with RTI in case NMI interrupts this
    lda #<NewAddr
    sta nmi_jump + 1
    lda #>NewAddr
    sta nmi_jump + 2
    lda #JMP_OPCODE
    sta nmi_jump
.endmacro

.macro update_irq NewAddr
    lda #<NewAddr
    sta irq_jump + 1
    lda #>NewAddr
    sta irq_jump + 2
.endmacro

.macro update_next_irq NewAddr
    lda #<NewAddr
    sta next_irq
    lda #>NewAddr
    sta next_irq + 1
.endmacro

.macro apply_next_irq NewAddr
    lda next_irq
    sta irq_jump + 1
    lda next_irq + 1
    sta irq_jump + 2
.endmacro

reset:
    sei        ; ignore IRQs
    cld        ; disable decimal mode
    ldx #$40
    stx $4017  ; disable APU frame IRQ
    ldx #$ff
    txs        ; set stack pointer to $01ff
    inx        ; now X = 0
    stx $2000  ; disable NMI
    stx $2001  ; disable rendering
    stx $4010  ; disable DMC IRQs

    ; Optional (omitted):
    ; Set up mapper and jmp to further init code here.

    ; The vblank flag is in an unknown state after reset,
    ; so it is cleared here to make sure that @vblankwait1
    ; does not exit immediately.
    bit $2002

    ; First of two waits for vertical blank to make sure that the
    ; PPU has stabilized
@vblankwait1:
    bit $2002
    bpl @vblankwait1

    ; We now have about 30,000 cycles to burn before the PPU stabilizes.
    ; One thing we can do with this time is put RAM in a known state.
    ; Here we fill it with $00, which matches what (say) a C compiler
    ; expects for BSS. Since we haven't modified the X register since
    ; the earlier code above, it's still set to 0, so we can just
    ; transfer it to the Accumulator and save a byte
    txa
@clrmem:
    sta $00,x
    sta $100,x
    sta $200,x
    sta $300,x
    sta $400,x
    sta $500,x
    sta $600,x
    sta $700,x
    inx
    bne @clrmem

    ; Other things you can do between vblank waits are set up audio
    ; or set up other mapper registers.

@vblankwait2:
    bit $2002
    bpl @vblankwait2
    bit PPUSTATUS
    lda #$3F
    sta PPUADDR
    lda #$00
    sta PPUADDR
    lda #$0F
    ldx #32
    :
    sta PPUDATA
    dex
    bne :-

    sta MMC3_IRQ_DISABLE
    lda #%00000000
    sta MMC3_NAMETABLE_ARRANGEMENT
    sta MMC3_BANK_SELECT
    lda #$00
    sta MMC3_BANK_DATA
    lda #%00000001
    sta MMC3_BANK_SELECT
    lda #$02
    sta MMC3_BANK_DATA
    lda #%00000010
    sta MMC3_BANK_SELECT
    lda #$04
    sta MMC3_BANK_DATA
    lda #%00000011
    sta MMC3_BANK_SELECT
    lda #$05
    sta MMC3_BANK_DATA
    lda #%00000100
    sta MMC3_BANK_SELECT
    lda #$06
    sta MMC3_BANK_DATA
    lda #%00000101
    sta MMC3_BANK_SELECT
    lda #$07
    sta MMC3_BANK_DATA
    lda #%00000110
    sta MMC3_BANK_SELECT
    lda #$00
    sta MMC3_BANK_DATA
    lda #%00000111
    sta MMC3_BANK_SELECT
    lda #$01
    sta MMC3_BANK_DATA

    bit PPUSTATUS
    lda #$00
    sta PPUADDR
    sta PPUADDR
    ldx #$00
    :
    ldy #$30
    :
    sta PPUDATA
    dey
    bne :-
    dex
    bne :--

    ldx #$00
    lda #$FF
    :
    sta $200, x
    dex
    bne :-

    clc
    lda #$40
    ldy #$20
    sty PPUADDR
    ldy #$02
    sty PPUADDR
    ldx #14
    :
    sta PPUDATA
    adc #$01
    sta PPUDATA
    adc #$03
    dex
    bne :-

    lda #$42
    ldy #$20
    sty PPUADDR
    ldy #$22
    sty PPUADDR
    ldx #14
    :
    sta PPUDATA
    adc #$01
    sta PPUDATA
    adc #$03
    dex
    bne :-

    lda #$04
    sta PPUADDR
    lda #$00
    sta PPUADDR
    ldx #$00
    @draw_char_loop:
    lda #$00
    sta scratch + 1
    lda Line, x
    sta scratch
    asl scratch
    rol scratch + 1
    asl scratch
    rol scratch + 1
    asl scratch
    rol scratch + 1
    asl scratch
    rol scratch + 1
    asl scratch
    rol scratch + 1
    lda #$A0
    ; clc
    adc scratch + 1
    sta scratch + 1
    ldy #$00
    :
    lda (scratch), y
    sta PPUDATA
    iny
    cpy #$08
    bcc :-
    lda #$00
    sta scratch + 3
    lda Line + 14, x
    sta scratch + 2
    asl scratch + 2
    rol scratch + 3
    asl scratch + 2
    rol scratch + 3
    asl scratch + 2
    rol scratch + 3
    asl scratch + 2
    rol scratch + 3
    asl scratch + 2
    rol scratch + 3
    lda #$A0
    ; clc
    adc scratch + 3
    sta scratch + 3
    ldy #$00
    :
    lda (scratch + 2), y
    sta PPUDATA
    iny
    cpy #$08
    bcc :-
    ldy #$08
    :
    lda (scratch), y
    sta PPUDATA
    iny
    cpy #$10
    bcc :-
    ldy #$08
    :
    lda (scratch + 2), y
    sta PPUDATA
    iny
    cpy #$10
    bcc :-
    ldy #$10
    :
    lda (scratch), y
    sta PPUDATA
    iny
    cpy #$18
    bcc :-
    ldy #$10
    :
    lda (scratch + 2), y
    sta PPUDATA
    iny
    cpy #$18
    bcc :-
    ldy #$18
    :
    lda (scratch), y
    sta PPUDATA
    iny
    cpy #$20
    bcc :-
    ldy #$18
    :
    lda (scratch + 2), y
    sta PPUDATA
    iny
    cpy #$20
    bcc :-
    inx
    cpx #14
    bcs :+
    jmp @draw_char_loop
    :

    lda #$E8
    sta y_scroll

    bit PPUSTATUS
    lda #%00001010
    :
    sta PPUADDR
    sta PPUADDR
    asl
    bcc :-


    update_nmi nmi
    sta irq_jump
    update_irq nop_slide
    update_next_irq disable_rendering_irq

    lda #%10001000
    sta current_ppu_ctrl
    sta PPUCTRL

    lda #%00011110
    sta current_ppu_mask

    cli

forever:
    .repeat 128
    inc $300, x
    .endrepeat
    jmp forever

.segment "CODE"

nmi:
    lda #$02
    sta OAMDMA
    sta MMC3_IRQ_DISABLE
    cli

    lda #$3F
    sta PPUADDR
    lda #$01
    sta PPUADDR
    lda #$20
    sta PPUDATA
    lda #$0F
    sta PPUDATA
    lda #$20
    sta PPUDATA

    lda current_ppu_ctrl
    sta PPUCTRL
    lda current_ppu_mask
    sta PPUMASK

    bit PPUSTATUS
    lda x_scroll
    sta PPUSCROLL
    lda y_scroll
    sta PPUSCROLL

    update_irq nop_slide
    update_next_irq disable_rendering_irq

    lda #$17
    sta MMC3_IRQ_LATCH
    sta MMC3_IRQ_RELOAD
    sta MMC3_IRQ_ENABLE

    rti

nop_slide:
    pha
    lda #$00
    sta MMC3_IRQ_DISABLE
    sta MMC3_IRQ_LATCH
    sta MMC3_IRQ_RELOAD
    update_irq disable_rendering_irq
    sta MMC3_IRQ_ENABLE
    pla
    cli
    .repeat 34
    nop
    .endrepeat
    rti

disable_rendering_irq:
    ; 3 cycles from jump
    sta MMC3_IRQ_DISABLE ; 4 cycles
    pha ; 3 cycles
    lda #$00 ; 2 cycles
    sta PPUMASK ; 4 cycles
    txa ; 2 cycles
    pha ; 3 cycles
    tya ; 2 cycles
    pha ; 3 cycles
    bit PPUSTATUS ; 4 cycles
    lda #$3F ; 2 cycles
    sta PPUADDR ; 4 cycles
    lda #$01 ; 2 cycles
    ldx #$0F ; 2 cycles
    ldy #$20 ; 2 cycles
    .repeat 29
    nop
    .endrepeat
    sta PPUADDR
    stx PPUDATA
    sty PPUDATA
    sta PPUADDR
    sta PPUADDR
    lda #$00
    sta PPUADDR
    lda #$00
    sta PPUSCROLL
    ldx #$00
    and #$F8
    asl
    asl
    .repeat 40
    nop
    .endrepeat
    stx PPUSCROLL
    sta PPUADDR
    lda current_ppu_mask
    sta PPUMASK
    pla
    tay
    pla
    tax
    pla
    rti

.include "kana.s"

.segment "RODATA"
Line:
    .byte $00, $01, $02, $03, $04, $05, $06, $07, $08, $09, $0A, $0B, $0C, $0D
    .byte $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $1A, $1B, $1C, $1D

.segment "VECTORS"
    .addr nmi_jump
    .addr reset
    .addr irq_jump