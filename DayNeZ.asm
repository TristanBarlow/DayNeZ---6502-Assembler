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

S_TITLE_SCREEN = %00000001
S_INGAME       = %00000010

ENEMY_SQUAD_WIDTH = 3
ENEMY_SQUAD_HEIGHT = 1
NUM_ENEMIES  = ENEMY_SQUAD_HEIGHT * ENEMY_SQUAD_WIDTH
ENEMY_SPACING = 16
JUMP_FORCE = -(256+128)
PLAYER_X_SPEED = 1
E_ROOT_SPRITE_OFFSET = 16

WEAPON_OFFSET = 8

W_WIDTH = 8
W_HEIGHT = 8

P_WIDTH = 8
P_HEIGHT = 24

E_WIDTH = 8
E_HEIGHT = 24
E_X_SPEED = 1

ANIM_FRAME_SPEED = 4

GRAVITY  =   8     ; Sub pixel per frame 
MAX_Y_SPEED = 20      ; pixel per frame
FLOORHEIGHT = 210
GROUND_FRICTION = 1  ; Sub pixel per frame

BULLET_INACTIVE = %00000000
BULLET_ACTIVE   = %00000001
BULLET_RIGHT    = %00000000
BULLET_LEFT     = %01000000
BULLET_SPEED    = 3

ANIM_INACTIVE   = %00000000
FLASH_RATE      =30

    .rsset $0000
joyPad1_state   .rs 1
bulletFlag      .rs 1
enemy_info      .rs 4 * NUM_ENEMIES
collisionFlag   .rs 1
temp_x          .rs 1
temp_y          .rs 1
active_sprite   .rs 1
nametable_add   .rs 2
my_state        .rs 1
player_health   .rs 1
player_kills    .rs 1
flash_cd        .rs 1



    .rsset $0000
speedY          .rs 2 ; sub pixels per frame
speedX          .rs 2 ; sub pixels per frame
pos             .rs 1 ; sub pixel movement position

    .rsset $0200
sprite_player .rs 4 * 4
sprite_bullet .rs 4
sprite_wall   .rs 4
sprite_poo    .rs 4
sprite_health .rs 4  * 3
sprite_enemy  .rs 4 * NUM_ENEMIES
sprite_e_body .rs 12 * NUM_ENEMIES


    .rsset $0300
player_movement .rs 5
poo_movement    .rs 5


    .rsset $0400
player_anim     .rs 4
poo_anim        .rs 4
bullet_anim     .rs 4
enemy_anim      .rs 4 * NUM_ENEMIES

    .rsset $0500
enemy_movement  .rs 5 * NUM_ENEMIES
enemy_m_head    .rs 5 * NUM_ENEMIES

    .rsset $0000
SPRITE_Y .rs 1
SPRITE_TILE .rs 1
SPRITE_ATTR .rs 1
SPRITE_X .rs 1

    .rsset $0000
enemy_speed .rs 1
enemyStatus .rs 1
enemy_health .rs 1
enemy_blank  .rs 1

    .rsset $0000
anim_cd         .rs 1
anim_index      .rs 1
anim_max_index  .rs 1
anim_status     .rs 1



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
;| 1: value |2: times
MultiplyY .macro
MultiplyLoop\@:
    TYA
    CLC
    ADC #\1
    TAY
    
    DEX
    CPX #1
    BCS MultiplyLoop\@

    .endm
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

;| 1: movement| 2: sprite | 3: body |4 anim | 5: enemy info | 6: Enemy Head
OutOfLoopEnemyUpdate .macro
    LDA \5 + enemy_health
    BMI Dead\@
    JMP CheckForHead\@

Dead\@:
    LDA #240
    STA \2 + SPRITE_Y
    UpdateSpritesToRoot \2,#2, \3, humanSpriteXOffsets, humanSpriteYOffsets
    JMP DoHeadPhyscis\@

CheckForHead\@:
    Jump \1, \2
    ApplyPhysics \1,\2
    AnimateSprite \3 + 4, enemyArm, \4

    LDA \5 + enemy_health
    CMP #1
    BCC NoHead\@
    UpdateSpritesToRoot \2,#3, \3,  humanSpriteXOffsets, humanSpriteYOffsets
    JMP EndUpdate\@
