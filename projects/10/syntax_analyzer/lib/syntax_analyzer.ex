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

  def tokenize_xml(path) do    
    x = translate_file(path)
    |> Tokenizer.tokenize_xml()
    |> Enum.join("\n")

    basename = jackfile_basename_no_prefix(path)
    dirname = Path.dirname(path)
    File.write("#{dirname}/KO_#{basename}T.xml", x, [:append])
  end

  def tokenize_xml_all(path) do
    find_jack_files(path)
    |> Enum.map(&tokenize_xml/1)
  end
  
  def jack_file?(path), do: ".jack" == Path.extname(path)

  def find_files(path) do
    if File.dir?(path) do
      {:ok, ls_files} = File.ls(path)
      ls_files
      |> Enum.map(fn(fname) -> "#{path}/" <> fname end)
    else
      [path]
    end
  end
  
  def find_jack_files(path), do: Enum.filter(find_files(path), &jack_file?/1)

end
