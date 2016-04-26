defmodule JackCompiler do

  def parse_parse(path) do
    {parsed, symbol_t} = SyntaxAnalyzer.parse(path)
    CodeGeneration.generate(parsed, symbol_t)

    # x = CompilationEngine.to_xml(parsed, symbol_t)
    # |> Enum.join("\n")
    
    # basename = jackfile_basename_no_prefix(path)
    # dirname = Path.dirname(path)
    # File.write("#{dirname}/KO_#{basename}.xml", x, [:append])
  end
  
end
