;--------------------------------- IN GAME CONTROLLER ----------------------------;
InGameRead:
        JSR UpdateController


;----------- A BUTTON--------;
    LDA joyPad1_state
    AND #BUTTON_A
    BEQ  LookAtB   ;Branch if equal
    JSR TrySpawnBullet

;----------- B BUTTON--------;
LookAtB:
    ;Read B Button
    LDA joyPad1_state
    AND #BUTTON_B
    BEQ  LookAtUp   ;Branch if equal

    JSR TryDeployBarrier
   
;----------- UP BUTTON--------;
LookAtUp:
    LDA joyPad1_state
    AND #BUTTON_UP
    BEQ  LookAtDown   ;Branch if equal
    Jump player_movement, sprite_player

LookAtDown:
    LDA joyPad1_state
    AND #BUTTON_DOWN
    BEQ LookAtLeft

    LDA sprite_player + SPRITE_X
    STA sprite_poo + SPRITE_X

    LDA sprite_player + SPRITE_Y
    STA sprite_poo + SPRITE_Y


;----------- LEFT BUTTON--------;
LookAtLeft:
    LDA joyPad1_state
    AND #BUTTON_LEFT
    BEQ  LookAtRight   ;Branch if equal

    ;FlipPlayer Sprite
    LDA #%01000000
    STA sprite_player+SPRITE_ATTR

    DEC sprite_player + SPRITE_X

    ;Check for min X (stops wrapping)
    LDA sprite_player + SPRITE_X
    CMP #X_MIN
    BCC NoLeftMove

    LDX #0
    CheckSpriteCollisionWithXReg sprite_player, #8, #24, sprite_barrier, #W_WIDTH, #W_HEIGHT -#1, #0,#0
    LDA collision_flag
    BNE LookAtRight

NoLeftMove:
    INC sprite_player + SPRITE_X    
;----------- RIGHT BUTTON--------;
LookAtRight:
    LDA joyPad1_state
    AND #BUTTON_RIGHT
    BEQ  LookAtStart  ;Branch if equal

    ;FlipPlayer Sprite
    LDA #%00000000
    STA sprite_player+SPRITE_ATTR

    INC sprite_player + SPRITE_X

    ;Check for min X (stops wrapping)
    LDA sprite_player + SPRITE_X
    CMP #X_MAX
    BCS NoRightMove

    LDX #0
    CheckSpriteCollisionWithXReg sprite_player, #8, #24, sprite_barrier, #W_WIDTH, #W_HEIGHT -#1,#0, #0
    LDA collision_flag
    BNE LookAtStart

NoRightMove:
    DEC sprite_player + SPRITE_X

;----------- START BUTTON--------;
LookAtStart:
    LDA joyPad1_state
    AND #BUTTON_START
    BEQ LookAtSelect   ;Branch if equal
    LDA sprite_player + SPRITE_Y
    CLC
    ADC #1
    STA sprite_player + SPRITE_Y

 
;----------- SELECT BUTTON--------;
LookAtSelect:
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
    
    
    LDA player_shot_CD
    CMP #1
    BCS GunCoolDown


    LDA bullet_flag
    ;Check for bullet active
    AND #BULLET_ACTIVE
    BNE NoSpawnBullet

    ;If we get here we know we have successfully shot
    LDA #BULLET_FIRE_CD
    STA player_shot_CD

    LDA #1
    STA player_anim + anim_status
    STA player_anim + anim_index
    STA player_anim + anim_cd
    
    ; Spawn a bullet
    LDA  sprite_player + WEAPON_OFFSET + SPRITE_Y      ; Y sub_pos
    STA  sprite_bullet + SPRITE_Y

    LDA  bulletSprites         ; Tile number
    STA  sprite_bullet + SPRITE_TILE

    LDA sprite_player + SPRITE_ATTR         ; Attributes ????
    STA sprite_bullet + SPRITE_ATTR

    LDA sprite_player + WEAPON_OFFSET + SPRITE_X      ; X sub_pos
    STA sprite_bullet + SPRITE_X

    ;load bullet active flag
    LDA sprite_player + SPRITE_ATTR
    AND #BULLET_LEFT
    ORA #BULLET_ACTIVE
    STA bullet_flag
    RTS
GunCoolDown:
    DEC player_shot_CD
NoSpawnBullet:
    RTS

GameUpdate:

UpdateBullet:
    LDA bullet_flag
    AND #BULLET_ACTIVE
    BEQ UpdateEnemies

    ;Set the player gun pallette to normal
    ;So we know the gun is not on cool down
    LDA sprite_player + 8 + SPRITE_ATTR
    ORA #%000000001
    STA sprite_player + 8 + SPRITE_ATTR

    LDA #1
    STA bullet_anim + anim_status
    AnimateSprite sprite_bullet, bulletSprites, bullet_anim
    ;Branch to move bullt in Direction
    LDA bullet_flag
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
    STA bullet_flag
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
    CMP  #X_MAX
    BCS EnemyReverse
    CMP #X_MIN
    BCC EnemyReverse

    CheckSpriteCollisionWithXReg sprite_enemy, #E_WIDTH, #E_HEIGHT, sprite_barrier, #W_WIDTH , #W_HEIGHT -#1, #0,#0

    LDA collision_flag
    BNE UpdateEnemiesNoReverse

    JSR DamageBarrier

