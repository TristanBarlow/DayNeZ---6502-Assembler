    .inesprg 1   ; 1 x bank of 16KB PRG code
    .ineschr 1   ; 1 x bank of 8KB CHR data
    .inesmap 0   ; mapper 0 = NROM, no bank swapping
    .inesmir 1   ; background mirroring
    
    .bank 0
    .org $C000
;------------------------------------------
PPUCTRL     = $2000
PPUMASK     = $2001
PPUSTATUS   = $2002
OAMADDR     = $2003     ; Objective attribute memory
OAMDATA     = $2004
PPUSCROLL   = $2005
PPUADDR     = $2006
PPUDATA     = $2007
OAMDMA      = $4014
JOYPAD1     = $4016
JOYPAD2     = $4017

BUTTON_A       = %10000000
BUTTON_B       = %01000000
BUTTON_SELECT  = %00100000
BUTTON_START   = %00010000
BUTTON_UP      = %00001000
BUTTON_DOWN    = %00000100
BUTTON_LEFT    = %00000010
BUTTON_RIGHT   = %00000001

S_TITLE_SCREEN = %00000001
S_INGAME       = %00000010
S_ENDGAME      = %00000100


;Enemy Constants
ENEMY_SQUAD_WIDTH  = 3
ENEMY_SQUAD_HEIGHT = 1
NUM_ENEMIES        = ENEMY_SQUAD_HEIGHT * ENEMY_SQUAD_WIDTH
ENEMY_SPACING      = 30
E_WIDTH            = 8
E_HEIGHT           = 24
E_X_SPEED          = 1
E_HEALTH           = 2      ;-1 so enemy dies when health is negative not 0
E_Y_SPAWN          = 220
E_BASE_SPRITE      = $22           
E_BODY_PARTS       = 3
E_ANIM_SPRITES     = 4
E_DECAP_HP         = 2

;offset into sprite that is the player gun sub_positions
WEAPON_OFFSET      = 8
POO_ANIM_SPRITES   = 3


;Barrier Constants
B_WIDTH          = 16
B_HEIGHT         = 16
B_COOLDOWN       = 128
B_NUM_SPRITES    = 4
B_RIGHT_X_OFFSET = 5

;Player constants
P_WIDTH         = 8
P_HEIGHT        = 24
P_NUM_SPRITES   = 4
P_SPAWN_X       = 230
P_SPAWN_Y       = 200
P_X_PIXEL_SPEED = 1
P_X_SUB_SPEED   = 64
P_ANIM_SPRITES  = 3

;Gameplay constants
X_MIN            = 16
X_MAX            = 232
JUMP_FORCE       = -(256)
NUMBER_OF_WAVES  = 3
ANIM_FRAME_SPEED = 4
GRAVITY          = 8     ; Sub pixel per frame 
MAX_Y_SPEED      = 20  
FLOORHEIGHT      = 210
WAVE_COOL_DOWN   = 120
DEATH_COOL_DOWN  = 150
RESPAWN_X        = 126
RESPAWN_Y        = 200
END_GAME_CD      = 75

;UI Constants
INITAL_START_CD = 100
START_SCREEN_X  = 95
START_SCREEN_Y  = 136
WAVE_T_X        = 200
WAVE_T_Y        = 10
END_GAME_MSG_X  = 120
END_GAME_MSG_Y  = 120
HEART_X         = 10
HEART_Y         = 10
NUM_HEARTS      = 3
NUM_WAVE_SP     = 2


;Bullet constants
BULLET_INACTIVE     = %00000000
BULLET_ACTIVE       = %00000001
BULLET_RIGHT        = %00000000
BULLET_LEFT         = %01000000
BULLET_SPEED        = 3
BULLET_FIRE_CD      = 10
BULLET_ANIM_SPRITES = 3

;Animation constants
ANIM_INACTIVE   = %00000000
ANIM_ACTIVE     = %00000001
FLASH_RATE      = 30

    .rsset $0000
joyPad1_state   .rs 1
bullet_flag     .rs 1
enemy_info      .rs 4 * NUM_ENEMIES
collision_flag  .rs 1
temp_x          .rs 1
temp_y          .rs 1
nametable_add   .rs 2
my_state        .rs 1
flash_cd        .rs 1
start_cd        .rs 1

player_health   .rs 1
player_kills    .rs 1
player_waves    .rs 1
player_shot_CD  .rs 1

barrier_health  .rs 1
barrier_CD      .rs 1


;Sprite variables
    .rsset $0200
sprite_player  .rs 4 * P_NUM_SPRITES
sprite_bullet  .rs 4
sprite_barrier .rs 4 * B_NUM_SPRITES
sprite_poo     .rs 4
sprite_health  .rs 4 * NUM_HEARTS
sprite_Wave    .rs 4 * NUM_WAVE_SP
sprite_enemy   .rs 4 * NUM_ENEMIES
sprite_e_body  .rs 4 * E_BODY_PARTS  * NUM_ENEMIES

;Movement variables
    .rsset $0300
player_movement .rs 5
poo_movement    .rs 5
enemy_movement  .rs 5 * NUM_ENEMIES
enemy_head_m    .rs 5 * NUM_ENEMIES


