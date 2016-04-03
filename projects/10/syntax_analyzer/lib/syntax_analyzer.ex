defmodule SyntaxAnalyzer do

  def file_binary(file_name) do
    case File.read(file_name) do
      {:ok, file_bin} ->
        file_bin
      {:error, reason} ->
        IO.puts "Can't read that file because: #{reason}"
    end
  end

  def comment_line?(line), do: String.starts_with? line, "//"
  def blank_line?(line),   do: line == ""
  def boring_line?(line),  do: comment_line?(line) || blank_line?(line)

  def strip_trailing_comments(line) do
    String.split(line, "//", parts: 2)
    |> List.first
  end
  
  def read_lines(file_binary, file_base) do
    String.splitter(file_binary, "\n")
    |> Enum.map(&strip_trailing_comments/1)
    |> Enum.map(&String.strip/1)
    |> Enum.filter(fn(line) -> !boring_line?(line) end)  
  end

  def jackfile_basename_no_prefix(path), do: Path.basename(path, ".jack")
  
  def translate_file(file_name) do
    file_binary(file_name)
    |> read_lines(jackfile_basename_no_prefix(file_name))
  end

  # def translate(path) do
  #   x = find_vm_files(path)
  #   |> Enum.map(&translate_file/1)
  #   |> bootstrap()
  #   |> List.flatten
  #   |> Enum.join("\n")
    
  #   basename_no_prefix = vmfile_basename_no_prefix(path)
  #   File.write("#{basename_no_prefix}.asm", x, [:append])
  # end

  # def jack_file?(path), do: ".jack" == Path.extname(path)

  # def find_files(path) do
  #   cond do
  #     File.dir?(path) ->
  #       {:ok, ls_files} = File.ls(path)
  #       ls_files
  #       |> Enum.map(fn(fname) -> "#{path}/" <> fname end)
  #     true ->
  #       [path]
  #   end
  # end
  
  # def find_vm_files(path), do: Enum.filter(find_files(path), &jack_file?/1)

end
