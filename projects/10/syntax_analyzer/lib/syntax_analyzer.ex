defmodule SyntaxAnalyzer do
  
  def file_binary(file_name) do
    case File.read(file_name) do
      {:ok, file_bin} ->
        file_bin
      {:error, reason} ->
        IO.puts "Can't read that file because: #{reason}"
    end
  end

  def jackfile_basename_no_prefix(path), do: Path.basename(path, ".jack")
  
  def translate_file(file_name) do
    file_binary(file_name)
    |> LineReader.read_lines()
  end

  def tokenize_xml(file_name) do
    x = translate_file(file_name)
    |> Tokenizer.tokenize_xml()
    |> Enum.join("\n")

    basename = jackfile_basename_no_prefix(file_name)
    File.write("KO_#{basename}T.xml", x, [:append])
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
