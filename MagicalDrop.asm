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
.eqv ROW_BYTES  128            # 32 units * 4 bytes per unit
.eqv CHAR_ROW   16             # Character row
.eqv HELD_ROW   18             # Starting row for held bubbles
.eqv WALL_LEFT  1              # Left wall column
.eqv WALL_RIGHT 9              # Right wall column
.eqv WALL_TOP   1              # Top wall row
.eqv WALL_BOT   17             # Bottom wall row
.eqv SCREEN_OFFSET_X 2         # Grid col 0 is at screen col 2
.eqv SCREEN_OFFSET_Y 2         # Grid row 0 is at screen row 2

##############################################################################
# Code
##############################################################################
	.text
	.globl main

    # Run the game.
main:
    # Initialise bottom 4 rows of the grid with random bubbles (codes 1-4)
    la   $t0, grid
    li   $t1, 0    
init_loop:
    li   $t2, 56
    bge  $t1, $t2, init_done

    li   $v0, 42
    li   $a0, 0
    li   $a1, 4
    syscall
    addi $a0, $a0, 1

    sll  $t3, $t1, 2
    add  $t3, $t0, $t3
    sw   $a0, 0($t3)

    addi $t1, $t1, 1
    j    init_loop

init_done:
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
# Drawing Functions
##############################################################################

# draw_all: Redraws all dynamic elements (character, grid, held bubbles).
# Reads: player_col, held_count, held_colour, grid
# Note: Overwrites temporary registers ($t0-$t9). 
#       Save any important values to memory before calling this.
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

# draw_background: Fills the entire screen with the background colour.
# Note: Overwrites $t0-$t3.
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

# draw_walls: Draws the grey playfield border (top, bottom, left, right).
# Note: Overwrites $t0-$t5.
draw_walls:
    lw   $t0, ADDR_DSPL
    lw   $t1, COLOUR_WALL
    li   $t2, WALL_TOP
    # left wall: $t2 = current row, $t3 = byte offset
    
lw_loop:
    sll  $t3, $t2, 7               # row * ROW_BYTES
    addi $t3, $t3, 4               # left wall col (1) * 4
    add  $t4, $t0, $t3
    sw   $t1, 0($t4)
    addi $t2, $t2, 1
    li   $t5, 18                   # stop after bottom wall row (17)
    blt  $t2, $t5, lw_loop
    li   $t2, WALL_TOP
    # Right wall: $t2 = current row, $t3 = byte offset
    
rw_loop:
    sll  $t3, $t2, 7               # row * ROW_BYTES
    addi $t3, $t3, 36              # right wall col (9) * 4
    add  $t4, $t0, $t3
    sw   $t1, 0($t4)
    addi $t2, $t2, 1
    li   $t5, 18                   # stop after bottom wall row (17)
    blt  $t2, $t5, rw_loop
    li   $t2, WALL_LEFT
    # Top wall: $t2 = current col, $t3 = byte offset
    
top_loop:
    li   $t3, 128                  # top wall row (1) * 128
    sll  $t4, $t2, 2               # col * 4
    add  $t3, $t3, $t4
    add  $t4, $t0, $t3
    sw   $t1, 0($t4)
    addi $t2, $t2, 1
    li   $t5, 10                   # stop after right wall col (9)
    blt  $t2, $t5, top_loop
    li   $t2, WALL_LEFT
    # Bottom wall: $t2 = current col, $t3 = byte offset

bot_loop:
    li   $t3, 2176                 # bottom wall row (17) * 128
    sll  $t4, $t2, 2               # col * 4
    add  $t3, $t3, $t4
    add  $t4, $t0, $t3
    sw   $t1, 0($t4)
    addi $t2, $t2, 1
    li   $t5, 10                   # stop after right wall col (9)
    blt  $t2, $t5, bot_loop
    jr   $ra

# clear_dynamic: Erases the character row and the held bubble area to 
# prevent trails when the character moves.
# Note: Overwrites $t0-$t7.
clear_dynamic:
    lw   $t0, ADDR_DSPL
    lw   $t1, COLOUR_BG
    li   $t2, CHAR_ROW
    sll  $t2, $t2, 7               # row * ROW_BYTES
    li   $t3, SCREEN_OFFSET_X
    # Character row: $t3 = current col
    
cd_char_loop:
    sll  $t4, $t3, 2               # col * 4
    add  $t4, $t2, $t4
    add  $t4, $t0, $t4
    sw   $t1, 0($t4)
    addi $t3, $t3, 1
    li   $t5, 9                    # stop before right wall (9)
    blt  $t3, $t5, cd_char_loop
    li   $t7, SCREEN_OFFSET_X
    # Held region: $t7 = current column, $t2 = current row
    
cd_col_loop:
    li   $t2, HELD_ROW           
    
cd_row_loop:
    sll  $t4, $t2, 7               # row * ROW_BYTES
    sll  $t6, $t7, 2               # col * 4
    add  $t4, $t4, $t6
    add  $t4, $t0, $t4
    sw   $t1, 0($t4)
    addi $t2, $t2, 1
    li   $t5, 32                   # last screen row + 1
    blt  $t2, $t5, cd_row_loop
    addi $t7, $t7, 1
    li   $t5, 9                    # stop before right wall (9)
    blt  $t7, $t5, cd_col_loop
    jr   $ra

# draw_grid: Iterates through the 14x7 grid array and draws each bubble.
# Calls colour_lookup.
# Note: Overwrites $t0-$t9.
draw_grid:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)
    la   $t0, grid
    li   $t1, 0
    # $t1 = grid row, $t2 = grid col
    
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

    addi $t6, $t1, SCREEN_OFFSET_Y
    addi $t7, $t2, SCREEN_OFFSET_X
    sll  $t8, $t6, 7               # screen_row * ROW_BYTES
    sll  $t9, $t7, 2               # screen_col * 4
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

# draw_player: Draws the white character square at its current column.
# Reads: player_col
# Note: Overwrites $t0-$t5.
draw_player:
    lw   $t0, ADDR_DSPL
    lw   $t1, COLOUR_PLAYER
    lw   $t2, player_col
    addi $t2, $t2, SCREEN_OFFSET_X
    li   $t3, CHAR_ROW
    sll  $t4, $t3, 7               # screen_row * ROW_BYTES
    sll  $t5, $t2, 2               # screen_col * 4
    add  $t4, $t4, $t5
    add  $t4, $t0, $t4
    sw   $t1, 0($t4)
    jr   $ra

# draw_held: Draws the held bubbles below the character.
# Reads: held_count, held_colour, player_col
# Calls colour_lookup_from_held.
# Note: Overwrites $t0-$t7.
draw_held:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    lw   $t0, held_count
    blez $t0, dh_done

    jal  colour_lookup_from_held
    move $t2, $v0

    lw   $t3, ADDR_DSPL
    lw   $t4, player_col
    addi $t4, $t4, SCREEN_OFFSET_X
    li   $t5, HELD_ROW

    # $t5 = current screen row to draw

dh_loop:
    sll  $t6, $t5, 7               # screen_row * ROW_BYTES
    sll  $t7, $t4, 2               # screen_col * 4
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

# colour_lookup: Maps a bubble code (0-4) to its display colour.
# Code 0 returns black, so empty grid cells are erased automatically.
# INPUT: $t4 (bubble code)
# OUTPUT: $v0 (colour word)
# Note: Overwrites $v0 and $t5.
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

# colour_lookup_from_held: Fetches held_colour and passes it to colour_lookup.
# Note: Overwrites $t4, $v0, $t5.
colour_lookup_from_held:
    lw   $t4, held_colour
    j    colour_lookup

##############################################################################