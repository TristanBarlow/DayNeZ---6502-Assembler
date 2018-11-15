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

BUTTON_A      = %10000000
BUTTON_B      = %01000000
BUTTON_SELECT = %00100000
BUTTON_START  = %00010000
BUTTON_UP     = %00001000
BUTTON_DOWN   = %00000100
BUTTON_LEFT   = %00000010
BUTTON_RIGHT  = %00000001

COLLIDE_RIGHT= %00000001
COLLIDE_LEFT = %00000010
COLLIDE_UP   = %00000100
COLLIDE_DOWN = %00001000

ENEMY_SQUAD_WIDTH = 3
ENEMY_SQUAD_HEIGHT = 1
NUM_ENEMIES  = ENEMY_SQUAD_HEIGHT * ENEMY_SQUAD_WIDTH
ENEMY_SPACING = 16
ENEMY_DECENT_SPEED = 5
JUMP_FORCE = -(256+128)

GRAVITY  =   8     ; Sub pixel per frame 
MAX_Y_SPEED = 20      ; pixel per frame
FLOORHEIGHT = 220
GROUND_FRICTION = 1  ; Sub pixel per frame

BULLET_INACTIVE = %00000000
BULLET_ACTIVE   = %00000001
BULLET_RIGHT    = %00000000
BULLET_LEFT     = %01000000





    .rsset $0000
joyPad1_state   .rs 1
bulletFlag      .rs 1
enemy_info      .rs 4 * NUM_ENEMIES
collisionFlag   .rs 1
temp_x          .rs 1
temp_y          .rs 1
active_sprite   .rs 1


    .rsset $0000
speedY          .rs 2 ; sub pixels per frame
speedX          .rs 2 ; sub pixels per frame
pos             .rs 1 ; sub pixel movement position

    .rsset $0200
sprite_player .rs 4 * 4
sprite_bullet .rs 4
sprite_wall   .rs 4
sprite_enemy  .rs 4 * NUM_ENEMIES

    .rsset $0300
enemy_movement  .rs 5 * NUM_ENEMIES
player_movement .rs 5

    .rsset $0000
SPRITE_Y .rs 1
SPRITE_TILE .rs 1
SPRITE_ATTR .rs 1
SPRITE_X .rs 1

    .rsset $0000
enemy_speed .rs 1
enemyStatus .rs 1
enemyWidth  .rs 1
enemyHeight .rs 1



    .bank 0
    .org $C000 

;---------------------------- MACROS ---------------------;
SignFlip .macro 
    EOR #%11111111
    CLC 
    ADC #1
    .endm

; 1st param adress second param value to add
AddValueInLoop .macro
    LDA \1,x
    CLC
    ADC \2
    STA \1,x
    .endm

; 1st param adress second param value to add
AddValue .macro
    LDA \1
    CLC
    ADC \2
    STA \1
    .endm

; 1: variable to subtract |2: value to sub 
SubtractValue .macro
    LDA \1
    SEC
    SBC \2
    STA \1
    .endm

;| 1: 16 variable | 2: 16bit Value to add| 
Add16Bit .macro 
    LDA \1
    CLC
    ADC #LOW(\2)
    STA \1
    LDA \1 + 1 ;high 8 bits
    ADC #HIGH(\2) ; DIDNT CLEAR CARRY
    STA \1 + 1
    .endm

;|Start of sprites| number Of Sprites |
MoveSpriteCollection

;| sprite variable | x | y | tileID | Attr| 
InitSpriteAtPos .macro
        ; Write sprite data for 0 OAM memory Object memory
    LDA  \3       ; Y pos
    STA  \1 + SPRITE_Y

    LDA  \4       ; Tile number
    STA  \1 + SPRITE_TILE

    LDA \5         ; Attributes ????
    STA \1 + SPRITE_ATTR

    LDA \2    ; X pos
    STA \1 + SPRITE_X
    .endm

;| sprite to change | sprite Table | current index
AnimateSprite .macro
    .endm
;|main sprie | X move | sprite Num
MoveAllSpritesX .macro
     ; Apply the phyics
    LDX #((\3-1) * 4)
ApplyToSprites\@:
    LDA \1 + SPRITE_X,x
    CLC
    ADC \2
    STA \1 + SPRITE_X,x
    DEX
    DEX
    DEX
    DEX
    BPL ApplyToSprites\@
    .endm

