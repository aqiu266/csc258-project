################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Magical Drop.
#
# Student 1: Selena (Student Number: 1011874786)
# Student 2: Andrew (Student Number: 1012021848)
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
keystrokes:     .word 0            # Tracks keystrokes for row advancement

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
    # Initialise top 8 rows of the grid with random bubbles (codes 1-4)
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
    jal  draw_all

game_loop:
    # 1a. Check if key has been pressed
    lw   $t0, ADDR_KBRD
    lw   $t1, 0($t0)
    beq  $t1, 1, handle_key
    j    after_input

handle_key:
    lw   $t4, keystrokes
    addi $t4, $t4, 1
    sw   $t4, keystrokes           # increment only when a key is pressed

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
    lw   $t0, player_col
    blez $t0, after_input
    addi $t0, $t0, -1
    sw   $t0, player_col
    j    after_input
    
key_right:
    lw   $t0, player_col
    li   $t1, GRID_COLS
    addi $t1, $t1, -1
    bge  $t0, $t1, after_input
    addi $t0, $t0, 1
    sw   $t0, player_col
    j    after_input
    
key_grab:
    la   $t0, grid
    lw   $t1, player_col
    li   $t2, 13 

grab_find_loop:
    bltz $t2, after_input          # if we hit the top, nothing to grab
    mul  $t3, $t2, GRID_COLS 
    add  $t3, $t3, $t1 
    sll  $t3, $t3, 2
    add  $t3, $t0, $t3             # address of cell
    lw   $t4, 0($t3)               # load bubble code
    bgtz $t4, grab_found           # if not empty, we found the bottom bubble
    addi $t2, $t2, -1              # else, move up one row
    j    grab_find_loop

grab_found:
    lw   $t5, held_count
    bgtz $t5, grab_check_colour
    sw   $t4, held_colour

grab_check_colour:
    lw   $t5, held_colour
    bne  $t4, $t5, after_input

    li   $t6, 0
    sw   $t6, 0($t3)               # erase bubble from grid
    lw   $t5, held_count
    addi $t5, $t5, 1
    sw   $t5, held_count           # increment held count
    addi $t2, $t2, -1              # move up one row
    j    grab_find_loop            # loop to grab chain
    
key_throw:
    lw   $t0, held_count
    blez $t0, after_input  

    la   $t1, grid
    lw   $t2, player_col
    li   $t3, 0

throw_find_loop:
    li   $t5, GRID_ROWS
    bge  $t3, $t5, after_input     # if column is full, we can't throw
    mul  $t4, $t3, GRID_COLS
    add  $t4, $t4, $t2
    sll  $t4, $t4, 2
    add  $t4, $t1, $t4
    lw   $t5, 0($t4)               # load bubble
    beqz $t5, throw_drop_here      # if empty, this is where they go
    addi $t3, $t3, 1               # else move down
    j    throw_find_loop

throw_drop_here:
    lw   $t6, held_colour
    li   $t7, 13

throw_stack_loop:
    sw   $t6, 0($t4)               # put bubble in grid
    addi $t0, $t0, -1              # decrement held_count
    blez $t0, throw_done
    bge  $t3, $t7, throw_done      # if bottom reached, stop
    addi $t3, $t3, 1 
    addi $t4, $t4, 28
    j    throw_stack_loop

throw_done:
    li   $t5, 0
    sw   $t5, held_count
    sw   $t5, held_colour 
    jal  check_matches
    j    after_input
    
key_quit:
    li   $v0, 10
    syscall

after_input:
    # 2a. Row advancement: drop a new row every 10 keystrokes
    lw   $t0, keystrokes
    li   $t1, 10
    blt  $t0, $t1, skip_row_advance
    sw   $zero, keystrokes         # reset counter
    jal  advance_row

skip_row_advance:
    # 2b. Check for game over
    la   $t1, grid
    li   $t2, 0                    # col counter 0 to 6

game_over_check:
    li   $t3, GRID_COLS
    bge  $t2, $t3, draw_frame      # if we checked all cols, game is not over

    sll  $t3, $t2, 2
    add  $t3, $t1, $t3
    li   $t4, 364 
    add  $t4, $t3, $t4
    lw   $t5, 0($t4)               # load the bottom row cell
    bgtz $t5, game_over            # if not empty, game over
    
    addi $t2, $t2, 1
    j    game_over_check

game_over:
    li   $v0, 10
    syscall

draw_frame:
	# 3. Draw the screen
	jal  draw_all

	# 4. Sleep
	li   $a0, 50
	li   $v0, 32
	syscall

    # 5. Go back to Step 1
    j game_loop

##############################################################################
# Game Logic Helpers
##############################################################################

# advance_row: Pushes all rows down and generates a new top row.
advance_row:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)
    la   $t0, grid
    li   $t1, 90                   # 13 rows * 7 cols - 1 = 90 (start from row 12)
