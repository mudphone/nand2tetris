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
    ["function #{class_name}.#{fn_name} #{number_of_locals(param_list)}"]
    ++ body_vm
  end

  def compile_subroutine_body([{:symbol, "{"} | rest], symbol_table) do
    {locals, rest1} = compile_var_dec(rest)
    {statements, rest2, _t} = compile_statements(rest1, symbol_table)
    [{:symbol, "}"}] = rest2
    locals ++ statements ++ [{:symbol, "}"}]
  end

  def compile_var_dec([{:varDec, _} | rest]), do: compile_var_dec(rest)

  def compile_var_dec(all), do: {[], all}

  def compile_statements([{:statements, statements_parsed} | rest], symbol_table) do
    {compile_statement(statements_parsed, symbol_table), rest, symbol_table}
  end
  
  def compile_statement([{:doStatement, do_parsed} | rest], symbol_table) do
    compile_do_statement(do_parsed, symbol_table)
    ++ compile_statement(rest, symbol_table)
  end

  def compile_statement([{:letStatement, let_parsed} | rest], symbol_table) do
    compile_let_statement(let_parsed, symbol_table)
    ++ compile_statement(rest, symbol_table)
  end

  def compile_statement([{:returnStatement, return_parsed} | rest], symbol_table) do
    compile_return_statement(return_parsed, symbol_table)
    ++ compile_statement(rest, symbol_table)
  end

  def compile_statement([], _symbol_table), do: []

  def compile_return_statement([{:keyword, "return"},
                               {:symbol, ";"}], _symbol_table) do
    ["return"]
  end

  def segment_of(:static), do: "static"
  def segment_of(:field),  do: "this"
  def segment_of(:arg),    do: "argument"
  def segment_of(:var),    do: "local"
  
  def compile_let_statement([{:keyword, "let"},
                             {:identifier, var_name, :attr, %{kind: kind, index: index}},
                             {:symbol, "="},
                             {:expression, exp_parsed},
                             {:symbol, ";"}], symbol_table) do
    
    compile_exp(exp_parsed)
    ++ ["pop #{segment_of(kind)} #{index}"]
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

  def compile_exp_list([{:symbol, ","} | more]), do: compile_exp_list(more)

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

  def compile_exp([{:symbol, "-"},
                   {:term, term} | more]) do
    compile_term(term) ++ ["sub"] ++ compile_exp(more)
  end

  def compile_exp([]), do: []

  def compile_term([{:keyword, "true"}]), do: ["push constant -1"]
  def compile_term([{:keyword, "false"}]), do: ["push constant 0"]
  
  def compile_term([{:identifier, var_name, :attr, %{kind: kind, index: index}}]) do
    ["push #{segment_of(kind)} #{index}"]
  end
  
  def compile_term([{:symbol, "-"},
                    {:term, term}]) do
    compile_term(term) ++ ["call Math.multiply -1"]
  end
  
  def compile_term([{:integerConstant, i}]) do
    ["push constant #{i}"]
  end

  def compile_term([{:symbol, "("},
                    {:expression, exp_parsed},
                    {:symbol, ")"}]) do
    compile_exp(exp_parsed)
  end

  def compile_term([{:identifier, class_name, :attr, _},
                    {:symbol, "."},
                    {:identifier, fn_name, :attr, %{category: :subroutine}},
                    {:symbol, "("},
                    {:expressionList, exp_list_parsed},
                    {:symbol, ")"}]) do
    compile_exp_list(exp_list_parsed)
    ++
    ["call #{class_name}.#{fn_name} #{number_of_expressions(exp_list_parsed)}"]
  end

  def compile_term([]), do: []
  
  def number_of_expressions(exp_list) do
    Enum.filter(exp_list, fn (tup) ->
      List.keymember?([tup], :expression, 0)
    end) |> length()
  end
  
  # def number_of_parameters(param_list) do
  #   Enum.filter(param_list, fn (tup) ->
  #     List.keymember?([tup], :identifier, 0)
  #   end) |> length()
  # end

  def number_of_locals(subroutine_body) do
    Enum.filter(subroutine_body, fn(tup) ->
      List.keymember?([tup], :varDec, 0)
    end)
    |> Enum.flat_map(fn ({:varDec, v}) ->
      Enum.filter(v, fn(tup) ->
        List.keymember?([tup], :identifier, 0)
      end)
    end)
    |> length()
  end
  
end