;| 1: Movement Variable | 2: sprite  | numberOf Sprites
ApplyPhysics .macro 
    ; Apply Gravity
    Add16Bit \1 + speedY, GRAVITY
    AddValue \1 + pos, \1 + speedY

    ; Apply the new speed DONT CLEAR CARRY
    LDA \2 + SPRITE_Y
    ADC \1 + speedY + 1
    STA \2 + SPRITE_Y

    ;CHeck to see if its not greater than floorHeight
    CMP #FLOORHEIGHT
    BCS OnGround\@

    JMP ReturnFromApplyPhysics\@

OnGround\@:
    ;If the object is on the ground
    LDA #0
    STA \1 +speedY
    STA \1 +speedY+1
    STA \1 + pos


    LDA #FLOORHEIGHT
    STA \2 + SPRITE_Y

ReturnFromApplyPhysics\@:

    .if \3 > 1
    ; Apply the Y to the rest of the sprites
    LDX #((\3-1) * 4)
    LDY #(\3-1)
ApplyToSprites\@:
    LDA \2 + SPRITE_Y
    CLC
    ADC humanSpriteOffsets, y
    STA \2 + SPRITE_Y+4,x
    DEX
    DEX
    DEX
    DEX
    DEY
    BPL ApplyToSprites\@
    .endif
    LDY #0
    .endm

;| 1: movement Variable | 2: sprite;
Jump .macro
    ; Make sure is on the floor
    LDA \2 + SPRITE_Y
    CMP #FLOORHEIGHT
    BCC NoJump\@

    ; Make sure we're not touching the floor
    AddValue \2 + SPRITE_Y, #-2

    LDA #LOW(JUMP_FORCE)
    STA \1 + speedY
    LDA #HIGH(JUMP_FORCE)
    STA \1 + speedY +1

NoJump\@:
    .endm

GetDirection .macro 
    ;Get X dir
    LDA \3
    SEC
    SBC \1
    STA \5 + vecX

    LDA \4
    SEC
    SBC \2
    STA \5 + vecY
    .endm

CielingValue .macro
    LDA \2
    CMP \1
    BCC Cap\@
    JMP Fin\@
Cap\@:
    STA \1
Fin\@:
    .endm
; SET X REG TO 0 IF NOT IN LOOP WITH CONSTANT COLLISION SIZES
;| 1: sprite1| 2 : w1 | 3 : h1 | 4 : sprite2 | 5 : w2 | 6 :  h2|
CheckSpriteCollisionWithXReg .macro 
    LDA #%00000000
    STA collisionFlag

    LDA \1 + SPRITE_X, x      ; load x1
    SEC
    SBC \5          ; subtract w2
    CMP \4 + SPRITE_X          ;compare with x2  
    BCS NoCollision\@ ; branch if x1-w2 >=


    CLC 
    ADC \2 + \5     ; Add width 1 and width 2 to A 
    CMP \4 + SPRITE_X          ; compare to x2
    BCC NoCollision\@ ; branch if no collision
    
    LDA \1 + SPRITE_Y, x ; caluclate y_enemy - bullet width(y1 - h2)
    SEC
    SBC \6                         ; assume w2 = 8
    CMP \4+SPRITE_Y ;compare with x  bullet   
    BCS NoCollision\@ ; branch if x1-w2 >=

    CLC 
    ADC \3+\6                    ; Calculat x_enemy + w_eneym (x1 + w1) assuming w1 = 8
    CMP \4+SPRITE_Y
    BCS EndCollision\@ ; 

NoCollision\@
    LDA #%00000001
    STA collisionFlag
EndCollision\@
    .endm

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
    STX $4010    ; disable DMC IRQs

vblankwait1:       ; First wait for vblank to make sure PPU is ready
    BIT PPUSTATUS
    BPL vblankwait1

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


    LDA #%10000000   ;intensify blues
    STA PPUMASK

    ;Reset PPU h/l latch
    LDA PPUSTATUS

    ; Write Address $3F10 (Bakcground colour) to the ppu
    LDA #$3F
    STA PPUADDR  
    LDA #$10
    STA PPUADDR

; Write pallet 00
    LDA #$0F
    STA PPUDATA
    LDA #$18
    STA PPUDATA
    LDA #$20
    STA PPUDATA
    LDA #$2A
    STA PPUDATA


;--------------------- Player Sprite Data --------------;

