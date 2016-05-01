defmodule CodeGeneration do

  # input parsed instructions and the completed symbol table
  
  def compile([{:class, inner} | rest]) do
    class_code = compile_class(inner)
    {code, rest1} = compile(rest)
    {class_code ++ code, rest1}
  end

  def compile(_all), do: {[], []}

  def compile_class([{:keyword, "class"},
                     {:identifier, class_name, :attr, _},
                     {:symbol, "{"}
                     | rest]) do
    compile_class(class_name, rest)
  end

  def compile_class(class_name,
        [{:subroutineDec, inner} | rest]) do
    compile_subroutine_dec(class_name, inner)
    ++ compile_class(class_name, rest)
  end

  def compile_class(_class_name, [{:symbol, "}"}]) do
    []
  end

  def compile_subroutine_dec(class_name,
        [{:keyword, "function"},
         {:keyword, "void"},
         {:identifier, fn_name, :attr, _},
         {:symbol, "("},
         {:parameterList, param_list},
         {:symbol, ")"},
         {:subroutineBody, body_parsed}]) do
    body_vm = compile_subroutine_body(body_parsed)
    ["function #{class_name}.#{fn_name} #{number_of_locals(param_list)}"]
    ++ body_vm
  end

  def compile_subroutine_body([{:symbol, "{"} | rest]) do
    {locals, rest1} = compile_var_dec(rest)
    {statements, rest2} = compile_statements(rest1)
    [{:symbol, "}"}] = rest2
    locals ++ statements ++ [{:symbol, "}"}]
  end

  def compile_var_dec([{:varDec, _} | rest]), do: compile_var_dec(rest)

  def compile_var_dec(all), do: {[], all}

  def compile_statements([{:statements, statements_parsed} | rest]) do
    {compile_statement(statements_parsed), rest}
  end
  
  def compile_statement([{:doStatement, do_parsed} | rest]) do
    compile_do_statement(do_parsed)
    ++ compile_statement(rest)
  end

  def compile_statement([{:letStatement, let_parsed} | rest]) do
    compile_let_statement(let_parsed)
    ++ compile_statement(rest)
  end

  def compile_statement([{:whileStatement, while_parsed} | rest]) do
    compile_while_statement(while_parsed)
    ++ compile_statement(rest)
  end

  def compile_statement([{:ifStatement, if_parsed} | rest]) do
    compile_if_statement(if_parsed)
    ++ compile_statement(rest)
  end

  def compile_statement([{:returnStatement, return_parsed} | rest]) do
    compile_return_statement(return_parsed)
    ++ compile_statement(rest)
  end

  def compile_statement([]), do: []

  def compile_return_statement([{:keyword, "return"},
                                {:symbol, ";"}]) do
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
                             {:symbol, ";"}]) do
    
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
                            {:symbol, ";"}]) do
    compile_exp_list(exp_list_parsed)
    ++ ["call #{class_name}.#{fn_name} #{number_of_expressions(exp_list_parsed)}"]
  end

  def compile_while_statement([{:keyword, "while"},
                               {:symbol, "("},
                               {:expression, exp_parsed},
                               {:symbol, ")"},
                               {:symbol, "{"} | rest]) do
    label1 = "whileL1$#{JackUuid.generate()}"
    label2 = "whileL2$#{JackUuid.generate()}"
    exp = compile_exp(exp_parsed)
    {statements, rest1} = compile_statements(rest)
    [{:symbol, "}"}] = rest1
    ["label #{label1}"]
    ++ exp
    ++ ["not",
        "if-goto #{label2}"]
    ++ statements
    ++ ["goto #{label1}",
        "label #{label2}"]
  end

  def compile_if_statement([{:keyword, "if"},
                            {:symbol, "("},
                            {:expression, exp_parsed},
                            {:symbol, ")"},
                            {:symbol, "{"},
                            {:statements, statements_parsed},
                            {:symbol, "}"},
                            {:keyword, "else"},
                            {:symbol, "{"},
                            {:statements, else_parsed},
                            {:symbol, "}"}]) do
    label1 = "ifL1$#{JackUuid.generate()}"
    label2 = "ifL2$#{JackUuid.generate()}"
    exp = compile_exp(exp_parsed)
    statements = compile_statement(statements_parsed)
    else_statements = compile_statement(else_parsed)
    exp
    ++ ["not",
        "if-goto #{label1}"]
    ++ statements
    ++ ["goto #{label2}",
        "label #{label1}"]
    ++ else_statements
    ++ ["label #{label2}"]
  end
  
  def compile_exp_list([{:expression, exp_parsed} | more]) do
    compile_exp(exp_parsed) ++ compile_exp_list(more)
  end

  def compile_exp_list([{:symbol, ","} | more]), do: compile_exp_list(more)

  def compile_exp_list([]), do: []

  def compile_exp([{:term, term} | more]) do
    compile_term(term) ++ compile_exp(more)
  end

  def compile_exp([{:symbol, "+"},
                   {:term, term} | more]) do
    compile_term(term) ++ ["add"] ++ compile_exp(more)
  end

  def compile_exp([{:symbol, "-"},
                   {:term, term} | more]) do
    compile_term(term) ++ ["sub"] ++ compile_exp(more)
  end

  def compile_exp([{:symbol, "*"},
                   {:term, term} | more]) do
    compile_term(term) ++ ["call Math.multiply 2"] ++ compile_exp(more)
  end

  def compile_exp([{:symbol, "/"},
                   {:term, term} | more]) do
    compile_term(term) ++ ["call Math.divide 2"] ++ compile_exp(more)
  end

  def compile_exp([{:symbol, "&"},
                   {:term, term} | more]) do
    compile_term(term) ++ ["and"] ++ compile_exp(more)
  end

  def compile_exp([{:symbol, "|"},
                   {:term, term} | more]) do
    compile_term(term) ++ ["or"] ++ compile_exp(more)
  end

  def compile_exp([{:symbol, "<"},
                   {:term, term} | more]) do
    compile_term(term) ++ ["lt"] ++ compile_exp(more)
  end

  def compile_exp([{:symbol, ">"},
                   {:term, term} | more]) do
    compile_term(term) ++ ["gt"] ++ compile_exp(more)
  end

  def compile_exp([{:symbol, "="},
                   {:term, term} | more]) do
    compile_term(term) ++ ["eq"] ++ compile_exp(more)
  end

  def compile_exp([]), do: []

  def compile_term([{:keyword, "true"}]), do: ["push constant -1"]
  def compile_term([{:keyword, "false"}]), do: ["push constant 0"]
  
  def compile_term([{:identifier, var_name, :attr, %{kind: kind, index: index}}]) do
    ["push #{segment_of(kind)} #{index}"]
  end
  
  def compile_term([{:symbol, "-"},{:term, term}]) do
    compile_term(term) ++ ["neg"]
  end

  def compile_term([{:symbol, "~"},{:term, term}]) do
    compile_term(term) ++ ["not"]
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
