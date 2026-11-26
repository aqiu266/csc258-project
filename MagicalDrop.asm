################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Magical Drop.
#
# Student 1: Selena (Student Number: 1011874786)
# Student 2: Andrew (Student Number: )
#
# We assert that the code submitted here is entirely our own 
# creation, and will indicate otherwise when it is not.
#
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       16
# - Unit height in pixels:      16
# - Display width in pixels:    512
# - Display height in pixels:   512
# - Base Address for Display:   0x10008000 ($gp)
##############################################################################

    .data
##############################################################################
# Immutable Data
##############################################################################
# The address of the bitmap display. Don't forget to connect it!
ADDR_DSPL:
    .word 0x10008000
# The address of the keyboard. Don't forget to connect it!
ADDR_KBRD:
    .word 0xffff0000

# Colours (one word per unit)
COLOUR_BG:      .word 0x00000000
COLOUR_WALL:    .word 0x00808080
COLOUR_RED:     .word 0x00FF0000
COLOUR_YELLOW:  .word 0x00FFFF00
COLOUR_GREEN:   .word 0x0000FF00
COLOUR_BLUE:    .word 0x000000FF
COLOUR_PLAYER:  .word 0x00FFFFFF

##############################################################################
# Mutable Data
##############################################################################
# Shared state
player_col:     .word 3
held_count:     .word 0
held_colour:    .word 0

# Grid: 14 rows x 7 cols, row-major. 0 = empty, 1..4 = colour code.
grid:
    .space 392        

.eqv GRID_COLS 7
.eqv GRID_ROWS 14
.eqv UNIT_BYTES 4

##############################################################################
# Code
##############################################################################
	.text
	.globl main

    # Run the game.
main:
    # TODO (Andrew): initialise the grid with starting rows of bubbles.

    # Draw the static frame once at start-up.
    jal  draw_background
    jal  draw_walls

game_loop:
    # 1a. Check if key has been pressed
    lw   $t0, ADDR_KBRD
    lw   $t1, 0($t0)
    beq  $t1, 1, handle_key
    j    after_input

handle_key:
    # 1b. Check which key has been pressed
    lw   $t2, 4($t0)   
    li   $t3, 0x61
    beq  $t2, $t3, key_left
    li   $t3, 0x64
    beq  $t2, $t3, key_right
    li   $t3, 0x73
    beq  $t2, $t3, key_grab
    li   $t3, 0x77
    beq  $t2, $t3, key_throw
    li   $t3, 0x71
    beq  $t2, $t3, key_quit
    j    after_input

key_left:
    # TODO (Andrew): bounds check + decrement player_col
    j    after_input
key_right:
    # TODO (Andrew): bounds check + increment player_col
    j    after_input
key_grab:
    # TODO (Andrew): grab chain from column above player
    j    after_input
key_throw:
    # TODO (Andrew): throw held bubbles + check matches
    j    after_input
key_quit:
    li   $v0, 10
    syscall

after_input:
	# 2a. Check for collisions
	# 2b. Grab/throw/match
	# TODO (Andrew): row advancement, gravity, match resolution.

	# 3. Draw the screen
	jal  draw_all

	# 4. Sleep
	li   $a0, 50
	li   $v0, 32
	syscall

    # 5. Go back to Step 1
    j game_loop


##############################################################################
# (everything after here is done)
##############################################################################

draw_all:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    jal  clear_dynamic
    jal  draw_grid
    jal  draw_player
    jal  draw_held

    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

draw_background:
    lw   $t0, ADDR_DSPL
    lw   $t1, COLOUR_BG
    li   $t2, 1024
    move $t3, $t0
    
bg_loop:
    sw   $t1, 0($t3)
    addi $t3, $t3, UNIT_BYTES
    addi $t2, $t2, -1
    bgtz $t2, bg_loop
    jr   $ra

draw_walls:
    lw   $t0, ADDR_DSPL
    lw   $t1, COLOUR_WALL
    li   $t2, 1
    
lw_loop:
    sll  $t3, $t2, 7
    addi $t3, $t3, 4
    add  $t4, $t0, $t3
    sw   $t1, 0($t4)
    addi $t2, $t2, 1
    li   $t5, 18
    blt  $t2, $t5, lw_loop
    li   $t2, 1
    
rw_loop:
    sll  $t3, $t2, 7
    addi $t3, $t3, 36
    add  $t4, $t0, $t3
    sw   $t1, 0($t4)
    addi $t2, $t2, 1
    li   $t5, 18
    blt  $t2, $t5, rw_loop
    li   $t2, 1
    