NoHead\@:
    ;render one less
    UpdateSpritesToRoot \2,#2, \3,  humanSpriteXOffsets, humanSpriteYOffsets
    LDA #1
    STA \4 +anim_status
DoHeadPhyscis\@:
    ApplyPhysics \6, \3 + 8
EndUpdate\@:
    .endm

;| sprite to change | sprite Table| anim Data |
AnimateSprite .macro
    ; Load in to see if we're still going to animate
    LDA \3 + anim_status
    BEQ EndAnim\@

    ;Load number of frames left before anim change
    LDA \3 + anim_cd
    BMI ChangeAnim\@

    ;Subtract one if frames left is still positive
    SEC
    SBC #1
    STA \3 + anim_cd
    JMP EndAnim\@


ChangeAnim\@:
    ;Load current index check to see if greater than max
    LDA \3 + anim_index
    CMP \3 + anim_max_index
    BCS  FinishedAnim\@

    ;Change sprite

    ; load sprite index into y
    LDY \3 + anim_index
    LDA \2, y
    STA \1 + SPRITE_TILE

    INY
    STY \3 + anim_index

    ;Set anim cd back to max
    LDA #ANIM_FRAME_SPEED
    STA \3 + anim_cd
    JMP EndAnim\@

FinishedAnim\@:
    ;Finished anim so set to inactive
    LDA #0
    STA \3 + anim_status
    STA \3 + anim_index

    LDY \3 + anim_index
    LDA \2, y
    STA \1 + SPRITE_TILE

EndAnim\@:
    .endm

;1: root  |2: numberOf Sprites |3: sprite Array|4: xOFFsets| 5: Y OFFsets
UpdateSpritesToRoot .macro
    .if \2 > 1
    ; Apply the Y to the rest of the sprites
    LDX #((\2-1) * 4)
    LDY #(\2-1)
ApplyToSprites\@:
    LDA \1 + SPRITE_Y
    CLC
    ADC \5, y
    STA \3 + SPRITE_Y,x

    LDA \1 + SPRITE_ATTR
    STA \3 + SPRITE_ATTR, x

    AND #%01000000
    BNE LeftFacing\@

    LDA \1+SPRITE_X
    CLC
    ADC \4, y
    STA \3 + SPRITE_X,x
    JMP FinishedXMove\@

LeftFacing\@:
    LDA \1+SPRITE_X
    SEC
    SBC \4, y
    STA \3 + SPRITE_X,x

FinishedXMove\@:
    DEX
    DEX
    DEX
    DEX
    DEY
    BPL ApplyToSprites\@
    .endif
    .endm


;|main sprie | X move | sprite Num
MoveAllSpritesX .macro
    ;Load in the number of sprites* size of memory
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

;| 1: Movement Variable | 2: sprite 
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

    LDX #0
    
    CheckSpriteCollisionWithXReg \2, #8,#0, sprite_wall, #8,#8, #1,#0
    LDA collisionFlag
    BEQ Onbarrier\@


    JMP ReturnFromApplyPhysics\@

