SignFlip .macro 
    EOR #%11111111
    CLC 
    ADC #1
    .endm
;|1:Pallette Array|
LoadPalette .macro
    LDA \1
    STA PPUDATA
    LDA \1+1
    STA PPUDATA
    LDA \1+2
    STA PPUDATA
    LDA \1+3
    STA PPUDATA
    .endm

;| 1: variable | 2: value
AddValueInLoop .macro
    LDA \1,x
    CLC
    ADC \2
    STA \1,x
    .endm

;|1: variable | 2: value
AddValue .macro
    LDA \1
    CLC
    ADC \2
    STA \1
    .endm

; 1: variable |2: value 
SubtractValue .macro
    LDA \1
    SEC
    SBC \2
    STA \1
    .endm
;1: Movement Var | 2: sprite |3: pixelOffset| 4: sub_Offset
SubPixelAddX .macro
    AddValue \1 + sub_pos_x, #\4
    LDA \2 + SPRITE_X
    ADC #\3
    STA \2 + SPRITE_X
    .endm

;1: Movement Var | 2: sprite |3: pixelOffset| 4: sub_Offset
SubPixelMinusX .macro
    SubtractValue \1 + sub_pos_x, #\4
    LDA \2 + SPRITE_X
    SBC #\3
    STA \2 + SPRITE_X
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

;| 1: movement| 2: sprite | 3: body |4 anim | 5: enemy info | 6: Enemy Head
;This macros is basically the states for the enemies behaviour
OutOfLoopEnemyUpdate .macro
    ;Get the health of the enemy coming in, check to see if its positive
    LDA \5 + enemy_health
    BEQ Dead\@

    ;If its here we know its alive, so check how alive it is
    JMP CheckForHead\@

Dead\@:
    ;Apply physics to the body of the zombie, using the original enemies legs
    ApplyPhysics \1, \3 
    
    ;Hide the rest of th enemy
    LDA #248
    STA \2 + SPRITE_Y
    STA \3+4 + SPRITE_Y

    ;If its dead we also know the head will be off so do some physics on it
    JMP TryDoHeadPhyscis\@

