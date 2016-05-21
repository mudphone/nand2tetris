# What is this?
I've used [LFE](http://lfe.io) and [Elixir](http://lfe.io) (and other tools) to follow the Nand2Tetris course, which guides "self-learners through the construction of a modern, full-scale computer system - hardware and software - from the ground up. In the process, the students practice many major computer science (CS) abstractions studied in typical CS courses and make them concrete through 12 guided implementation projects."

## The Parts
                +----------+               +------------+                         +-----------+
Jack Program ---| Compiler |--> VM Code ---| Translator |--> Assembly Language ---| Assembler |--> Machine Code
                +----------+               +------------+                         +-----------+

                +---------------------------------------------------------------------------+
                | Compiler                                                                  |
                |                                                                           |
                |   +----------------------------------------------+                        |
                |   | Syntax Analyzer                              |                        |
                |   |                                              |                        |
                |   |   +-----------+   +----------------------+   |   +----------------+   |
Jack Program ---|---|-->| Tokenizer |-->| Parser               |---|-->| Code Generator |---|---> VM Code
                |   |   +-----------+   | (Compilation Engine) |   |   +----------------+   |
                |   |                   +----------------------+   |                        |
                |   +----------------------------------------------+                        |
                |                                                                           |
                +---------------------------------------------------------------------------+

* [The assembler in LFE](https://github.com/mudphone/nand2tetris/blob/master/projects/06/assembler.lfe)
* [The VM code translator in Elixir](https://github.com/mudphone/nand2tetris/blob/master/projects/08/translator.ex)
* [The tokenizer in Elixir](https://github.com/mudphone/nand2tetris/blob/master/projects/11/jack_compiler/lib/tokenizer.ex)
* [The parser in Elixir](https://github.com/mudphone/nand2tetris/blob/master/projects/11/jack_compiler/lib/compilation_engine.ex)
* [The VM code generator in Elixir](https://github.com/mudphone/nand2tetris/blob/master/projects/11/jack_compiler/lib/code_generation.ex)
* [The compiler (wraps the tokenizer, parser, and generator) in Elixir](https://github.com/mudphone/nand2tetris/blob/master/projects/11/jack_compiler/lib/jack_compiler.ex)
* [The syntax analyzer (wraps the tokenizer and parser) in Elixir](https://github.com/mudphone/nand2tetris/blob/master/projects/11/jack_compiler/lib/syntax_analyzer.ex)

## The Overview Video
[From Nand to Tetris In 12 Steps](https://www.youtube.com/watch?v=JtXvUoPx4Qs) [~9 minutes]

## Based on:
[The Elements of Computing Systems: Building a Modern Computer from First Principles, Nand to Tetris Companion](http://nand2tetris.org/), by Noam Nisan and Shimon Schocken