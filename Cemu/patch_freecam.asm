[BotWFreecam]
moduleMatches = 0x6267bfd0

; enables Nintendo's freecam in Breath of the Wild
; Controls:
; hold R to increase camera speed
; hold L to decrease camera speed
; ZR to move camera up
; ZL to move camera down
; right stick to control field of view
; left stick to control horizontal camera position
; left stick button to toggle free camera

0x10369f48 = .float 2.5                 ; set cam rotation speed
0x0308e5a0 = malloc:                    ; define the function to allocate DebugInfo
0x03ac0e44 = rlwinm. r8,r0,0,26,26      ; zoom in with L rather than (+)
0x03ae6034 = nop                        ; nop null pointer check on heap

.origin = 0x03ae6054
nop
nop
addi r25, r3, 0x374
nop
li r5, 4
mr r4, r31
li r3, 0x418
bl malloc                               ; resolve call to allocate DebugInfo strings

0x03a1197c = bl set_freecam_params      ; hook gsys:SystemTask::prepare()
0x03ae630c = bl set_flags               ; hook agl::lyr::Layer::calc_()
0x03ae660c = bl cameraCode
0x03ac0538 = bl storeCamSpeed
0x03abffd0 = bl switchSticks
0x030d89f8 = b disableGamepadControls

controllerPtr = 0x10A06250              ; &buttonsHeld - 0x10c (find through memory search)
LINK_CAM = 0x1047c390

.origin = 0x102e6394                    ; store global variables in .rodata over an unused string
freecamEnabled:                         ; stores whether the camera is enabled
.int 0
speed:                                  ; copy of camera speed
.float 0

.origin = 0x0358dd7c                    ; insert hooks below into unused debug function

set_freecam_params:
lis r11, controllerPtr@h
ori r11, r11, controllerPtr@l
li r7, 1
stw r7,0x370(r25)                       ; enable dynamic camera focus (rather than static; make this toggleable)
li r7, 1
stw r7,0x36c(r25)                       ; enable debug camera
blr

set_flags:                              ; r28 currently contains the same address as r25 above
mr r29,r3                               ; original instruction
lis r6,freecamEnabled@ha
lwz r9,freecamEnabled@l(r6)
lwz r7,0x374(r28)                       ; load controller into r7
lwz r3,0x110(r7)
rlwinm. r3,r3,0,14,14
beq setEnabledStatus
xori r9,r9,1                            ; if right stick button pressed this frame, enable freecam and setup camera
lwz r5,0x19c(r29)
addi r5, r5, 0x5c                       ; r5 contains LookAtCamera pointer
lis r4,LINK_CAM@ha
lwz r4,LINK_CAM@l(r4)
lwz r4,0x2c(r4)                         ; r4 contains Link camera pointer
lfs f1, 0x24(r4)                        ; copy camera position vector to our camera
lfs f2, 0x28(r4)
lfs f3, 0x2c(r4)
stfs f1, 0x34(r5)
stfs f2, 0x38(r5)
stfs f3, 0x3c(r5)
lfs f1, 0x30(r4)                        ; copy camera attention vector to our camera
lfs f2, 0x34(r4)
lfs f3, 0x38(r4)
stfs f1, 0x40(r5)
stfs f2, 0x44(r5)
stfs f3, 0x48(r5)
setEnabledStatus:
stw r9,freecamEnabled@l(r6)
cmpwi r9,0x1
lwz r9,0x50(r29)
bne disableFreecam
ori r9,r9,0xc9                          ; bitwise OR with mask 0b11001001
b storeBits
disableFreecam:
rlwinm r9,r9,0,0,30
rlwinm r9,r9,0,29,27
rlwinm r9,r9,0,26,23
storeBits:
stw r9,0x50(r29)
blr

cameraCode:
li r4, 0
stw r4, -0x4(r1)
lis r4, 0x3f80
stw r4, -0x8(r1)
lfs f1, -0x4(r1)
lfs f2, -0x8(r1)
stfs f1, 0x4c(r3)                       ; store the vector (0,1,0) as camera orientation
stfs f2, 0x50(r3)
stfs f1, 0x54(r3)
lis r4,speed@ha
lfs f2,speed@l(r4)                      ; load cam speed into f2
lwz r4,0x10c(r30)                       ; load currently pressed button
rlwinm. r5,r4,0,25,25                   ; check if ZR is pressed
bne apply_changes
rlwinm. r5,r4,0,24,24                   ; check if ZL is pressed
beqlr
fneg f2, f2
apply_changes:                          ; add/subtract units to/from y component of cameraPos and cameraAtt
lfs f1,0x38(r3)
fadds f1,f2,f1
stfs f1,0x38(r3)
lfs f1,0x44(r3)
fadds f1,f2,f1
stfs f1,0x44(r3)
blr

storeCamSpeed:
lwz r12,0x1a0(r1)                       ; load speed value into r12
lis r6, speed@ha
stw r12, speed@l(r6)
blr

switchSticks:                           ; swap the left and right stick functions to mimic native controls
cmpwi r8, 0                             ; original instruction
mr r8, r5
mr r5, r4
mr r4, r8
blr

0x030d8bc4 = nop                        ; disable right stick trigger
disableGamepadControls:
lis r4,freecamEnabled@ha
lwz r4,freecamEnabled@l(r4)
cmpwi r4,1
beqlr                                   ; if free camera is enabled, skip control detection
stwu r1,-0x50(r1)                       ; original instruction
b 0x030d89fc