Onbarrier\@:
    LDA #0
    STA \1 +speedY
    STA \1 +speedY+1
    STA \1 + pos


    LDA sprite_wall + SPRITE_Y
    SEC
    SBC #9
    STA \2 + SPRITE_Y
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
;| 1: sprite1| 2 : w1 | 3 : h1 | 4 : sprite2 | 5 : w2 | 6 :  h2| 7: xMove | 8:yMove
CheckSpriteCollisionWithXReg .macro 
    LDA #%00000000
    STA collisionFlag

    LDA \1 + SPRITE_X, x      ; load x1
    SEC
    SBC #\5 + #\7   ; subtract w2
    CMP \4 + SPRITE_X          ;compare with x2  
    BCS NoCollision\@ ; branch if x1-w2 >=


    CLC 
    ADC #\2 + #\5  + #\7    ; Add width 1 and width 2 AND the x movement
    CMP \4 + SPRITE_X          ; compare to x2
    BCC NoCollision\@ ; branch if no collision
    
    LDA \1 + SPRITE_Y, x ; caluclate y_enemy - bullet width(y1 - h2)
    CLC
    ADC #\6 +#\8                    ; assume w2 = 8
    CMP \4+SPRITE_Y         ;compare with x  bullet   
    BCC NoCollision\@ ; branch if x1-w2 >=

    SEC 
    SBC #\3+#\6  + #\8            ; Calculat x_enemy + w_eneym (x1 + w1) assuming w1 = 8
    CMP \4+SPRITE_Y 
    BCC EndCollision\@ ; 

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
    LDA #$0F
    STA PPUDATA
    LDA #$00
    STA PPUDATA
    LDA #$1C
    STA PPUDATA
    LDA #$08
    STA PPUDATA

    ; Write Address $3F10 (sprite colour) to the ppu
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

    ; Write pallet 01
    LDA #$0F
    STA PPUDATA
    LDA #$15
    STA PPUDATA
    LDA #$05
    STA PPUDATA
    LDA #$15
    STA PPUDATA

    ;load nametable data
    LDA #$20            ; write adress 
    STA PPUADDR  
    LDA #$00
    STA PPUADDR
    
    JSR LoadNameTables

    JSR InitStartScreen

    LDA #%00011000   ;intensify blues
    STA PPUMASK

    LDA #%10000000   ;intensify blues
    STA PPUCTRL


    LDA #0
    STA PPUSCROLL   ;se x scroll
    STA PPUSCROLL   ;set y scroll

Forever:
    JMP Forever     ;jump back to Forever, infinite loop


;------------------------------- GAME UPDATE -------------------------;
NMI:

    LDA my_state
    AND #S_INGAME
    BEQ TitleScreen

;-------- In game -----;

; INGAME CONTROLS
    JSR InGameRead
; Perform game update
    JSR GameUpdate

    JMP EndNMI

TitleScreen:
    JSR FlashMessageSprites
    JSR UpdateController
    LDA joyPad1_state
    AND #BUTTON_A
    BEQ  EndNMI   ;Branch if equal
    LDA #S_INGAME
    STA my_state
    JSR InitGame


EndNMI:
    ;copy sprite data to the ppu#
    LDA #0
    STA OAMADDR
    LDA #$02
    STA OAMDMA

    RTI
    
;--------------------------------- IN GAME CONTROLLER ----------------------------;
InGameRead:
        JSR UpdateController


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

    ; spawn wall
    LDA sprite_player + SPRITE_X
    STA sprite_wall + SPRITE_X
    LDA sprite_player + SPRITE_Y
    STA sprite_wall + SPRITE_Y


;----------- UP BUTTON--------;
LookAt_UP:
    LDA joyPad1_state
    AND #BUTTON_UP
    BEQ  LookAt_Down   ;Branch if equal
    Jump player_movement, sprite_player

LookAt_Down:
    LDA joyPad1_state
    AND #BUTTON_DOWN
    BEQ LookAt_LEFT

    LDA sprite_player + SPRITE_X
    STA sprite_poo + SPRITE_X

    LDA sprite_player + SPRITE_Y
    STA sprite_poo + SPRITE_Y


;----------- LEFT BUTTON--------;
LookAt_LEFT:
    LDA joyPad1_state
    AND #BUTTON_LEFT
    BEQ  LookAt_RIGHT   ;Branch if equal

    ;FlipPlayer Sprite
    LDA #%01000000
    STA sprite_player+SPRITE_ATTR


    LDX #0
    CheckSpriteCollisionWithXReg sprite_player, #8, #24, sprite_wall, #8,#8, #-1,#0
    LDA collisionFlag
    BEQ LookAt_RIGHT
    AddValue sprite_player+SPRITE_X, #-1
    