top_loop:
    li   $t3, 128
    sll  $t4, $t2, 2
    add  $t3, $t3, $t4
    add  $t4, $t0, $t3
    sw   $t1, 0($t4)
    addi $t2, $t2, 1
    li   $t5, 10
    blt  $t2, $t5, top_loop
    li   $t2, 1

bot_loop:
    li   $t3, 2176
    sll  $t4, $t2, 2
    add  $t3, $t3, $t4
    add  $t4, $t0, $t3
    sw   $t1, 0($t4)
    addi $t2, $t2, 1
    li   $t5, 10
    blt  $t2, $t5, bot_loop

    jr   $ra

clear_dynamic:
    lw   $t0, ADDR_DSPL
    lw   $t1, COLOUR_BG
    li   $t2, 16
    sll  $t2, $t2, 7
    li   $t3, 2
    
cd_char_loop:
    sll  $t4, $t3, 2
    add  $t4, $t2, $t4
    add  $t4, $t0, $t4
    sw   $t1, 0($t4)
    addi $t3, $t3, 1
    li   $t5, 9
    blt  $t3, $t5, cd_char_loop
    li   $t7, 2
    
cd_col_loop:
    li   $t2, 18      
    
cd_row_loop:
    sll  $t4, $t2, 7
    sll  $t6, $t7, 2
    add  $t4, $t4, $t6
    add  $t4, $t0, $t4
    sw   $t1, 0($t4)
    addi $t2, $t2, 1
    li   $t5, 32
    blt  $t2, $t5, cd_row_loop
    addi $t7, $t7, 1
    li   $t5, 9
    blt  $t7, $t5, cd_col_loop
    jr   $ra

draw_grid:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)
    la   $t0, grid
    li   $t1, 0

dg_row_loop:
    li   $t2, 0
    
dg_col_loop:
    mul  $t3, $t1, GRID_COLS
    add  $t3, $t3, $t2
    sll  $t3, $t3, 2
    add  $t3, $t0, $t3
    lw   $t4, 0($t3)

    jal  colour_lookup 
    move $t5, $v0

    addi $t6, $t1, 2
    addi $t7, $t2, 2
    sll  $t8, $t6, 7
    sll  $t9, $t7, 2
    add  $t8, $t8, $t9
    lw   $t9, ADDR_DSPL
    add  $t8, $t9, $t8
    sw   $t5, 0($t8)

    addi $t2, $t2, 1
    blt  $t2, GRID_COLS, dg_col_loop
    addi $t1, $t1, 1
    blt  $t1, GRID_ROWS, dg_row_loop

    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

draw_player:
    lw   $t0, ADDR_DSPL
    lw   $t1, COLOUR_PLAYER
    lw   $t2, player_col
    addi $t2, $t2, 2
    li   $t3, 16
    sll  $t4, $t3, 7
    sll  $t5, $t2, 2
    add  $t4, $t4, $t5
    add  $t4, $t0, $t4
    sw   $t1, 0($t4)
    jr   $ra

draw_held:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    lw   $t0, held_count
    blez $t0, dh_done

    jal  colour_lookup_from_held
    move $t2, $v0

    lw   $t3, ADDR_DSPL
    lw   $t4, player_col
    addi $t4, $t4, 2
    li   $t5, 18

dh_loop:
    sll  $t6, $t5, 7
    sll  $t7, $t4, 2
    add  $t6, $t6, $t7
    add  $t6, $t3, $t6
    sw   $t2, 0($t6)
    addi $t5, $t5, 1
    addi $t0, $t0, -1
    bgtz $t0, dh_loop

dh_done:
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

colour_lookup:
    li   $v0, 0
    li   $t5, 1
    beq  $t4, $t5, cl_red
    li   $t5, 2
    beq  $t4, $t5, cl_yellow
    li   $t5, 3
    beq  $t4, $t5, cl_green
    li   $t5, 4
    beq  $t4, $t5, cl_blue
    jr   $ra

cl_red:
    lw   $v0, COLOUR_RED
    jr   $ra
cl_yellow:
    lw   $v0, COLOUR_YELLOW
    jr   $ra
cl_green:
    lw   $v0, COLOUR_GREEN
    jr   $ra
cl_blue:
    lw   $v0, COLOUR_BLUE
    jr   $ra

colour_lookup_from_held:
    lw   $t4, held_colour
    j    colour_lookup

##############################################################################