; Animation instance variables
    .rsset $0400
player_anim     .rs 4
poo_anim        .rs 4
bullet_anim     .rs 4
enemy_anim      .rs 4 * NUM_ENEMIES

;Movement variable offsets
    .rsset $0000
speed_y          .rs 2 ; sub pixels per frame
sub_pos_x        .rs 2 ; sub pixels per frame
sub_pos          .rs 1 ; sub pixel movement sub_position

;Sprite variable offsets
    .rsset $0000
SPRITE_Y    .rs 1
SPRITE_TILE .rs 1
SPRITE_ATTR .rs 1
SPRITE_X    .rs 1

;Enemy info offsets, blank so it can loop nicely
    .rsset $0000

enemyStatus  .rs 1
enemy_health .rs 1
enemy_speed  .rs 1
enemy_blank2 .rs 1

;Animation variable offset
    .rsset $0000
anim_cd         .rs 1
anim_index      .rs 1
anim_max_index  .rs 1
anim_status     .rs 1


    .bank 0
    .org $C000 

    ; Include macros here so we can use them during the init process
    INCLUDE "macros.asm"
;----------------------------- RESET ---------------------;
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
    STX $4010    ; disable DMC IRQs]
    

vblankwait1:       ; First wait for vblank to make sure PPU is ready
    BIT PPUSTATUS
    BPL vblankwait1
    TXA
    LDX #0
clrmem:
    LDA #$00
    STA $0000, x
    STA $0100, x
    STA $0300, x
    STA $0400, x
    STA $0500, x
    STA $0600, x
    STA $0700, x
    LDA #$FE
        
    STA $0200, x

    INX
    BNE clrmem

vblankwait2:      ; Second wait for vblank, PPU is ready after this
    BIT PPUSTATUS
    BPL vblankwait2

    LDA PPUSTATUS



    ; Write Address $3F10 (background pallet) to the ppu
    LDA #$3F
    STA PPUADDR  
    LDA #$00
    STA PPUADDR

;write background
    LoadPalette backGroundPalettes

    ; Write Address $3F10 (sprite colour) to the ppu
    LDA #$3F
    STA PPUADDR  
    LDA #$10
    STA PPUADDR

    ; load our pallets
    LoadPalette palettes
    LoadPalette palettes+4

    ;load nametable data
    LDA #$20             
    STA PPUADDR  
    LDA #$00
    STA PPUADDR
    
    ;Load background
    JSR LoadNameTables

    ;Set state to title screen
    LDA #S_TITLE_SCREEN
    STA my_state
    JSR InitStartScreen

    LDA #%00011000   
    STA PPUMASK

    LDA #%10000000  
    STA PPUCTRL

    ;Set a cool down so players dont start straight away
    LDA #INITAL_START_CD
    STA start_cd

    LDA #0
    STA PPUSCROLL   ;se x scroll
    STA PPUSCROLL   ;set y scroll


;jump back to Forever, infinite loop
Forever:
    JMP Forever     


;------------------------------- GAME UPDATE -------------------------;
NMI:

    ; Make sure we're reading controler inputs
    JSR UpdateController

    ;First check state for in game as this is most likely
    ; And when performance matters most
    LDA my_state
    AND #S_INGAME
    BNE InGame

    ;Check to see if we're still on a start cool down
    LDA start_cd
    CMP #1
    BCC OnStartCD
    DEC start_cd
    JMP EndNMI
OnStartCD:
    ;We know we're not in game so check for title screen
    LDA my_state
    AND #S_TITLE_SCREEN
    BNE TitleScreen

    JMP EndGame

;-------- In game -----;
InGame:
    ;Update the player and handle inputs
    JSR UpdatePlayer
    
    ;Check to see if we're still on a start cool down
    LDA start_cd
    CMP #1
    BCC FullGameUpdate

    ;If there is still a cool down end the update
    DEC start_cd
    JMP EndNMI

FullGameUpdate:
; Perform game update
    JSR GameUpdate

    JSR UpdateBarrier

    JMP EndNMI

TitleScreen:
    ;Flash the message on screen
    JSR FlashMessageSprites

    ;Check to see if the player has pressed A to continue to the game
    LDA joyPad1_state
    AND #BUTTON_A
    BEQ  EndNMI   

    ;Change state to ingame
    LDA #S_INGAME
    STA my_state

    ;Init game
    JSR InitGame

    JMP EndNMI

EndGame:
    ;Flash end game messages
    JSR FlashMessageSprites

    ;Check to see if the player is done with looking at the end game message
    LDA joyPad1_state
    AND #BUTTON_A
    BEQ  EndNMI   

    ;If A has been pressed reset game
    JMP RESET

EndNMI:
    ;copy sprite data to the ppu#
    LDA #0
    STA OAMADDR
    LDA #$02
    STA OAMDMA

    RTI
    

SPRITE
;;;;;;;;;;;;;;   
    INCLUDE "subroutines.asm"
    INCLUDE "sprite_data.asm"
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
    .incbin "../Sprites/Face.chr"   ;includes 8KB graphics file from SMB1