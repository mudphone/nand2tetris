defmodule JackCompiler do

  def compile_jack_to_vm(path) do
    {vm_code, []} = SyntaxAnalyzer.parse(path)
    |> CodeGeneration.compile()

    x = Enum.join(vm_code, "\n")
    
    basename = SyntaxAnalyzer.jackfile_basename_no_prefix(path)
    dirname = Path.dirname(path)
    File.write("#{dirname}/#{basename}.vm", x, [:append])
  end
  
end
