// This file is part of www.nand2tetris.org
// and the book "The Elements of Computing Systems"
// by Nisan and Schocken, MIT Press.
// File name: projects/04/Fill.asm

// Runs an infinite loop that listens to the keyboard input. 
// When a key is pressed (any key), the program blackens the screen,
// i.e. writes "black" in every pixel. When no key is pressed, the
// program clears the screen, i.e. writes "white" in every pixel.

// @0 : R0 screen position
// @1 : R1 row
// @2 : R2 column
// @3 : R3 color

@256
D=A
@ROWS
M=D

@32
D=A
@COLS
M=D

(KBLOOP)
  @KBD  // keyboard
  D=M

  @BLACK
  D;JGT   // key pressed?
  
  (WHITE)
  @0   // zero: white
  D=A
  @R3   // color: white
  M=D
  @COLOREND
  0;JMP

  (BLACK)
  @0   // zero: black
  D=A-1
  @R3  // color: black
  M=D
  (COLOREND)

  (FILL)
  @SCREEN  // first screen address
  D=A
  @R0      // reset screen position
  M=D


  @0       // zero
  D=A
  @R1      // current row
  M=D
  (FILLLOOP)
    @R1
    D=M
    @ROWS
    D=D-M 
    @FILLLOOPEND
    D;JGE  // jump if row >= 256

    @0     // zero
    D=A
    @R2    // reset column
    M=D
    (ROWLOOP)
      @R2  // current column
      D=M
      @COLS
      D=D-M
      @ROWLOOPEND
      D;JGE  // jump if column >= 32

      @R3
      D=M
      @R0
      A=M
      M=D    // set color

      @R2    // increment column
      M=M+1

      @R0    // increment screen position
      M=M+1
      
      @ROWLOOP
      0;JMP  // increment column and loop
    (ROWLOOPEND)
    
    @R1    // increment row
    M=M+1

    @FILLLOOP
    0;JMP
  (FILLLOOPEND)

(KBLOOPEND)

@KBLOOP
0;JMP