EnemyReverse:
    LDA enemy_info + enemy_speed, x
    SignFlip
    STA enemy_info + enemy_speed, x

    LDA sprite_enemy+SPRITE_ATTR,X

    EOR #%01000000
    STA sprite_enemy+SPRITE_ATTR,X

    LDA #1
    STA enemy_anim + anim_status, x



UpdateEnemiesNoReverse:
    ; check collisions

    CheckSpriteCollisionWithXReg sprite_enemy, #E_WIDTH, #E_HEIGHT, sprite_bullet, #8,#8, #0,#0

    LDA collision_flag
    BNE CheckPlayerCollision

    ; Decrement enemy health
    LDA enemy_info + enemy_health, x
    SEC
    SBC #1
    STA enemy_info + enemy_health, x


    ;Kill bullet
    LDA #BULLET_INACTIVE
    STA bullet_flag
    LDA #248
    STA sprite_bullet + SPRITE_Y

    ; Check to see if the player has killed 
    ; all the enemies
    INC player_kills
    LDA player_kills
    CMP #2*NUM_ENEMIES
    BCC CheckPlayerCollision

    LDA #0
    STA player_kills

    JSR WaveComplete

CheckPlayerCollision:
    CheckSpriteCollisionWithXReg sprite_enemy, #E_WIDTH, E_HEIGHT, sprite_player, #P_WIDTH,#P_HEIGHT, #0,#0

    LDA collision_flag
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
    OutOfLoopEnemyUpdate enemy_movement, sprite_enemy, sprite_e_body, enemy_anim, enemy_info, enemy_head_m
    OutOfLoopEnemyUpdate enemy_movement+5, sprite_enemy+4, sprite_e_body+12, enemy_anim+4 , enemy_info + 4, enemy_head_m + 5
    OutOfLoopEnemyUpdate enemy_movement+10, sprite_enemy+8, sprite_e_body+24, enemy_anim+8, enemy_info + 8, enemy_head_m + 10


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

    TAX
    LDY #0
    MultiplyY #4

    LDA #245
    STA sprite_health + SPRITE_Y, y

    ;Check for player dead
    LDA player_health
    CMP #1
    BCS PlayerNotDead
    ;Player dead
    JMP GameComplete

PlayerNotDead:
    LDA #100
    STA start_cd

    LDA #126
    STA sprite_player + SPRITE_X
    STA sprite_player + SPRITE_Y

    RTS

InitStartScreen:

    ;Press A message Using sprite Enemy because we know they're
    ;going to be overridden when the game actually start
    InitSpriteAtPos sprite_enemy, #120, #136, press_sprites,#%000100001
    InitSpriteAtPos sprite_enemy+4, #128, #136, press_sprites+1, #%000100001
    InitSpriteAtPos sprite_enemy+8, #136, #136, press_sprites+2, #%000100001
    InitSpriteAtPos sprite_enemy+12, #144, #136, press_sprites+3, #%000100001
    InitSpriteAtPos sprite_enemy+16, #152, #136, press_sprites+4, #%000100001
    InitSpriteAtPos sprite_enemy+20, #176, #136, aSprite, #%000100001


    RTS

InitBarrier:
    InitSpriteAtPos sprite_barrier , #0, #245, barrier_sprites, #%00000000
    InitSpriteAtPos sprite_barrier +4, #0, #245, barrier_sprites+1, #%00000000
    InitSpriteAtPos sprite_barrier +8, #0, #245, barrier_sprites+2, #%00000000
    InitSpriteAtPos sprite_barrier +12, #0, #245, barrier_sprites+3, #%00000000
    LDA #2
    STA barrier_health

    RTS

TryDeployBarrier:
     ;If Barrier is on CD dont spawn look at next
    LDA barrier_CD
    CMP #1
    BCS FailedToSpawnBarrier

    ;reset barrier health and sprites
    JSR InitBarrier

    ;get the direction of the player and branch depending on dir
    LDA sprite_player + SPRITE_ATTR
    AND #%01000000
    BNE SpawnWallLeft

    ;We are facing right here so deploy right
    LDA sprite_player + 8 + SPRITE_X
    CLC
    ADC #5
    JMP SpawnWall

SpawnWallLeft:
    LDA sprite_player + 8 + SPRITE_X
    SEC
    SBC #W_HEIGHT

