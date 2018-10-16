    .inesprg 1   ; 1x 16KB PRG code
    .ineschr 1   ; 1x  8KB CHR data
    .inesmap 0   ; mapper 0 = NROM, no bank swapping
    .inesmir 1   ; background mirroring
  

;;;;;;;;;;;;;;;

;---------------- CONSTANT ADDRESSES -------------------
PPUCTRL   = $2000
PPUMASK   = $2001
PPUSTATUS = $2002
OAMADDR   = $2003
OAMDATA   = $2004
PPUSCROLL = $2005
PPUADDR   = $2006
PPUDATA   = $2007
OAMDMA    = $4014

JOYPAD1   = $4016
JOYPAD2   = $4017

    .rsset $0010
joyPad1_state .rs 1
bullet_active .rs 1


    .rsset $0200
sprite_player .rs 4
sprite_bullet .rs 5

    .rsset $0000
SPRITE_Y .rs 1
SPRITE_TILE .rs 1
SPRITE_ATTR .rs 1
SPRITE_X .rs 1
bullet_ATT .rs 1


BUTTON_A      = %10000000
BUTTON_B      = %01000000
BUTTON_SELECT = %00100000
BUTTON_START  = %00010000
BUTTON_UP     = %00001000
BUTTON_DOWN   = %00000100
BUTTON_LEFT   = %00000010
BUTTON_RIGHT  = %00000001


    
    .bank 0
    .org $C000 
RESET:
    SEI          ; disable IRQs
    CLD          ; disable decimal mode
    LDX #$40
    STX $4017    ; disable APU frame IRQ
    LDX #$FF
    TXS          ; Set up stack
    INX          ; now X = 0
    STX PPUCTRL    ; disable NMI
    STX PPUMASK    ; disable rendering
    STX $4010    ; disable DMC IRQs

vblankwait1:       ; First wait for vblank to make sure PPU is ready
    BIT PPUSTATUS
    BPL vblankwait1

clrmem:
    LDA #$00
    STA $0000, x
    STA $0100, x
    STA $0200, x
    STA $0400, x
    STA $0500, x
    STA $0600, x
    STA $0700, x
    LDA #$FE
    STA $0300, x
    INX
    BNE clrmem
   
vblankwait2:      ; Second wait for vblank, PPU is ready after this
    BIT PPUSTATUS
    BPL vblankwait2


;    LDA #%10000000   ;intensify blues
;    STA PPUMASK

    ;Reset PPU h/l latch
    LDA PPUSTATUS

    ; Write Address $3F10 (Bakcground colour) to the ppu
    LDA #$3F
    STA PPUADDR  
    LDA #$10
    STA PPUADDR

    ;Write the BackgroundColor
    LDA #$30
    STA PPUDATA

; Write pallet 00
    LDA #$00
    STA PPUDATA
    LDA #$01
    STA PPUDATA
    LDA #$2A
    STA PPUDATA
    LDA #$25
    STA PPUDATA


;--------------------- Sprite Data --------------;
    ; Write sprite data for 0 OAM memory Object memory
    LDA  #120       ; Y pos
    STA  sprite_player + SPRITE_Y

    LDA  #0         ; Tile number
    STA  sprite_player + SPRITE_TILE

    LDA  #%00000000         ; Attributes ????
    STA sprite_player + SPRITE_ATTR

    LDA #128    ; X pos
    STA sprite_player + SPRITE_X


    LDA #%10000000  ;binary notation to Enable NMI
    STA PPUCTRL  

    LDA #%00010000  ; Enable Sprites
    STA PPUMASK

Forever:
    JMP Forever     ;jump back to Forever, infinite loop


;------------------------------- GAME UPDATE -------------------------;
NMI:

; Update  And Check Controller
    JMP ControllerRead
ControllerReturn:


    JMP UpdateBullet
BulletReturn:

    ;copy sprite data to the ppu#
    LDA #0
    STA OAMADDR
    LDA #$02
    STA OAMDMA

    RTI
    
;--------------------------------- CONTROLLER ----------------------------;
ControllerRead:
    ;Init Controller 1
    LDA #1
    STA JOYPAD1
    LDA #0
    STA JOYPAD1

    ;Read joypad A is already 0
    LDX #0
    STX joyPad1_state