;----------- RIGHT BUTTON--------;
LookAt_RIGHT:
    LDA joyPad1_state
    AND #BUTTON_RIGHT
    BEQ  LookAt_START  ;Branch if equal

    ;FlipPlayer Sprite
    LDA #%00000000
    STA sprite_player+SPRITE_ATTR
    
    LDX #0
    CheckSpriteCollisionWithXReg sprite_player, #8, #24, sprite_wall, #8,#8,#1, #0
    LDA collisionFlag
    BEQ LookAt_START
    AddValue sprite_player+SPRITE_X, #1

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
    ApplyPhysics player_movement, sprite_player
    UpdateSpritesToRoot sprite_player, #3, sprite_player + 4,  humanSpriteXOffsets, humanSpriteYOffsets
    AnimateSprite sprite_player + 8, playerGun, player_anim

    ; Update poo stuff
    LDA #1
    STA poo_anim + anim_status
    AnimateSprite sprite_poo, pooSprites, poo_anim
    ApplyPhysics poo_movement , sprite_poo
     
    RTS

;--------------------------------------SPAWNING----------------------------;
TrySpawnBullet:
    LDA bulletFlag
    AND #BULLET_ACTIVE
    BEQ SpawnBullet
    RTS

SpawnBullet:

    LDA #1
    STA player_anim + anim_status
    STA player_anim + anim_index
    STA player_anim + anim_cd
    
    ; Spawn a bullet
    LDA  sprite_player + WEAPON_OFFSET + SPRITE_Y      ; Y pos
    STA  sprite_bullet + SPRITE_Y

    LDA  bulletSprites         ; Tile number
    STA  sprite_bullet + SPRITE_TILE

    LDA sprite_player + SPRITE_ATTR         ; Attributes ????
    STA sprite_bullet + SPRITE_ATTR

    LDA sprite_player + WEAPON_OFFSET + SPRITE_X      ; X pos
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

    LDA #1
    STA bullet_anim + anim_status
    AnimateSprite sprite_bullet, bulletSprites, bullet_anim
    ;Branch to move bullt in Direction
    LDA bulletFlag
    AND #BULLET_LEFT
    BEQ BulletRight

BulletLeft:
    LDA sprite_bullet + SPRITE_X
    SEC
    SBC #BULLET_SPEED
    STA sprite_bullet + SPRITE_X
    BCS UpdateEnemies
 BulletRight:
    LDA sprite_bullet + SPRITE_X
    CLC
    ADC #BULLET_SPEED
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
    LDA enemy_info + enemy_health, x
    BPL NotDead
    JMP UpdateEnemiesNoCollision

NotDead:

    LDA sprite_enemy+SPRITE_X, x
    CLC
    ADC enemy_info + enemy_speed, x
    STA sprite_enemy+SPRITE_X,X
    CMP  #256 - 8 
    BCS EnemyReverse
    CMP #8
    BCC EnemyReverse

    CheckSpriteCollisionWithXReg sprite_enemy, #E_WIDTH, #E_HEIGHT, sprite_wall, #8,#8, #0,#0

    LDA collisionFlag
    BEQ EnemyReverse

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

    CheckSpriteCollisionWithXReg sprite_enemy, #E_WIDTH, #E_HEIGHT, sprite_bullet, #8,#8, #0,#0

    LDA collisionFlag
    BNE CheckPlayerCollision

    ; Decrement enemy health
    LDA enemy_info + enemy_health, x
    SEC
    SBC #1
    STA enemy_info + enemy_health, x


    ;Kill bullet
    LDA #BULLET_INACTIVE
    STA bulletFlag
    LDA #248
    STA sprite_bullet + SPRITE_Y

    INC player_kills
    LDA player_kills
    CMP #2*NUM_ENEMIES
    BCC CheckPlayerCollision
    JMP RESET

CheckPlayerCollision:
    CheckSpriteCollisionWithXReg sprite_enemy, #E_WIDTH, E_HEIGHT, sprite_player, #P_WIDTH,#P_HEIGHT, #0,#0

    LDA collisionFlag
    BNE UpdateEnemiesNoCollision

    JSR PlayerDamaged
    
    LDA #1
    STA enemy_anim +anim_status,x

UpdateEnemiesNoCollision:

    DEX
    DEX
    DEX
    DEX
    BMI UpdateReturnJump
    JMP UpdateEnemiesLoop

