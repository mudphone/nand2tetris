// This file is part of www.nand2tetris.org
// and the book "The Elements of Computing Systems"
// by Nisan and Schocken, MIT Press.
// File name: projects/04/Fill.asm

// Runs an infinite loop that listens to the keyboard input. 
// When a key is pressed (any key), the program blackens the screen,
// i.e. writes "black" in every pixel. When no key is pressed, the
// program clears the screen, i.e. writes "white" in every pixel.

// @0 screen
// @1 row
// @2 column
// @3 color

(KBLOOP)
  @24576  // keyboard
  D=M

  @BLACK
  D;JGT   // key pressed?
  
  (WHITE)
  @0   // zero: white
  D=A
  @3   // color: white
  M=D
  @COLOREND
  0;JMP

  (BLACK)
  @0   // zero: black
  D=A-1
  @3   // color: black
  M=D
  (COLOREND)

  (FILL)
  @16384  // first screen address
  D=A
  @0      // reset screen position
  M=D
  @0      // zero
  D=A
  @1      // current row
  M=D
  (FILLLOOP)
    // 256 rows
    // 32 words per row
    @1
    D=M
    @256
    D=D-A 
    @FILLLOOPEND
    D;JGE  // jump if row >= 256

    @0     // zero
    D=A
    @2     // reset column
    M=D
    (ROWLOOP)
      @2   // current column
      D=M
      @32
      D=D-A
      @ROWLOOPEND
      D;JGE  // jump if column >= 32

      @3
      D=M
      @0
      A=M
      M=D    // set color

      @2     // increment column
      M=M+1

      @0     // increment screen position
      M=M+1
      
      @ROWLOOP
      0;JMP  // increment column and loop
    (ROWLOOPEND)
    
    @1     // increment row
    M=M+1

    @FILLLOOP
    0;JMP
  (FILLLOOPEND)

(KBLOOPEND)

@KBLOOP
0;JMP
