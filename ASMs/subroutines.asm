;--------------------------------- Player Update ----------------------------;
UpdatePlayer:

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

    ;Use the players special ability
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

    ;Perform a subPixel calculation to move the player
    SubPixelMinusX player_movement, sprite_player,#P_X_PIXEL_SPEED, #P_X_SUB_SPEED

    ;Check for min X (stops wrapping)
    CMP #X_MIN
    BCC NoLeftMove

    ;Check to see if we hit the barrier
    LDX #0
    CheckSpriteCollisionWithXReg sprite_player, #P_WIDTH, #P_HEIGHT, sprite_barrier, #B_WIDTH, #B_HEIGHT -#1, #0,#0
    LDA collision_flag
    BNE LookAtRight

NoLeftMove:
    ;If the movement resulted in collision move the player back
    SubPixelAddX player_movement, sprite_player,#P_X_PIXEL_SPEED, #P_X_SUB_SPEED
;----------- RIGHT BUTTON--------;
LookAtRight:
    LDA joyPad1_state
    AND #BUTTON_RIGHT
    BEQ  LookAtStart  ;Branch if equal

    ;FlipPlayer Sprite
    LDA #%00000000
    STA sprite_player+SPRITE_ATTR

    ;Perform a subpixe
    SubPixelAddX player_movement, sprite_player,#P_X_PIXEL_SPEED, #P_X_SUB_SPEED

    ;Check for min X (stops wrapping)
    CMP #X_MAX
    BCS NoRightMove

    ;Check for collision with barrier
    LDX #0
    CheckSpriteCollisionWithXReg sprite_player, #P_WIDTH, #P_HEIGHT, sprite_barrier, #B_WIDTH, #B_HEIGHT -#1,#0, #0
    LDA collision_flag
    BNE LookAtStart

NoRightMove:
    ;Undo the right move if the move is invalid
    SubPixelMinusX player_movement, sprite_player,#P_X_PIXEL_SPEED, #P_X_SUB_SPEED

;----------- START BUTTON--------;
LookAtStart:
    LDA joyPad1_state
    AND #BUTTON_START
    BEQ LookAtSelect  

    ;Not currently doing anything but left in here 
    ;for completeness 

 
;----------- SELECT BUTTON--------;
LookAtSelect:
    LDA joyPad1_state
    AND #BUTTON_SELECT
    BEQ  ControllerReadFinished 

    ;Not currently doing anything but left in here 
    ;for completeness 

;----------- CONTROLLER FINISHED --------;
ControllerReadFinished:   

ApplyPlayerPhysics:
    ;Update all the player stuffs after all the inputs have been handled with
    ApplyPhysics player_movement, sprite_player
    UpdateSpritesToRoot sprite_player, #3, sprite_player + 4,  humanSpriteXOffsets, humanSpriteYOffsets
    AnimateSprite sprite_player + 8, playerGun, player_anim

    ; Update special ability stuff
    ;Force it to always animate
    LDA #ANIM_ACTIVE
    STA poo_anim + anim_status
    AnimateSprite sprite_poo, pooSprites, poo_anim
    ApplyPhysics poo_movement , sprite_poo
     
    RTS

;--------------------------------------SPAWNING----------------------------;
TrySpawnBullet:
    
    ;Load in number of frames until player can shoot again
    ;See if it is >=1 if try shoot, else reduce the cool down
    LDA player_shot_CD
    CMP #1
    BCS GunCoolDown

    ;Check to see if the bullet is active
    LDA bullet_flag
    AND #BULLET_ACTIVE
    BNE NoSpawnBullet

    ;If we get here we know we have successfully shot
    LDA #BULLET_FIRE_CD
    STA player_shot_CD

    ;Load the initial values to start the animation
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

    ;load bullet active flag and get direction of player, storing both in bullet flag
    LDA sprite_player + SPRITE_ATTR
    AND #BULLET_LEFT
    ORA #BULLET_ACTIVE
    STA bullet_flag
    RTS