ReadController:
    LDA JOYPAD1
    LSR A 
    ROL joyPad1_state
    INX
    CPX #8
    BNE ReadController

;----------- A BUTTON--------;
    LDA joyPad1_state
    AND #BUTTON_A
    BEQ  LookAt_B   ;Branch if equal
    JSR SpawnBullet

;----------- B BUTTON--------;
LookAt_B:
    ;Read B Button
    LDA joyPad1_state
    AND #BUTTON_B
    BEQ  LookAt_UP   ;Branch if equal
    LDA sprite_player + SPRITE_X
    CLC
    ADC #1
    STA sprite_player + SPRITE_X

;----------- UP BUTTON--------;
LookAt_UP:
    LDA joyPad1_state
    AND #BUTTON_UP
    BEQ  LookAt_DOWN   ;Branch if equal
    LDA sprite_player + SPRITE_Y
    CLC
    ADC #-1
    STA sprite_player + SPRITE_Y

;----------- DOWN BUTTON--------;
LookAt_DOWN:
    LDA joyPad1_state
    AND #BUTTON_DOWN
    BEQ  LookAt_LEFT   ;Branch if equal
    LDA sprite_player + SPRITE_Y
    CLC
    ADC #1
    STA sprite_player + SPRITE_Y

;----------- LEFT BUTTON--------;
LookAt_LEFT:
    LDA joyPad1_state
    AND #BUTTON_LEFT
    BEQ  LookAt_RIGHT   ;Branch if equal
    LDA sprite_player + SPRITE_X
    CLC
    ADC #-1
    STA sprite_player + SPRITE_X

    
;----------- RIGHT BUTTON--------;
LookAt_RIGHT:
    LDA joyPad1_state
    AND #BUTTON_RIGHT
    BEQ  LookAt_START   ;Branch if equal
    LDA sprite_player + SPRITE_X
    CLC
    ADC #1
    STA sprite_player + SPRITE_X

;----------- START BUTTON--------;
LookAt_START:
    LDA joyPad1_state
    AND #BUTTON_START
    BEQ  LookAt_SELECT   ;Branch if equal
    LDA sprite_player + SPRITE_Y
    CLC
    ADC #1
    STA sprite_player + SPRITE_Y
 
;----------- SELECT BUTTON--------;
LookAt_SELECT:
    LDA joyPad1_state
    AND #BUTTON_SELECT
    BEQ  ControllerReadFinished   ;Branch if equal
    LDA sprite_player + SPRITE_Y
    CLC
    ADC #1
    STA sprite_player + SPRITE_Y

;----------- CONTROLLER FINISHED --------;
ControllerReadFinished:   
    JMP ControllerReturn

;--------------------------------------SPAWNING----------------------------;
SpawnBullet:
    ; Spawn a bullet
    LDA  sprite_player + SPRITE_Y       ; Y pos
    STA  sprite_bullet + SPRITE_Y

    LDA  #1         ; Tile number
    STA  sprite_bullet + SPRITE_TILE

    LDA  #%00000000         ; Attributes ????
    STA sprite_bullet + SPRITE_ATTR

    LDA sprite_player + SPRITE_X     ; X pos
    STA sprite_bullet + SPRITE_X

    LDA #1
    STA bullet_active
    RTS

UpdateBullet:
    LDA bullet_active
    BEQ BulletGone
    LDA sprite_bullet + SPRITE_Y
    SEC
    SBC #1
    STA sprite_bullet + SPRITE_Y
    BCS BulletGone
    LDA #0
    STA bullet_active
    JMP BulletReturn

BulletGone:
    JMP BulletReturn

;;;;;;;;;;;;;;   
  
  

    .bank 1
    .org $FFFA     ;first of the three vectors starts here
    .dw NMI        ;when an NMI happens (once per frame if enabled) the 
                    ;processor will jump to the label NMI:
    .dw RESET      ;when the processor first turns on or is reset, it will jump
                    ;to the label RESET:
    .dw 0          ;external interrupt IRQ is not used in this tutorial

  
;;;;;;;;;;;;;;  
  
  
    .bank 2
    .org $0000
    .incbin "Sprites/Face.chr"   ;includes 8KB graphics file from SMB1