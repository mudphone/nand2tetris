defmodule CodeGeneration do

  # input parsed instructions and the completed symbol table
  
  def compile([{:class, inner}
               | rest], symbol_table) do
    class_code = compile_class(inner, symbol_table)
    {code, rest1} = compile(rest, symbol_table)
    {class_code ++ code, rest1}
  end

  def compile(all, symbol_table), do: {[], []}

  def compile_class([{:keyword, "class"},
                     {:identifier, class_name, :attr, _},
                     {:symbol, "{"}
                     | rest], symbol_table) do
    compile_class(class_name, rest, symbol_table)
  end

  def compile_class(class_name,
        [{:subroutineDec, inner} | rest], symbol_table) do
    compile_subroutine_dec(class_name, inner, symbol_table)
    ++ compile_class(class_name, rest, symbol_table)
  end

  def compile_class(class_name,
        [{:symbol, "}"}], symbol_table) do
    []
  end

  def compile_subroutine_dec(class_name,
        [{:keyword, "function"},
         {:keyword, "void"},
         {:identifier, fn_name, :attr, _},
         {:symbol, "("},
         {:parameterList, param_list},
         {:symbol, ")"},
         {:subroutineBody, body_parsed}], symbol_table) do
    body_vm = compile_subroutine_body(body_parsed, symbol_table)
    ["function #{class_name}.#{fn_name} #{number_of_parameters(param_list)}"]
    ++ body_vm
  end

  def compile_subroutine_body([{:symbol, "{"},
                               {:statements, statements_parsed},
                               {:symbol, "}"}], symbol_table) do
    compile_statements(statements_parsed, symbol_table)
  end

  def compile_statements([{:doStatement, do_parsed} | rest], symbol_table) do
    compile_do_statement(do_parsed, symbol_table)
    ++ compile_statements(rest, symbol_table)
  end

  def compile_statements([{:returnStatement, return_parsed}], symbol_table) do
    ["return statement"]
  end

  def compile_statements([], _symbol_table), do: []

  def compile_do_statement([{:keyword, "do"},
                            {:identifier, class_name, :attr, _},
                            {:symbol, "."},
                            {:identifier, fn_name, :attr, _},
                            {:symbol, "("},
                            {:expressionList, exp_parsed},
                            {:symbol, ")"},
                            {:symbol, ";"}], symbol_table) do
    ["do statement"]
  end
  
  def number_of_parameters(param_list) do
    Enum.filter(param_list, fn (tup) ->
      List.keymember?([tup], :identifier, 0)
    end) |> length()
  end
                                         
end