GunCoolDown:
    ;decrement the counter until the gun can be shot again
    DEC player_shot_CD
NoSpawnBullet:
    RTS

GameUpdate:

UpdateBullet:
    ;Check to see if the bullet is active
    LDA bullet_flag
    AND #BULLET_ACTIVE
    BEQ UpdateEnemies

    ;Set the player gun pallette to normal
    ;So we know the gun is not on cool down
    LDA sprite_player + 8 + SPRITE_ATTR
    ORA #%000000001
    STA sprite_player + 8 + SPRITE_ATTR

    ;Start animation
    LDA #1
    STA bullet_anim + anim_status
    AnimateSprite sprite_bullet, bulletSprites, bullet_anim
    ;Branch to move bullt in Direction
    LDA bullet_flag
    AND #BULLET_LEFT
    BEQ BulletRight

BulletLeft:
    ;If the bullet is travelling left subtract
    LDA sprite_bullet + SPRITE_X
    SEC
    SBC #BULLET_SPEED
    STA sprite_bullet + SPRITE_X
    BCS UpdateEnemies
 BulletRight:
    ;If the bullet is travelling right add
    LDA sprite_bullet + SPRITE_X
    CLC
    ADC #BULLET_SPEED
    STA sprite_bullet + SPRITE_X
    BCC UpdateEnemies


    ;hide bullet of screen
    LDA #BULLET_INACTIVE
    STA bullet_flag
    LDA #248
    STA sprite_bullet + SPRITE_Y

    JMP UpdateEnemies


UpdateEnemies:
    ;Load in the max offset for enemies
    LDX #(NUM_ENEMIES-1)*4
UpdateEnemiesLoop:
    ;Load in the zombie health, to see if we should update it
    LDA enemy_info + enemy_health, x
    BNE NotDead

    ;Enemy is dead
    JMP EndUpdateEnemy
NotDead:

    ;Move the enemy by their current speed
    LDA sprite_enemy+SPRITE_X, x
    CLC
    ADC enemy_info + enemy_speed, x
    STA sprite_enemy+SPRITE_X,X


    ;Make sure the enemies dont wrap 
    CMP  #X_MAX
    BCS EnemyReverse
    CMP #X_MIN
    BCC EnemyReverse

    ;Check to see if the enemies are colliding with the barrier
    CheckSpriteCollisionWithXReg sprite_enemy, #E_WIDTH, #E_HEIGHT, sprite_barrier, #B_WIDTH , #B_HEIGHT -#1, #0,#0
    LDA collision_flag
    BNE UpdateEnemiesNoReverse

    ;If they have collided with the barrier, deal damage to it
    JSR DamageBarrier
    LDA #1
    STA enemy_anim + anim_status, x
EnemyReverse:

    ;Reverese the current enemy speed
    LDA enemy_info + enemy_speed, x
    SignFlip
    STA enemy_info + enemy_speed, x

    ;Flip the enemy base sprite
    LDA sprite_enemy+SPRITE_ATTR,X
    EOR #%01000000
    STA sprite_enemy+SPRITE_ATTR,X



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

    ;Check if the max amount of damage done has been done
    CMP #E_HEALTH*NUM_ENEMIES
    BCC CheckPlayerCollision

    ;If max has been done reset player kills and restart wave
    LDA #0
    STA player_kills
    JSR WaveComplete

CheckPlayerCollision:

    ;Check to see if the enemy has hit the player, if so damage the player
    CheckSpriteCollisionWithXReg sprite_enemy, #E_WIDTH, E_HEIGHT, sprite_player, #P_WIDTH,#P_HEIGHT, #0,#0
    LDA collision_flag
    BNE EndUpdateEnemy

    JSR PlayerDamaged
    
    ;Make the enemy hitting do an animation
    LDA #1
    STA enemy_anim +anim_status,x

