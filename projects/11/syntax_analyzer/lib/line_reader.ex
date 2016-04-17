defmodule LineReader do

  def comment_line?(line), do: String.starts_with? line, "//"
  def blank_line?(line),   do: line == ""
  def boring_line?(line),  do: comment_line?(line) || blank_line?(line)

  def strip_trailing_comments(line) do
    String.split(line, "//", parts: 2)
    |> List.first
  end
  
  def read_lines(file_binary) do
    String.splitter(file_binary, "\n")
    |> Enum.map(&strip_trailing_comments/1)
    |> Enum.map(&String.strip/1)
    |> Enum.filter(fn(line) -> !boring_line?(line) end)  
  end

end