InitPlayerSprites:

    ;legs
    InitSpriteAtPos sprite_player, #120, #136,  #$20, #%00000000

    ;body
    InitSpriteAtPos sprite_player + 4, #120, #128,  #$10, #%00000000

    ;gun
    InitSpriteAtPos sprite_player + 8 ,#128, #128,  #$11, #%00000000
    
    ;head
    InitSpriteAtPos sprite_player + 12,     #120, #120,  #$00, #%00000000


;--------------------- wall Data --------------;
    ; Write sprite data for 0 OAM memory Object memory
    LDA  #FLOORHEIGHT      ; Y pos
    STA  sprite_wall + SPRITE_Y

    LDA  #$30        ; Tile number
    STA  sprite_wall + SPRITE_TILE

    LDA  #%00000000         ; Attributes ????
    STA sprite_wall + SPRITE_ATTR

    LDA #128    ; X pos
    STA sprite_wall + SPRITE_X

;---------------------------- Init enemies -------------------------;
    LDX #0
    LDA #ENEMY_SQUAD_HEIGHT  * ENEMY_SPACING
    STA temp_y
InitEnemiesLoop_Y:
    LDA #ENEMY_SQUAD_WIDTH *ENEMY_SPACING
    STA temp_x
InitEnemiesLoop_X:
    ; Accumlator  = temp_x here

    STA sprite_enemy + SPRITE_X, x
    LDA temp_y
    STA sprite_enemy + SPRITE_Y,x
    LDA #2 
    STA sprite_enemy + SPRITE_TILE, X
    LDA #%00000000   
    STA sprite_enemy+ SPRITE_ATTR, x

    STA enemy_info + enemyStatus,x

    LDA #8
    STA enemy_info + enemyHeight, x

    LDA #1
    STA enemy_info + enemy_speed, x


    ;Increment X by 4
    TXA
    CLC
    ADC #4
    TAX

    LDA temp_x
    SEC
    SBC #ENEMY_SPACING
    STA temp_x
    BNE InitEnemiesLoop_X

    LDA temp_y
    SEC
    SBC #ENEMY_SPACING
    STA temp_y
    BNE InitEnemiesLoop_Y

;----------- End Enemy loop -------------;

    LDA #%10000000  ;binary notation to Enable NMI
    STA PPUCTRL  

    LDA #%00010000  ; Enable Sprites
    STA PPUMASK

Forever:
    JMP Forever     ;jump back to Forever, infinite loop


;------------------------------- GAME UPDATE -------------------------;
NMI:

; Update  And Check Controller
    JSR ControllerRead

; Perform game update
    JSR GameUpdate

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
    JSR TrySpawnBullet

;----------- B BUTTON--------;
LookAt_B:
    ;Read B Button
    LDA joyPad1_state
    AND #BUTTON_B
    BEQ  LookAt_UP   ;Branch if equal

;----------- UP BUTTON--------;
LookAt_UP:
    LDA joyPad1_state
    AND #BUTTON_UP
    BEQ  LookAt_LEFT   ;Branch if equal
    Jump player_movement, sprite_player
;----------- LEFT BUTTON--------;
LookAt_LEFT:
    LDA joyPad1_state
    AND #BUTTON_LEFT
    BEQ  LookAt_RIGHT   ;Branch if equal

    ;FlipPlayer Sprite
    LDA #%01000000
    STA sprite_player+SPRITE_ATTR

    MoveAllSpritesX sprite_player, #-1, #4

    LDX 1
    CheckSpriteCollisionWithXReg sprite_player, #8, #8, sprite_wall, #8,#8
    LDA collisionFlag
    BNE LookAt_RIGHT
    AddValue sprite_player + SPRITE_X, #1

    
;----------- RIGHT BUTTON--------;
LookAt_RIGHT:
    LDA joyPad1_state
    AND #BUTTON_RIGHT
    BEQ  LookAt_START  ;Branch if equal
    ;AddValue sprite_player + SPRITE_X, #1

    MoveAllSpritesX sprite_player, #1, #4

    ;FlipPlayer Sprite
    LDA #%00000000
    STA sprite_player+SPRITE_ATTR

    LDX 1
    CheckSpriteCollisionWithXReg sprite_player, #8, #8, sprite_wall, #8,#8
    LDA collisionFlag
    BNE LookAt_START
    AddValue sprite_player + SPRITE_X, #-1

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

ApplyPlayerPhysics:
    ApplyPhysics player_movement, sprite_player, #3
    RTS

