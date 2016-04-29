defmodule JackCompiler do

  def compile_jack_to_vm(path) do
    {parsed, symbol_t} = SyntaxAnalyzer.parse(path)
    {vm_code, []} = CodeGeneration.compile(parsed, symbol_t)

    x = Enum.join(vm_code, "\n")
    # x = CompilationEngine.to_xml(parsed, symbol_t)
    # |> Enum.join("\n")
    
    basename = SyntaxAnalyzer.jackfile_basename_no_prefix(path)
    dirname = Path.dirname(path)
    File.write("#{dirname}/KO_#{basename}.vm", x, [:append])
  end
  
end