SpawnWall:
    ; set sprite wall with the value stored in A (which is directional) offset
    STA sprite_barrier + SPRITE_X

    ;Set the barrier to spawn always on the floor
    LDA #FLOORHEIGHT 
    STA sprite_barrier + SPRITE_Y

    ;Set barrier on cool down
    LDA #W_COOLDOWN
    STA barrier_CD
        
    ;If spawn a wall do nothing else this controller input
    JMP ControllerReadFinished

FailedToSpawnBarrier:
    RTS

UpdateBarrier:
    UpdateSpritesToRoot sprite_barrier, #3, sprite_barrier+4, wallXOffsets, wallYOffsets
    LDA barrier_CD
    CMP #1
    BCS Barrier_On_CD
    RTS
Barrier_On_CD:
    DEC barrier_CD
    RTS

DamageBarrier:
    LDY barrier_health
    DEY
    STY barrier_health
    BNE BarrierOK

    LDA #W_COOLDOWN
    STA barrier_CD

    LDA #245
    STA sprite_barrier + SPRITE_Y

BarrierOK:

    STX temp_x
    ; If barrier was hit and is now ok
    ;Make the wall broken
    LDA barrier_health
    TAX
    LDY #0
    MultiplyY #4
    LDA broken_barrier_sprites
    STA sprite_barrier + SPRITE_TILE
    STA sprite_barrier + SPRITE_TILE+4
    STA sprite_barrier + SPRITE_TILE+8
    STA sprite_barrier + SPRITE_TILE+12

    LDX temp_x
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
    STA sprite_enemy+20 + SPRITE_ATTR

    ;reset cooldown
    LDA #FLASH_RATE
    STA flash_cd

    JMP EndFlash
NoFlash:
    DEC flash_cd
EndFlash:
    RTS

InitWaveSprites:
    ;Could initialise sprites in a loop, although this is code duplication, it is more efficient this way
    ; and there is less code total
    InitSpriteAtPos sprite_Wave, #200, #10,  WaveSprites, #%00000001
    InitSpriteAtPos sprite_Wave+4, #210, #10,  WaveSprites +1, #%00000001
    RTS



InitLoseSprites:

    ;Could initialise sprites in a loop, although this is code duplication, it is more efficient this way
    ; and there is less code total
    InitSpriteAtPos sprite_enemy, #120, #136, DeadSprites, #%00000001
    InitSpriteAtPos sprite_enemy+4, #128, #136, DeadSprites+1, #%00000001
    InitSpriteAtPos sprite_enemy+8, #136, #136, DeadSprites+2, #%00000001
    InitSpriteAtPos sprite_enemy+12, #144, #136, DeadSprites+3, #%00000001
    LDA #248
    STA sprite_enemy + SPRITE_Y + 16
    STA sprite_enemy + SPRITE_Y + 20
    RTS

InitWinSprites:
    InitSpriteAtPos sprite_enemy, #120, #136, GGsprites, #%00000001
    InitSpriteAtPos sprite_enemy+4, #128, #136, GGsprites+1, #%00000001
    LDA #248
    STA sprite_enemy + SPRITE_Y + 8
    STA sprite_enemy + SPRITE_Y + 12
    STA sprite_enemy + SPRITE_Y+ 16
    STA sprite_enemy + SPRITE_Y+ 20
    RTS

WaveComplete:
    INC player_waves
    LDA player_waves
    CMP #NUMBER_OF_WAVES
    BCS GameComplete

    LDY player_waves
    LDA WaveSprites + 1,y 
    STA sprite_Wave + 4 + SPRITE_TILE
    LDA #100
    STA start_cd
    
    JSR InitEnemies
    RTS
GameComplete:
    LDA #S_ENDGAME
    STA my_state
    LDA #100
    STA start_cd

    LDA player_health
    CMP #1
    BCS Win

    JSR InitLoseSprites

    JMP Forever
Win:
    JSR InitWinSprites

    JMP Forever

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

    LDA #0
    STA player_waves

    InitSpriteAtPos sprite_health, #10, #10,  HeartSprite, #%00000001
    InitSpriteAtPos sprite_health+4, #20, #10,  HeartSprite, #%00000001
    InitSpriteAtPos sprite_health+8, #30, #10,  HeartSprite, #%00000001

;--------------------- Poo sprite data --------------------;

    InitSpriteAtPos sprite_poo, #126,#126, #$40, #%00000000

    LDA #3
    STA poo_anim + anim_max_index

;---------------- Bullet Anim Data ------------------;

    LDA #3
    STA bullet_anim + anim_max_index

    LDA #BULLET_FIRE_CD
    STA player_shot_CD
;--------------------- wall Data --------------;
    ; Write sprite data for 0 OAM memory Object memory
    JSR InitBarrier



;--------- Init wave sprites ------------;
    JSR InitWaveSprites

;----------- Init Enemies -------------;

    JSR InitEnemies


InitEnemies:
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