push_down_loop:
    bltz $t1, gen_top_row
    addi $t2, $t1, 7               # target index (one row down)
    sll  $t3, $t1, 2
    add  $t3, $t0, $t3
    lw   $t4, 0($t3)               # load current bubble
    sll  $t5, $t2, 2
    add  $t5, $t0, $t5
    sw   $t4, 0($t5)               # store in row below
    addi $t1, $t1, -1
    j    push_down_loop

gen_top_row:
    li   $t1, 0
gen_col_loop:
    li   $t2, GRID_COLS
    bge  $t1, $t2, advance_done
    li   $v0, 42
    li   $a0, 0
    li   $a1, 4
    syscall
    addi $a0, $a0, 1
    sll  $t3, $t1, 2
    add  $t3, $t0, $t3
    sw   $a0, 0($t3)               # store new random bubble
    addi $t1, $t1, 1
    j    gen_col_loop

advance_done:
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

# check_matches: Scans the grid for vertical 3+ matches and clears them.
check_matches:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)
    la   $t0, grid
    li   $t1, 0                    # row counter (0 to 13)

cm_row_loop:
    li   $t2, 0                    # col counter (0 to 6)

cm_col_loop:
    li   $t3, 12
    bge  $t1, $t3, cm_next_col

    mul  $t3, $t1, GRID_COLS
    add  $t3, $t3, $t2
    sll  $t3, $t3, 2
    add  $t3, $t0, $t3
    lw   $t4, 0($t3)
    beqz $t4, cm_next_col

    addi $t3, $t3, 28              # next row
    lw   $t5, 0($t3)
    bne  $t4, $t5, cm_next_col

    addi $t3, $t3, 28              # next row
    lw   $t6, 0($t3)
    bne  $t4, $t6, cm_next_col

    # Match of at least 3 found. Clear the run.
    li   $t7, 0
    addi $t3, $t3, -56             # go back to start
    sw   $t7, 0($t3)
    addi $t3, $t3, 28
    sw   $t7, 0($t3)
    
cm_clear_loop:
    addi $t3, $t3, 28
    lw   $t5, 0($t3)
    bne  $t5, $t4, cm_next_col     # stop if the chain breaks
    sw   $t7, 0($t3)               # erase extra bubble
    j    cm_clear_loop

cm_next_col:
    addi $t2, $t2, 1
    blt  $t2, GRID_COLS, cm_col_loop
    addi $t1, $t1, 1
    blt  $t1, GRID_ROWS, cm_row_loop

    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

##############################################################################
# Drawing Functions
##############################################################################

# draw_all: Redraws all dynamic elements (character, grid, held bubbles).
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
draw_walls:
    lw   $t0, ADDR_DSPL
    lw   $t1, COLOUR_WALL
    li   $t2, WALL_TOP
    
lw_loop:
    sll  $t3, $t2, 7
    addi $t3, $t3, 4   
    add  $t4, $t0, $t3
    sw   $t1, 0($t4)
    addi $t2, $t2, 1
    li   $t5, 18                   # stop after bottom wall row (17)
    blt  $t2, $t5, lw_loop
    
    li   $t2, WALL_TOP
rw_loop:
    sll  $t3, $t2, 7
    addi $t3, $t3, 36
    add  $t4, $t0, $t3
    sw   $t1, 0($t4)
    addi $t2, $t2, 1
    li   $t5, 18                   # stop after bottom wall row (17)
    blt  $t2, $t5, rw_loop
    
    li   $t2, WALL_LEFT
top_loop:
    li   $t3, 128   
    sll  $t4, $t2, 2
    add  $t3, $t3, $t4
    add  $t4, $t0, $t3
    sw   $t1, 0($t4)
    addi $t2, $t2, 1
    li   $t5, 10                   # stop after right wall col (9)
    blt  $t2, $t5, top_loop
    
    li   $t2, WALL_LEFT
bot_loop:
    li   $t3, 2176
    sll  $t4, $t2, 2
    add  $t3, $t3, $t4
    add  $t4, $t0, $t3
    sw   $t1, 0($t4)
    addi $t2, $t2, 1
    li   $t5, 10                   # stop after right wall col (9)
    blt  $t2, $t5, bot_loop
    jr   $ra

# clear_dynamic: Erases the character row and the held bubble area.
clear_dynamic:
    lw   $t0, ADDR_DSPL
    lw   $t1, COLOUR_BG
    li   $t2, CHAR_ROW
    sll  $t2, $t2, 7
    li   $t3, SCREEN_OFFSET_X
    
cd_char_loop:
    sll  $t4, $t3, 2
    add  $t4, $t2, $t4
    add  $t4, $t0, $t4
    sw   $t1, 0($t4)
    addi $t3, $t3, 1
    li   $t5, 9                    # stop before right wall (9)
    blt  $t3, $t5, cd_char_loop
    
    li   $t7, SCREEN_OFFSET_X
    
cd_col_loop:
    li   $t2, HELD_ROW           
    
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
    li   $t5, 9                    # stop before right wall (9)
    blt  $t7, $t5, cd_col_loop
    jr   $ra

# draw_grid: Iterates through the 14x7 grid array and draws each bubble.
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

colour_lookup:
    li   $v0, 0                    # code 0 returns black
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