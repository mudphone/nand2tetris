# UUID code copied from Ecto
defmodule UUID do
  @doc """
  Generates a version 4 (random) UUID.
  """
  def generate do
    bingenerate() |> encode
  end

  @doc """
  Generates a version 4 (random) UUID in the binary format.
  """
  def bingenerate do
    <<u0::48, _::4, u1::12, _::2, u2::62>> = :crypto.strong_rand_bytes(16)
    <<u0::48, 4::4, u1::12, 2::2, u2::62>>
  end

  defp encode(<<u0::32, u1::16, u2::16, u3::16, u4::48>>) do
    hex_pad(u0, 8) <> "-" <>
    hex_pad(u1, 4) <> "-" <>
    hex_pad(u2, 4) <> "-" <>
    hex_pad(u3, 4) <> "-" <>
    hex_pad(u4, 12)
  end

  defp hex_pad(hex, count) do
    hex = Integer.to_string(hex, 16)
    lower(hex, :binary.copy("0", count - byte_size(hex)))
  end

  defp lower(<<h, t::binary>>, acc) when h in ?A..?F,
    do: lower(t, acc <> <<h + 32>>)
  defp lower(<<h, t::binary>>, acc),
    do: lower(t, acc <> <<h>>)
  defp lower(<<>>, acc),
    do: acc
end


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
  
  def get_top_item_on_stack(), do: ["@SP","M=M-1","A=M"]
  def increment_stack_pointer(), do: ["@SP","M=M+1"]
  def set_top_of_stack_to(s), do: ["@SP","A=M","M=#{s}"]
  
  def translate_command([:C_ARITHMETIC, ["add"]]) do
    [get_top_item_on_stack(),  # get top item on stack: y
     "D=M",                    # and assign to D register
     get_top_item_on_stack(),  # get second item on stack (from top): x
     "M=D+M",                  # add (y+x)
     increment_stack_pointer() # increment stack pointer
    ]
  end
  def translate_command([:C_ARITHMETIC, ["sub"]]) do
    [get_top_item_on_stack(),  # get top item on stack: y
     "D=M",                    # and assign to D register
     get_top_item_on_stack(),  # get second item on stack (from top): x
     "M=M-D",                  # sub (x-y)
     increment_stack_pointer() # increment stack pointer
    ]
  end
  def translate_command([:C_ARITHMETIC, ["neg"]]) do
    [get_top_item_on_stack(),  # get top item on stack: y
     "M=-M",                   # neg (-y)
     increment_stack_pointer() # increment stack pointer
    ]
  end
  def translate_command([:C_ARITHMETIC, ["and"]]) do
    [get_top_item_on_stack(),  # y
     "D=M",                    # and assign to D register
     get_top_item_on_stack(),  # x
     "M=D&M",                  # y&x
     increment_stack_pointer()
    ]
  end
  def translate_command([:C_ARITHMETIC, ["or"]]) do
    [get_top_item_on_stack(),  # y
     "D=M",                    # and assign to D register
     get_top_item_on_stack(),  # x
     "M=D|M",                  # y|x
     increment_stack_pointer()
    ]
  end
  def translate_command([:C_ARITHMETIC, ["not"]]) do
    [get_top_item_on_stack(),  # y
     "M=!M",                   # !y
     increment_stack_pointer()
    ]
  end
  def translate_command([:C_ARITHMETIC, ["eq"]]) do
    true_label = "IS_TRUE_#{UUID.generate()}"
    false_label = "IS_FALSE_#{UUID.generate()}"
    end_label = "END__#{UUID.generate()}"
    [get_top_item_on_stack(), # y
     "D=M",                   # and assign to D register
     get_top_item_on_stack(), # x
     "D=D-M",                 # y - x
     "@#{true_label}",
     "D;JEQ",
     "(#{false_label})",
     set_top_of_stack_to("0"),
     "@#{end_label}",
     "0;JMP",
     "(#{true_label})",
     set_top_of_stack_to("-1"),
     "(#{end_label})",
     increment_stack_pointer()
    ]
  end
  def translate_command([:C_ARITHMETIC, ["lt"]]) do
    # x is LT y if x-y is LT 0
    true_label = "IS_TRUE_#{UUID.generate()}"
    false_label = "IS_FALSE_#{UUID.generate()}"
    end_label = "END__#{UUID.generate()}"
    [get_top_item_on_stack(), # y
     "D=M",                   # and assign to D register
     get_top_item_on_stack(), # x
     "D=M-D",                 # x - y
     "@#{true_label}",
     "D;JLT",
     "(#{false_label})",
     set_top_of_stack_to("0"),
     "@#{end_label}",
     "0;JMP",
     "(#{true_label})",
     set_top_of_stack_to("-1"),
     "(#{end_label})",
     increment_stack_pointer()
    ]
  end
  def translate_command([:C_ARITHMETIC, ["gt"]]) do
    # x is GT y if x-y is GT 0
    true_label = "IS_TRUE_#{UUID.generate()}"
    false_label = "IS_FALSE_#{UUID.generate()}"
    end_label = "END__#{UUID.generate()}"
    [get_top_item_on_stack(), # y
     "D=M",                   # and assign to D register
     get_top_item_on_stack(), # x
     "D=M-D",                 # x - y
     "@#{true_label}",
     "D;JGT",
     "(#{false_label})",
     set_top_of_stack_to("0"),
     "@#{end_label}",
     "0;JMP",
     "(#{true_label})",
     set_top_of_stack_to("-1"),
     "(#{end_label})",
     increment_stack_pointer()
    ]
  end
  def translate_command([:C_ARITHMETIC, [cmd]]), do: "unknown arith cmd: #{cmd}"
  def translate_command([:C_PUSH, ["constant", arg2]]) do
    ["@#{arg2}", # place constant in D register
     "D=A",
     set_top_of_stack_to("D"), # push constant from D register
     increment_stack_pointer() # increment stack pointer
    ]
  end
  def translate_command([cmd, _]), do: "unknown cmd: #{cmd}"      

  def translate(file_name) do
    x = file_binary(file_name)
    |> read_lines()
    |> Enum.join("\n")

    File.write("output.asm", x)
  end

end