UpdateReturnJump:
    OutOfLoopEnemyUpdate enemy_movement, sprite_enemy, sprite_e_body, enemy_anim, enemy_info, enemy_m_head
    OutOfLoopEnemyUpdate enemy_movement+5, sprite_enemy+4, sprite_e_body+12, enemy_anim+4 , enemy_info + 4, enemy_m_head + 5
    OutOfLoopEnemyUpdate enemy_movement+10, sprite_enemy+8, sprite_e_body+24, enemy_anim+8, enemy_info + 8, enemy_m_head + 10


    RTS
UpdateController:
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

    RTS

LoadNameTables:

    LDA #LOW(NameTableLabel)
    STA nametable_add
    LDA #HIGH(NameTableLabel)
    STA nametable_add + 1
NameTableOuterLoop:
    LDY #0
NameTableInnerLoop:
    LDA [nametable_add],y
    BEQ NameTableEnd
    STA PPUDATA
    INY
    BNE NameTableInnerLoop

    INC nametable_add + 1
    JMP NameTableOuterLoop
NameTableEnd:
    RTS

PlayerDamaged:
    LDA player_health
    SEC
    SBC #1
    STA player_health

    CMP #1
    BCS PlayerNotDead
    ;Player dead
    JMP RESET

PlayerNotDead:
    TAX
    LDY #0
    MultiplyY #4

    LDA #245
    STA sprite_health + SPRITE_Y, y

    LDA #0
    STA sprite_player + SPRITE_X
    STA sprite_player + SPRITE_Y

    RTS

InitStartScreen:

    ;Press A message Using sprite Enemy because we know they're
    ;going to be overridden when the game actually start
    InitSpriteAtPos sprite_enemy, #120, #136, press_sprites, #%00000001
    InitSpriteAtPos sprite_enemy+4, #128, #136, press_sprites+1, #%00000001
    InitSpriteAtPos sprite_enemy+8, #136, #136, press_sprites+2, #%00000001
    InitSpriteAtPos sprite_enemy+12, #144, #136, press_sprites+3, #%00000001
    InitSpriteAtPos sprite_enemy+16, #152, #136, press_sprites+4, #%00000001
    InitSpriteAtPos sprite_enemy+24, #176, #136, aSprite, #%00000001


    RTS

FlashMessageSprites:
    ;load flash coold down
    LDA flash_cd

    ;branch if it not time to switch flash
    BNE NoFlash
    
    ;Load in current sprite attribute and flip it
    LDA sprite_enemy + SPRITE_ATTR
    EOR #%00100000

    ;Put the pallet back to 1 (messgae pallet)
    ORA #%00000001

    ;Store all the new attribute in the sprites
    STA sprite_enemy   + SPRITE_ATTR
    STA sprite_enemy+4 + SPRITE_ATTR
    STA sprite_enemy+8 + SPRITE_ATTR
    STA sprite_enemy+12 + SPRITE_ATTR
    STA sprite_enemy+16 + SPRITE_ATTR
    STA sprite_enemy+24 + SPRITE_ATTR

    ;reset cooldown
    LDA #FLASH_RATE
    STA flash_cd

    JMP EndFlash
NoFlash:
    DEC flash_cd
EndFlash:
    RTS


InitGame:
    ;--------------------- Player Sprite Data --------------;

InitPlayerSprites:

    ;legs
    InitSpriteAtPos sprite_player, #220, #220,  #$20, #%00000000

    ;body
    InitSpriteAtPos sprite_player + 4, #0, #00,  #$10, #%00000000

    ;gun
    InitSpriteAtPos sprite_player + 8 ,#0, #0,  #$11, #%00000000
    
    ;head
    InitSpriteAtPos sprite_player + 12, #0, #0,  #$00, #%00000000


; Init anim data for player
    LDA #3
    STA player_anim + anim_max_index

    LDA #3
    STA player_health

    InitSpriteAtPos sprite_health, #10, #10,  HeartSprite, #%00000001
    InitSpriteAtPos sprite_health+4, #20, #10,  HeartSprite, #%00000001
    InitSpriteAtPos sprite_health+8, #30, #10,  HeartSprite, #%00000001

;--------------------- Poo sprite data --------------------;

    InitSpriteAtPos sprite_poo, #255,#255, #$40, #%00000000

    LDA #3
    STA poo_anim + anim_max_index

;---------------- Bullet Anim Data ------------------;

    LDA #3
    STA bullet_anim + anim_max_index
