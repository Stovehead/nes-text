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

reset:
    sta MMC3_IRQ_DISABLE
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

    bit PPUSTATUS
    lda #%00001010
    :
    sta PPUADDR
    sta PPUADDR
    asl
    bcc :-

    lda #%10000110
    sta MMC3_BANK_SELECT
    lda #$00
    sta MMC3_BANK_DATA
    lda #%10000111
    sta MMC3_BANK_SELECT
    lda #$01
    sta MMC3_BANK_DATA
    sta MMC3_IRQ_DISABLE


    update_nmi nmi
    sta irq_jump
    update_irq irq

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

    lda current_ppu_ctrl
    sta PPUCTRL
    lda current_ppu_mask
    sta PPUMASK

    bit PPUSTATUS
    lda #%00001010
    :
    sta PPUADDR
    sta PPUADDR
    asl
    bcc :-

    lda x_scroll
    sta PPUSCROLL
    lda y_scroll
    sta PPUSCROLL

    update_irq nop_slide

    lda #49
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
    update_irq irq
    sta MMC3_IRQ_ENABLE
    pla
    cli
    .repeat 34
    nop
    .endrepeat

irq:
    sta MMC3_IRQ_DISABLE
    rti

.include "kana.s"

.segment "VECTORS"
    .addr nmi_jump
    .addr reset
    .addr irq_jump