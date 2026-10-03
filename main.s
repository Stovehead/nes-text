.feature line_continuations +

.segment "HEADER"  
    .byte $4E, $45, $53, $1A    ; iNES header identifier
    .byte 2                     ; 2x 16KB PRG code
    .byte 1                     ; 1x  8KB CHR data
    .byte $01, $00              ; mapper 0, vertical mirroring

.segment "VECTORS"
    .addr nmi
    .addr reset
    .addr 0

.segment "STARTUP"

.segment "CODE"

nmi:

reset:

.segment "CHARS"