;--------------------- wall Data --------------;
    ; Write sprite data for 0 OAM memory Object memory
    LDA  #FLOORHEIGHT      ; Y pos
    STA  sprite_wall + SPRITE_Y

    LDA  #$50        ; Tile number
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
    LDA #230
    STA sprite_enemy + SPRITE_Y,x
    LDA #$22 
    STA sprite_enemy + SPRITE_TILE, X
    LDA #%00000000   
    STA sprite_enemy+ SPRITE_ATTR, x


    STA enemy_info + enemyStatus,x

    LDA #1
    STA enemy_info + enemy_health, x

    LDA #E_X_SPEED
    STA enemy_info + enemy_speed, x

    LDA #4
    STA enemy_anim + anim_max_index,x

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


;------- Init enemy body parts ---------;
    LDX #(NUM_ENEMIES * 12)
    LDY #0

LoadBodySprite:

    ; X and Y will be overriden they dont matter
    LDA #0
    STA sprite_e_body + SPRITE_X, x
    STA sprite_e_body + SPRITE_Y,x   
    LDA enemySprites, y
    STA sprite_e_body + SPRITE_TILE, X
    LDA #%00000000 
    STA sprite_e_body+ SPRITE_ATTR, x

    DEX
    DEX
    DEX
    DEX

    INY
    TYA
    CMP #3
    BCC LoadBodySprite

    LDY #0

    TXA
    BPL LoadBodySprite



;----------- End Enemy loop -------------;
    RTS

