defmodule CodeGeneration do

  # input parsed instructions and the completed symbol table
  
  def compile([{:class, inner}
               | rest], symbol_table) do
    class_code = compile_class(inner, symbol_table)
    {code, rest1} = compile(rest, symbol_table)
    {class_code ++ code, rest1}
  end

  def compile(_all, _symbol_table), do: {[], []}

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

  def compile_class(_class_name,
        [{:symbol, "}"}], _symbol_table) do
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

  def compile_statements([{:returnStatement, return_parsed} | rest], symbol_table) do
    compile_return_statement(return_parsed, symbol_table)
    ++ compile_statements(rest, symbol_table)
  end

  def compile_statements([], _symbol_table), do: []

  def compile_return_statement([{:keyword, "return"},
                               {:symbol, ";"}], _symbol_table) do
    ["return"]
  end

  def compile_do_statement([{:keyword, "do"},
                            {:identifier, class_name, :attr, _},
                            {:symbol, "."},
                            {:identifier, fn_name, :attr, _},
                            {:symbol, "("},
                            {:expressionList, exp_list_parsed},
                            {:symbol, ")"},
                            {:symbol, ";"}], _symbol_table) do
    compile_exp_list(exp_list_parsed)
    ++ ["call #{class_name}.#{fn_name} #{number_of_expressions(exp_list_parsed)}"]
  end

  def compile_exp_list([{:expression, exp_parsed} | more]) do
    compile_exp(exp_parsed) ++ compile_exp_list(more)
  end

  def compile_exp_list([]), do: []

  def compile_exp([{:term, term} | more]) do
    compile_term(term) ++ compile_exp(more)
  end

  def compile_exp([{:symbol, "*"},
                   {:term, term} | more]) do
    compile_term(term) ++ ["call Math.multiply 2"] ++ compile_exp(more)
  end

  def compile_exp([{:symbol, "+"},
                    {:term, term} | more]) do
    compile_term(term) ++ ["add"] ++ compile_exp(more)
  end

  def compile_exp([]), do: []
  
  def compile_term([{:integerConstant, i}]) do
    ["push constant #{i}"]
  end

  def compile_term([{:symbol, "("},
                    {:expression, exp_parsed},
                    {:symbol, ")"}]) do
    compile_exp(exp_parsed)
  end

  def compile_term([]), do: []
  
  def number_of_expressions(exp_list) do
    Enum.filter(exp_list, fn (tup) ->
      List.keymember?([tup], :expression, 0)
    end) |> length()
  end
  
  def number_of_parameters(param_list) do
    Enum.filter(param_list, fn (tup) ->
      List.keymember?([tup], :identifier, 0)
    end) |> length()
  end
                                         
end