EndUpdateEnemy:

    ;Decrement the offset and loop if should keep looping
    DEX
    DEX
    DEX
    DEX
    BMI UpdateReturnJump
    JMP UpdateEnemiesLoop

UpdateReturnJump:

    ;Do all the updating stuff that requires X,Y And A registers, could be done in the loop, but not 
    ;only is it more efficient this way, it also means we dont have to keep close track on which 
    ;reg/variable is tracking wich offset 
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

    ;Read the state of the controller and load it into the 
    ;the variables for use later
    ReadController:
    LDA JOYPAD1
    LSR A 
    ROL joyPad1_state
    INX
    CPX #8
    BNE ReadController

    RTS

LoadNameTables:
    ;Loads the name tables into the background
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

    ;Load player health and reduce it
    DEC player_health
    LDA player_health

    TAX
    LDY #0
    MultiplyY #4

    ;hide a heart
    LDA #245
    STA sprite_health + SPRITE_Y, y

    ;Check for player dead
    LDA player_health
    CMP #1
    BCS PlayerNotDead

    ;Player dead
    JMP GameComplete

PlayerNotDead:

    ;Player died, but its not game over so start a CD
    LDA #DEATH_COOL_DOWN
    STA start_cd

    ;Set player to reapawn point
    LDA #RESPAWN_X
    STA sprite_player + SPRITE_X
    LDA #RESPAWN_Y
    STA sprite_player + SPRITE_Y

    RTS

InitStartScreen:

    ;Press A message Using sprite Enemy because we know they're
    ;going to be overridden when the game actually start
    ;Some code duplication, but this is most efficient
    InitSpriteAtPos sprite_enemy,    #START_SCREEN_X   , #START_SCREEN_Y, press_sprites,#%000100001
    InitSpriteAtPos sprite_enemy+4,  #START_SCREEN_X+8 , #START_SCREEN_Y, press_sprites+1, #%000100001
    InitSpriteAtPos sprite_enemy+8,  #START_SCREEN_X+16, #START_SCREEN_Y, press_sprites+2, #%000100001
    InitSpriteAtPos sprite_enemy+12, #START_SCREEN_X+24, #START_SCREEN_Y, press_sprites+3, #%000100001
    InitSpriteAtPos sprite_enemy+16, #START_SCREEN_X+32, #START_SCREEN_Y, press_sprites+4, #%000100001
    InitSpriteAtPos sprite_enemy+20, #START_SCREEN_X+44, #START_SCREEN_Y, aSprite, #%000100001


    RTS

InitBarrier:

    ;Init the barrier sprites somewhere off screen they will be updated and 
    ;organised on demand.
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
    BNE DeployBarrierLeft

    ;We are facing right here so deploy right
    LDA sprite_player + WEAPON_OFFSET + SPRITE_X


    CMP #X_MAX - P_WIDTH - B_RIGHT_X_OFFSET     ;Check the box isnt going to go off screen 
    BCS FailedToSpawnBarrier

    ;If we are here we know the barrier is being placed in a sensible spot
    CLC
    ADC #B_RIGHT_X_OFFSET
    JMP DeployBarrier

DeployBarrierLeft:
    LDA sprite_player + 8 + SPRITE_X
    CMP #X_MIN + B_WIDTH   ;Check the box isnt going to go off screen
    BCC FailedToSpawnBarrier

    ;If we are here we know the barrier is being placed in a sensible spot
    SEC
    SBC #B_WIDTH

DeployBarrier:
    ; set sprite wall with the value stored in A (which is directional) offset
    STA sprite_barrier + SPRITE_X

    ;Set the barrier to spawn always on the floor
    LDA #FLOORHEIGHT 
    STA sprite_barrier + SPRITE_Y

    ;Set barrier on cool down
    LDA #B_COOLDOWN
    STA barrier_CD
        
    ;If spawn a wall do nothing else this controller input
    JMP ControllerReadFinished