NameTableLabel:
    .db $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77 
    .db $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77 

    .db $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77 
    .db $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77 
    .db $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77 
    .db $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77 

    .db $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77 
    .db $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77 
    .db $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77 
    .db $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77,   $77,$77,$77,$77 

    .db $76,$76,$76,$76,   $76,$76,$76,$76,   $76,$76,$76,$76,   $76,$76,$76,$76,   $76,$76,$76,$76,   $76,$76,$76,$76,   $76,$76,$76,$76,   $76,$76,$76,$76
    .db $76,$76,$76,$76,   $76,$76,$76,$76,   $76,$76,$76,$76,   $76,$76,$76,$76,   $76,$76,$76,$76,   $76,$76,$76,$76,   $76,$76,$76,$76,   $76,$76,$76,$76
    .db $76,$76,$76,$76,   $76,$76,$76,$76,   $76,$76,$76,$76,   $76,$76,$76,$76,   $76,$76,$76,$76,   $76,$76,$76,$76,   $76,$76,$76,$76,   $76,$76,$76,$76
    .db $76,$76,$76,$76,   $76,$76,$76,$76,   $76,$76,$76,$76,   $76,$76,$76,$76,   $76,$76,$76,$76,   $76,$76,$76,$76,   $76,$76,$76,$76,   $76,$76,$76,$76

    .db $04,$04,$04,$04,   $04,$04,$04,$04,   $05,$04,$04,$04,   $04,$04,$04,$04,   $04,$04,$04,$04,   $04,$04,$04,$04,   $04,$04,$04,$04,   $04,$04,$04,$04 
    .db $04,$04,$04,$04,   $04,$04,$04,$04,   $05,$04,$04,$04,   $04,$04,$04,$04,   $04,$04,$04,$04,   $04,$04,$04,$04,   $04,$04,$04,$04,   $04,$04,$04,$04                      
    .db $04,$04,$04,$04,   $04,$04,$04,$04,   $05,$04,$04,$04,   $04,$04,$04,$04,   $04,$04,$04,$04,   $04,$04,$04,$04,   $04,$04,$04,$04,   $04,$04,$04,$04 
    .db $04,$04,$04,$04,   $04,$04,$04,$04,   $05,$04,$04,$04,   $04,$04,$04,$04,   $04,$04,$04,$04,   $04,$04,$04,$04,   $04,$04,$04,$04,   $04,$04,$04,$04 

    .db $04,$05,$06,$07,   $04,$05,$06,$07,   $04,$05,$06,$07,   $04,$05,$06,$07,   $04,$05,$06,$07,   $04,$05,$06,$07,   $04,$05,$06,$07,   $04,$05,$06,$07
    .db $15,$14,$16,$17,   $15,$14,$16,$17,   $15,$14,$16,$17,   $15,$14,$16,$17,   $15,$14,$16,$17,   $15,$14,$16,$17,   $15,$14,$16,$17,   $15,$14,$16,$17                         
    .db $04,$05,$04,$05,   $04,$05,$04,$05,   $04,$05,$04,$05,   $04,$05,$04,$05,   $04,$05,$04,$05,   $04,$05,$04,$05,   $04,$05,$04,$05,   $04,$05,$04,$05
    .db $15,$14,$15,$14,   $15,$14,$15,$14,   $15,$14,$15,$14,   $15,$14,$15,$14,   $15,$14,$15,$14,   $15,$14,$15,$14,   $15,$14,$15,$14,   $15,$14,$15,$14

    .db $04,$05,$26,$27,   $04,$05,$26,$27,   $04,$05,$26,$27,   $04,$05,$26,$27,   $04,$05,$26,$27,   $04,$05,$26,$27,   $04,$05,$26,$27,   $04,$05,$26,$27 
    .db $15,$14,$36,$37,   $15,$14,$36,$37,   $15,$14,$36,$37,   $15,$14,$36,$37,   $15,$14,$36,$37,   $15,$14,$36,$37,   $15,$14,$36,$37,   $15,$14,$36,$37                      
    .db $47,$24,$25,$47,   $47,$24,$25,$47,   $47,$24,$25,$47,   $47,$24,$25,$47,   $47,$24,$25,$47,   $47,$24,$25,$47,   $47,$24,$25,$47,   $47,$24,$25,$47 
    .db $47,$34,$35,$47,   $47,$34,$35,$47,   $47,$34,$35,$47,   $47,$34,$35,$47,   $47,$34,$35,$47,   $47,$34,$35,$47,   $47,$34,$35,$47,   $47,$34,$35,$47  

    .db $54,$55,$56,$57,   $54,$55,$56,$57,   $54,$55,$56,$57,   $54,$55,$56,$57,   $54,$55,$56,$57,   $54,$55,$56,$57,   $54,$55,$56,$57,   $54,$55,$56,$57
    .db $54,$55,$56,$57,   $54,$55,$56,$57,   $54,$55,$56,$57,   $54,$55,$56,$57,   $54,$55,$56,$57,   $54,$55,$56,$57,   $54,$55,$56,$57,   $54,$55,$56,$57
    
    .db $54,$55,$56,$57,   $54,$55,$56,$57,   $54,$55,$56,$57,   $54,$55,$56,$57,   $54,$55,$56,$57,   $54,$55,$56,$57,   $54,$55,$56,$57,   $54,$55,$56,$57
    .db $54,$55,$56,$57,   $54,$55,$56,$57,   $54,$55,$56,$57,   $54,$55,$56,$57,   $54,$55,$56,$57,   $54,$55,$56,$57,   $54,$55,$56,$57,   $54,$55,$56,$57
    .db $00
  
    ;--- broken window
    .db $26,$27
    .db $36,$37
    ;--- window
    .db $06,$07
    .db $16,$17
    ;--- wall
    .db $04,$05
    .db $15,$14
    ;--- crack wall
    .db $24,$25
    .db $34,$35

    
;--------------------- Data tabe-------------;
table: 
     .dw UpdateEnemiesNoCollision-1  
playerSprites:
    .db $00, $10, $20
playerGun:
    .db $11, $21, $01
enemySprites:
    .db $12, $02, $13
enemyArm:
    .db $13,$33, $03, $23
pooSprites:
    .db $40,$41,$42
bulletSprites:
    .db $30, $31, $32

press_sprites:
    .db $80,$81,$82,$83, $83
aSprite:
    .db $90
GGsprites:
    .db $92, $92
DeadSprites:
    .db $93, $82, $90, $93
HeartSprite:
    .db $91

wallSprites:
    .db $50,$51,$61,$62
wallYOffsets:
    .db 8,0,8
wallXOffsets:
    .db 0,-8,-8
humanSpriteYOffsets:
    .db -8,-8, -16
humanSpriteXOffsets:
    .db 0,8, 0



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