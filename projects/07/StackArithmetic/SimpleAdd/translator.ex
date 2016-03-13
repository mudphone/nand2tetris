defmodule Translator do

  def file_binary(file_name) do
    case File.read(file_name) do
      {:ok, file_bin} ->
        file_bin
      {:error, reason} ->
        IO.puts "Can't read that file because: #{reason}"
    end
  end

  def is_comment_line?(line), do: String.starts_with? line, "//"
  def is_blank_line?(line), do: line == ""
  def is_boring_line?(line), do: is_comment_line?(line) || is_blank_line?(line)

  def read_lines(file_binary) do
    String.splitter(file_binary, "\n")
    |> Enum.map(&String.strip/1)
    |> Enum.filter(fn(line) -> !is_boring_line?(line) end)  
    |> Enum.map(&parse_line/1)
    |> Enum.map(&translate_command/1)
    |> List.flatten()
  end

  def is_push_command?(line), do: String.starts_with?(line, "push")
  def is_pop_command?(line), do: String.starts_with?(line, "pop")

  def parse_int(s) do
    {i,_} = Integer.parse(s)
    i
  end
  def parse_args([f, s]), do: [f, parse_int(s)]
  
  def command_args(command) do
    String.split(command, " ")
    |> Enum.drop(1)
    |> parse_args()
  end
  
  def parse_line(line) do
    # transforms line -> cmd_type, [arg1, arg2]
    cond do
      is_push_command?(line) -> [:C_PUSH, command_args(line)]
      is_pop_command?(line) ->  [:C_POP,  command_args(line)]
      true -> [:C_ARITHMETIC, [line]]
    end
  end

  def translate_command([:C_ARITHMETIC, ["add"]]) do
    ["@SP",   # get top item on stack: x
     "M=M-1",
     "A=M",
     "D=M",
     "@SP",   # get second item on stack (from top): y
     "M=M-1",
     "A=M",
     "M=D+M", # add (x+y)
     "@SP",   # increment stack pointer
     "M=M+1"]
  end
  def translate_command([:C_ARITHMETIC, [cmd]]), do: "unknown arith cmd: #{cmd}"
  def translate_command([:C_PUSH, ["constant", arg2]]) do
    ["@#{arg2}", # place constant in D register
     "D=A",
     "@SP",      # push constant 
     "A=M",
     "M=D",     
     "@SP",      # increment stack pointer
     "M=M+1"]
  end
  def translate_command([cmd, _]), do: "unknown cmd: #{cmd}"      

  def translate(file_name) do
    x = file_binary(file_name)
    |> read_lines()
    |> Enum.join("\n")

    File.write("output.asm", x)
  end

end

