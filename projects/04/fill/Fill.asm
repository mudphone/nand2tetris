// This file is part of www.nand2tetris.org
// and the book "The Elements of Computing Systems"
// by Nisan and Schocken, MIT Press.
// File name: projects/04/Fill.asm

// Runs an infinite loop that listens to the keyboard input. 
// When a key is pressed (any key), the program blackens the screen,
// i.e. writes "black" in every pixel. When no key is pressed, the
// program clears the screen, i.e. writes "white" in every pixel.

// @POS      current screen position
// @ROW      current row
// @COL      current column
// @COLOR    current color (black or white)
// @NUMROWS  total screen rows
// @NUMCOLS  total screen columns

@256
D=A
@NUMROWS
M=D

@32
D=A
@NUMCOLS
M=D

(KBLOOP)
  @KBD   // keyboard
  D=M

  @BLACK
  D;JGT  // key pressed?
  
  (WHITE)
  @0      // zero: white
  D=A
  @COLOR  // color: white
  M=D
  @PICKEREND
  0;JMP

  (BLACK)
  @0      // zero: black
  D=A-1
  @COLOR  // color: black
  M=D
  (PICKEREND)

  (FILL)
  @SCREEN  // first screen address
  D=A
  @POS      // reset screen position
  M=D


  @0       // zero
  D=A
  @ROW     // current row
  M=D
  (FILLLOOP)
    @ROW
    D=M
    @NUMROWS
    D=D-M 
    @FILLLOOPEND
    D;JGE  // jump if row >= 256

    @0     // zero
    D=A
    @COL    // reset column
    M=D
    (ROWLOOP)
      @COL  // current column
      D=M
      @NUMCOLS
      D=D-M
      @ROWLOOPEND
      D;JGE  // jump if column >= 32

      @COLOR
      D=M
      @POS
      A=M
      M=D    // set color

      @COL    // increment column
      M=M+1

      @POS    // increment screen position
      M=M+1
      
      @ROWLOOP
      0;JMP  // increment column and loop
    (ROWLOOPEND)
    
    @ROW    // increment row
    M=M+1

    @FILLLOOP
    0;JMP
  (FILLLOOPEND)

(KBLOOPEND)

@KBLOOP
0;JMP