CheckForHead\@:
    ;DO jump and Phyiscs and animate enemy
    Jump \1, \2
    ApplyPhysics \1,\2
    AnimateSprite \3 + 4, enemyArm, \4

    ;Check to see if the enemy has max health if not then off with its head
    LDA \5 + enemy_health
    CMP #2
    BCC NoHead\@

    ;If we are here then the zombie has a head :(
    UpdateSpritesToRoot \2,#3, \3,  humanSpriteXOffsets, humanSpriteYOffsets
    JMP EndUpdate\@
NoHead\@:
    ;render one less
    UpdateSpritesToRoot \2,#2, \3,  humanSpriteXOffsets, humanSpriteYOffsets
    LDA #1
    STA \4 +anim_status
TryDoHeadPhyscis\@:

    ;compare the head height to the floor, if its less than the floor height dont do physics
    ;as we know the heads wont do anything after they drop to floor and will spend more time on the
    ;floor than in the air so this should save some CPU cycles
    LDA \3 + 8 +SPRITE_Y
    CMP #FLOORHEIGHT+1
    BCC DoHeadPhysics\@
    JMP EndUpdate\@
DoHeadPhysics\@:
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

    ;Subtract one if frames left is still sub_positive
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

    ;reset to default animation tile
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

    ;Load in the root sprites Y and apply the offset to the current offset sprite
    LDA \1 + SPRITE_Y
    CLC
    ADC \5, y
    STA \3 + SPRITE_Y,x

    ;Make sure their attr are the same, for both flip and for palette 
    LDA \1 + SPRITE_ATTR
    STA \3 + SPRITE_ATTR, x

    ;Check to see which direction the sprite is facing
    AND #%01000000
    BNE LeftFacing\@

    ;Apply the X offsets for a right facing root sprite
    LDA \1+SPRITE_X
    CLC
    ADC \4, y
    STA \3 + SPRITE_X,x
    JMP FinishedXMove\@

LeftFacing\@:
    ;Apply the X offsets for a left facing root sprite
    LDA \1+SPRITE_X
    SEC
    SBC \4, y
    STA \3 + SPRITE_X,x

FinishedXMove\@:
    ;Decrement to get the next offset
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
    Add16Bit \1 + speed_y, GRAVITY
    AddValue \1 + sub_pos, \1 + speed_y

    ; Apply the new speed DONT CLEAR CARRY
    LDA \2 + SPRITE_Y
    ADC \1 + speed_y + 1
    STA \2 + SPRITE_Y

    ;CHeck to see if its not greater than floorHeight
    CMP #FLOORHEIGHT
    BCS OnGround\@

    ;Check physics object against barrier to see if we're colliding
    LDX #0
    CheckSpriteCollisionWithXReg \2, #8,#0, sprite_barrier, #B_WIDTH,#B_HEIGHT, #0,#0
    LDA collision_flag
    BEQ Onbarrier\@


    JMP ReturnFromApplyPhysics\@

Onbarrier\@:
    ;Reset speeds to 0
    LDA #0
    STA \1 +speed_y
    STA \1 +speed_y+1
    STA \1 + sub_pos

    ;Get the Top of the sprite barrier and set \2 sprite Y to it
    LDA sprite_barrier + SPRITE_Y
    SEC
    SBC #B_HEIGHT
    STA \2 + SPRITE_Y
    JMP ReturnFromApplyPhysics\@

OnGround\@:
    ;If the object is on the ground
    LDA #0
    STA \1 +speed_y
    STA \1 +speed_y+1
    STA \1 + sub_pos


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
    LDA \2 + SPRITE_Y
    SEC 
    SBC #2
    STA \2 + SPRITE_Y

    LDA #LOW(JUMP_FORCE)
    STA \1 + speed_y
    LDA #HIGH(JUMP_FORCE)
    STA \1 + speed_y +1

NoJump\@:
    .endm

;| sprite variable | x | y | tileID | Attr| 
InitSpriteAtPos  .macro
        ; Write sprite data for 0 OAM memory Object memory
    LDA  \3       ; Y sub_pos
    STA  \1 + SPRITE_Y

    LDA  \4       ; Tile number
    STA  \1 + SPRITE_TILE

    LDA \5         ; Attributes ????
    STA \1 + SPRITE_ATTR

    LDA \2    ; X sub_pos
    STA \1 + SPRITE_X
    .endm

;|1:sprite Tiles|2: sprite array | 3: Far Left | 4: Top 
InitFourLetterSprite .macro
    InitSpriteAtPos \2,    #\3,   #\4,   \1,   #0 
    InitSpriteAtPos \2+4,  #\3+8, #\4,   \1+1, #0 
    InitSpriteAtPos \2+8,  #\3,   #\4+8, \1+2, #0 
    InitSpriteAtPos \2+12, #\3+8, #\4+8, \1+3, #0 
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
    ;Initialise collision as if We have collided 
    LDA #%00000000
    STA collision_flag

    ; branch if x1 - (w2 + dx)  >= x2 
    LDA \1 + SPRITE_X, x      
    SEC
    SBC #\5 + #\7   
    CMP \4 + SPRITE_X   
    BCS NoCollision\@ 

    ;Branch if (x1 - (w2 + dx)) + w1 + w2 + dx < x2
    CLC 
    ADC #\2 + #\5  + #\7    
    CMP \4 + SPRITE_X       
    BCC NoCollision\@ 
    
    ;Branch if y1 + h2 + dy < y2
    LDA \1 + SPRITE_Y, x 
    CLC
    ADC #\6 +#\8                    
    CMP \4+SPRITE_Y        
    BCC NoCollision\@ 

    ;Branch if (y1 + h2+ dy) - (h1 + h2 + dy) < y2 (if branch here it means there is a hit)
    SEC 
    SBC #\3+#\6  + #\8           
    CMP \4+SPRITE_Y 
    BCC EndCollision\@ ; 

NoCollision\@
    LDA #%00000001
    STA collision_flag
EndCollision\@
    .endm