FailedToSpawnBarrier:
    RTS

UpdateBarrier:
    ;Snaps all the sprites to the root sprite, with the given offsets
    UpdateSpritesToRoot sprite_barrier, #B_NUM_SPRITES -1, sprite_barrier+4, wallXOffsets, wallYOffsets
    
    ;Check to see if the barrier is on cool down if it is, decrement it cd
    LDA barrier_CD
    CMP #1
    BCS Barrier_On_CD
    RTS
Barrier_On_CD:
    DEC barrier_CD
    RTS

DamageBarrier:
    ;An enemy has hit the barrier, decrement health and check health isnt 0
    DEC barrier_health
    LDA barrier_health
    BNE BarrierOK

    ;If barrier is here, then it has died :( so add a cool down, so the player cant use it for a bit
    LDA #B_COOLDOWN
    STA barrier_CD

    ;Hide barrier
    LDA #245
    STA sprite_barrier + SPRITE_Y
    
    ;Put it behind the background just to make sure
    LDA #%00010001
    STA sprite_barrier + SPRITE_ATTR

BarrierOK:

    ;As damage ussually happens in loop with enemies, need to perserve X value
    STX temp_x

    ; If barrier was hit and is now ok
    ;Make the wall broken
    LDA barrier_health
    TAX
    LDY #0
    MultiplyY #4

    ;Just apply the same broken sprite to all of the barrier, saves time
    LDA broken_barrier_sprites
    STA sprite_barrier + SPRITE_TILE
    STA sprite_barrier + SPRITE_TILE+4
    STA sprite_barrier + SPRITE_TILE+8
    STA sprite_barrier + SPRITE_TILE+12

    ;put the x value back
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
    InitSpriteAtPos sprite_Wave, #WAVE_T_X, #WAVE_T_Y,  WaveSprites, #%00000001
    InitSpriteAtPos sprite_Wave+4, #WAVE_T_X + 10, #WAVE_T_Y,  WaveSprites +1, #%00000001
    RTS



InitLoseSprites:

    ;Could initialise sprites in a loop, although this is code duplication, it is more efficient this way
    ; and there is less code total
    InitSpriteAtPos sprite_enemy,    #END_GAME_MSG_X,    #END_GAME_MSG_Y, DeadSprites,   #%00000001
    InitSpriteAtPos sprite_enemy+4,  #END_GAME_MSG_X+8,  #END_GAME_MSG_Y, DeadSprites+1, #%00000001
    InitSpriteAtPos sprite_enemy+8,  #END_GAME_MSG_X+16, #END_GAME_MSG_Y, DeadSprites+2, #%00000001
    InitSpriteAtPos sprite_enemy+12, #END_GAME_MSG_X+24, #END_GAME_MSG_Y, DeadSprites+3, #%00000001

    ;Hide the excess enemuy sprites as they will still be flashing, but there is no point 
    ;writing a unique macro or sub when i can easily hide them
    LDA #248
    STA sprite_enemy + SPRITE_Y + 16
    STA sprite_enemy + SPRITE_Y + 20
    RTS

InitWinSprites:
    InitSpriteAtPos sprite_enemy,   #END_GAME_MSG_X, #END_GAME_MSG_Y, GGsprites, #%00000001
    InitSpriteAtPos sprite_enemy+4, #END_GAME_MSG_X+8, #END_GAME_MSG_Y, GGsprites+1, #%00000001
    ;Hide the excess enemuy sprites as they will still be flashing, but there is no point 
    ;writing a unique macro or sub when i can easily hide them
    LDA #248
    STA sprite_enemy + SPRITE_Y + 8
    STA sprite_enemy + SPRITE_Y + 12
    STA sprite_enemy + SPRITE_Y+ 16
    STA sprite_enemy + SPRITE_Y+ 20
    RTS

WaveComplete:
    ;Increase the value of waves complete, and check against how many waves are needed to win
    ;Branch accordingly
    INC player_waves
    LDA player_waves
    CMP #NUMBER_OF_WAVES
    BCS GameComplete

    ;If we're here we know we havent won, but we're a little bit closer
    ;Change the wave sprites to show the new wave score
    LDY player_waves
    LDA WaveSprites + 1,y 
    STA sprite_Wave + 4 + SPRITE_TILE

    ;set the wave cool down
    LDA #WAVE_COOL_DOWN
    STA start_cd
    
    ;Wave has been finished which means all the enemies are dead, so add re init them
    JSR InitEnemies
    RTS

GameComplete:
    ;Load the endgame state and store in the current state
    LDA #S_ENDGAME
    STA my_state

    ;Load a cool down so people read the end game message
    LDA #END_GAME_CD
    STA start_cd

    ;Now to check if the player has won or not
    LDA player_health

    ;If health>= 1 Winner Winner
    CMP #1
    BCS Win

    ;You lost init losing
    JSR InitLoseSprites

    ;Exit out of the current Loop
    JMP Forever
Win:
    ;Winner winner chicken for dinner
    JSR InitWinSprites

    ;Exit out of the current Loop    
    JMP Forever

InitGame:
    ;--------------------- Player Sprite Data --------------;

InitPlayerSprites:

    ;legs
    InitSpriteAtPos sprite_player, #P_SPAWN_X, #P_SPAWN_Y,  playerSprites, #%00000000

    ; As the legs are the route, they're the ones that only really matter
    ; when choosing where the player will spawn
    ;body
    InitSpriteAtPos sprite_player + 4, #0, #00,playerSprites+1, #%00000000

    ;gun
    InitSpriteAtPos sprite_player + 8 ,#0, #0,  playerSprites+2, #%00000000
    
    ;head
    InitSpriteAtPos sprite_player + 12, #0, #0,  playerSprites+3, #%00000000


; Init anim data for player
    LDA #P_ANIM_SPRITES
    STA player_anim + anim_max_index

    LDA #NUM_HEARTS
    STA player_health

    LDA #0
    STA player_waves

    ;FlipPlayer Sprite so the guy is facing the enemies to start
    LDA #%01000000
    STA sprite_player+SPRITE_ATTR

    ;init the three hearts
    InitSpriteAtPos sprite_health,   #HEART_X,    #HEART_Y,  HeartSprite, #%00000001
    InitSpriteAtPos sprite_health+4, #HEART_X+10, #HEART_Y,  HeartSprite, #%00000001
    InitSpriteAtPos sprite_health+8, #HEART_X+20, #HEART_Y,  HeartSprite, #%00000001

;--------------------- Poo sprite data --------------------;

    InitSpriteAtPos sprite_poo, #126,#126, #$40, #%00000000

    LDA #POO_ANIM_SPRITES
    STA poo_anim + anim_max_index

;---------------- Bullet Data ------------------;

    LDA #BULLET_ANIM_SPRITES
    STA bullet_anim + anim_max_index

    LDA #BULLET_FIRE_CD
    STA player_shot_CD
;--------------------- wall Data --------------;

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

    ;init default enemy stuff
    STA sprite_enemy + SPRITE_X, x
    LDA #E_Y_SPAWN
    STA sprite_enemy + SPRITE_Y,x
    LDA #E_BASE_SPRITE 
    STA sprite_enemy + SPRITE_TILE, X
    LDA #%00000000   
    STA sprite_enemy+ SPRITE_ATTR, x

    ;A =0 so store into enemy status also
    STA enemy_info + enemyStatus,x

    ;Give the enemy 
    LDA #E_HEALTH
    STA enemy_info + enemy_health, x

    LDA #E_X_SPEED
    STA enemy_info + enemy_speed, x

    LDA #E_ANIM_SPRITES
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