;--------------------------------------SPAWNING----------------------------;
TrySpawnBullet:
    LDA bulletFlag
    AND #BULLET_ACTIVE
    BEQ SpawnBullet
    RTS

SpawnBullet:

    ; Spawn a bullet
    LDA  sprite_player + SPRITE_Y      ; Y pos
    STA  sprite_bullet + SPRITE_Y

    LDA  bulletSprites         ; Tile number
    STA  sprite_bullet + SPRITE_TILE

    LDA sprite_player + SPRITE_ATTR         ; Attributes ????
    STA sprite_bullet + SPRITE_ATTR

    LDA sprite_player + SPRITE_X     ; X pos
    STA sprite_bullet + SPRITE_X

    ;load bullet active flag
    LDA sprite_player + SPRITE_ATTR
    AND #BULLET_LEFT
    ORA #BULLET_ACTIVE
    STA bulletFlag
    RTS


GameUpdate:

UpdateBullet:
    LDA bulletFlag
    AND #BULLET_ACTIVE
    BEQ UpdateEnemies
    
    ;Branch to move bullt in Direction
    LDA bulletFlag
    AND #BULLET_LEFT
    BEQ BulletRight

BulletLeft:
    LDA sprite_bullet + SPRITE_X
    SEC
    SBC #1
    STA sprite_bullet + SPRITE_X
    BCS UpdateEnemies
 BulletRight:
    LDA sprite_bullet + SPRITE_X
    CLC
    ADC #1
    STA sprite_bullet + SPRITE_X
    BCC UpdateEnemies

    ;Kill bullet
    LDA #BULLET_INACTIVE
    STA bulletFlag
    LDA #248
    STA sprite_bullet + SPRITE_Y

    JMP UpdateEnemies


UpdateEnemies:
    LDX #(NUM_ENEMIES-1)*4
UpdateEnemiesLoop:
    LDA enemy_info + enemyStatus, x
    BEQ NotDead
    JMP UpdateEnemiesNoCollision

NotDead:

    LDA sprite_enemy+SPRITE_X, x
    CLC
    ADC enemy_info + enemy_speed, x
    STA sprite_enemy+SPRITE_X,X
    CMP  #256 - ENEMY_SPACING 
    BCS EnemyReverse
    CMP #ENEMY_SPACING
    BCC EnemyReverse
    JMP UpdateEnemiesNoReverse

EnemyReverse:
    LDA enemy_info + enemy_speed, x
    SignFlip
    STA enemy_info + enemy_speed, x


    
    LDA sprite_enemy+SPRITE_ATTR,X

    EOR #%01000000
    STA sprite_enemy+SPRITE_ATTR,X

UpdateEnemiesNoReverse:
    ; check collisions

    CheckSpriteCollisionWithXReg sprite_enemy, #8, #8, sprite_bullet, #8,#8

    LDA collisionFlag
    BNE CheckPlayerCollision

    ; Kill enemy
    LDA #%00000001
    STA enemy_info + enemyStatus, x

    ;Move enemy off screen
    LDA #128
    STA sprite_enemy + SPRITE_X, x
    STA sprite_enemy + SPRITE_Y, x

CheckPlayerCollision:
    CheckSpriteCollisionWithXReg sprite_enemy, #8,#8, sprite_player, #8,#8

    LDA collisionFlag
    BNE UpdateEnemiesNoCollision
    JMP RESET

UpdateEnemiesNoCollision:
    DEX
    DEX
    DEX
    DEX
    BMI UpdateReturnJump
    JMP UpdateEnemiesLoop

UpdateReturnJump:

    Jump enemy_movement, sprite_enemy
    ApplyPhysics enemy_movement, sprite_enemy, #1
    ApplyPhysics enemy_movement+5, sprite_enemy+4, #1
    ApplyPhysics enemy_movement+10, sprite_enemy+8, #1


    RTS

do_action:
       asl A
       tax
       lda table+1,x
       pha
       lda table,x
       pha
       rts

;--------------------- Data tabe-------------;
table: 
     .dw UpdateEnemiesNoCollision-1  
playerSprites:
    .db $00, $10, $20
playerGun:
    .db $11, $21, $01
enemySprites:
    .db $02, $12, $22
enemyArm:
    .db $13, $03, $23
bulletSprites:
    .db $31, $32
humanSpriteOffsets:
    .db -8,-8, -16, 0

SPRITE
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