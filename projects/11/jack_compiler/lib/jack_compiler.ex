defmodule JackCompiler do

  def compile_jack_to_vm(path) do
    {vm_code, []} = SyntaxAnalyzer.parse(path)
    |> CodeGeneration.compile()

    x = Enum.join(vm_code, "\n")
    
    basename = SyntaxAnalyzer.jackfile_basename_no_prefix(path)
    dirname = Path.dirname(path)
    File.write("#{dirname}/#{basename}.vm", x, [:append])
  end

  def compile(path) do
    find_jack_files(path)
    |> Enum.map(&compile_jack_to_vm/1)
  end

  def jack_file?(path), do: ".jack" == Path.extname(path)

  def find_files(path) do
    cond do
      File.dir?(path) ->
        {:ok, ls_files} = File.ls(path)
        ls_files
        |> Enum.map(fn(fname) -> "#{path}/" <> fname end)
      true ->
        [path]
    end
  end
  
  def find_jack_files(path), do: Enum.filter(find_files(path), &jack_file?/1)

end
