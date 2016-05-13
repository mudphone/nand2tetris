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
    compile_class(%{class: class_name, fields: 0}, rest)
  end

  def compile_class(%{class: class_name, fields: field_count},
        [{:classVarDec, inner} | rest]) do
    {vm_code, fields} = compile_class_var(inner)
    vm_code ++ compile_class(%{class: class_name, fields: field_count + fields}, rest)
  end
  
  def compile_class(env,
        [{:subroutineDec, inner} | rest]) do
    compile_subroutine_dec(env, inner)
    ++ compile_class(env, rest)
  end

  def compile_class(_env, [{:symbol, "}"}]), do: []

  def compile_class_var([{:keyword, static_or_field},
                         {:keyword, _type},
                         {:identifier, _var_name, :attr, _} | rest]) do
    {vm_code, n} = compile_class_var(rest)
    {vm_code, if(static_or_field == "field", do: n+1, else: 0)}
  end

  def compile_class_var([{:keyword, static_or_field},
                         {:identifier, _type, :attr, _},
                         {:identifier, _var_name, :attr, _} | rest]) do
    {vm_code, n} = compile_class_var(rest)
    {vm_code, if(static_or_field == "field", do: n+1, else: 0)}
  end

  def compile_class_var([{:symbol, ","},
                         {:identifier, _var_name, :attr, _} | rest]) do
    {vm_code, n} = compile_class_var(rest)
    {vm_code, n+1}
  end

  def compile_class_var([{:symbol, ";"}]), do: {[], 0}

  def compile_subroutine_dec(%{class: class_name, fields: field_count},
        [{:keyword, "constructor"},
         {:identifier, _class, :attr, _},
         {:identifier, "new", :attr, _},
         {:symbol, "("},
         {:parameterList, _param_list},
         {:symbol, ")"},
         {:subroutineBody, body_parsed}]) do
    ["function #{class_name}.new #{number_of_locals(body_parsed)}",
     "push constant #{field_count}",
     "call Memory.alloc 1",
     "pop pointer 0"]
    ++ compile_subroutine_body(class_name, body_parsed)
  end

  def compile_subroutine_dec(%{class: class_name},
        [{:keyword, "method"},
         {:keyword, _return_type},
         {:identifier, fn_name, :attr, _},
         {:symbol, "("},
         {:parameterList, _param_list},
         {:symbol, ")"},
         {:subroutineBody, body_parsed}]) do
    ["function #{class_name}.#{fn_name} #{number_of_locals(body_parsed)}",
     "push argument 0",
     "pop pointer 0"]
    ++ compile_subroutine_body(class_name, body_parsed)
  end

  def compile_subroutine_dec(%{class: class_name},
        [{:keyword, "function"},
         {:identifier, _return_type, :attr, _},
         {:identifier, fn_name, :attr, _},
         {:symbol, "("},
         {:parameterList, _param_list},
         {:symbol, ")"},
         {:subroutineBody, body_parsed}]) do
    compile_subroutine_dec_for_function(class_name, fn_name, body_parsed)
  end

  def compile_subroutine_dec(%{class: class_name},
        [{:keyword, "function"},
         {:keyword, _return_type},
         {:identifier, fn_name, :attr, _},
         {:symbol, "("},
         {:parameterList, _param_list},
         {:symbol, ")"},
         {:subroutineBody, body_parsed}]) do
    compile_subroutine_dec_for_function(class_name, fn_name, body_parsed)
  end

  def compile_subroutine_dec_for_function(class_name, fn_name, body_parsed) do
    ["function #{class_name}.#{fn_name} #{number_of_locals(body_parsed)}"]
    ++ compile_subroutine_body(class_name, body_parsed)    
  end
  
  def compile_subroutine_body(class_name, [{:symbol, "{"} | rest]) do
    {locals, rest1} = compile_var_dec(rest)
    {statements, rest2} = compile_statements(class_name, rest1)
    [{:symbol, "}"}] = rest2
    locals ++ statements
  end

  def compile_var_dec([{:varDec, _} | rest]), do: compile_var_dec(rest)

  def compile_var_dec(all), do: {[], all}

  def compile_statements(class_name, [{:statements, statements_parsed} | rest]) do
    {compile_statement(class_name, statements_parsed), rest}
  end
  
  def compile_statement(class_name, [{:doStatement, do_parsed} | rest]) do
    compile_do_statement(class_name, do_parsed)
    ++ compile_statement(class_name, rest)
  end

  def compile_statement(class_name, [{:letStatement, let_parsed} | rest]) do
    compile_let_statement(let_parsed)
    ++ compile_statement(class_name, rest)
  end

  def compile_statement(class_name, [{:whileStatement, while_parsed} | rest]) do
    compile_while_statement(class_name, while_parsed)
    ++ compile_statement(class_name, rest)
  end

  def compile_statement(class_name, [{:ifStatement, if_parsed} | rest]) do
    compile_if_statement(class_name, if_parsed)
    ++ compile_statement(class_name, rest)
  end

  def compile_statement(class_name, [{:returnStatement, return_parsed} | rest]) do
    compile_return_statement(return_parsed)
    ++ compile_statement(class_name, rest)
  end

  def compile_statement(_class_name, []), do: []

  def compile_return_statement([{:keyword, "return"},
                                {:symbol, ";"}]) do
    ["push constant 0",
     "return"]
  end

  def compile_return_statement([{:keyword, "return"},
                                {:expression, exp_parsed},
                                {:symbol, ";"}]) do
    compile_exp(exp_parsed)
    ++ ["return"]
  end  

  def segment_of(:static), do: "static"
  def segment_of(:field),  do: "this"
  def segment_of(:arg),    do: "argument"
  def segment_of(:var),    do: "local"

  def compile_let_statement([{:keyword, "let"},
                             {:identifier, _var_name, :attr, %{kind: kind, index: index, type: "Array"}},
                             {:symbol, "["},
                             {:expression, exp_parsed},
                             {:symbol, "]"},
                             {:symbol, "="},
                             {:expression, rh_exp_parsed},
                             {:symbol, ";"}]) do
    compile_exp(exp_parsed)
    ++ ["push #{segment_of(kind)} #{index}",
        "add",
        "pop pointer 1"]
    ++ compile_exp(rh_exp_parsed)
    ++ ["pop that 0"]
  end
  
  def compile_let_statement([{:keyword, "let"},
                             {:identifier, _var_name, :attr, %{kind: kind, index: index}},
                             {:symbol, "="},
                             {:expression, exp_parsed},
                             {:symbol, ";"}]) do 
    compile_exp(exp_parsed)
    ++ ["pop #{segment_of(kind)} #{index}"]
  end

  def compile_do_statement(_class_name,
        [{:keyword, "do"},
         {:identifier, class_name, :attr, %{category: :class}},
         {:symbol, "."},
         {:identifier, fn_name, :attr, _},
         {:symbol, "("},
         {:expressionList, exp_list_parsed},
         {:symbol, ")"},
         {:symbol, ";"}]) do
    compile_exp_list(exp_list_parsed)
    ++ ["call #{class_name}.#{fn_name} #{number_of_expressions(exp_list_parsed)}"]
  end
    
  def compile_do_statement(_class_name,
        [{:keyword, "do"},
         {:identifier, _var_name, :attr, %{type: type, category: category, kind: kind, index: index}},
         {:symbol, "."},
         {:identifier, fn_name, :attr, _},
         {:symbol, "("},
         {:expressionList, exp_list_parsed},
         {:symbol, ")"},
         {:symbol, ";"}])
  when category in [:field, :var] do
    ["push #{segment_of(kind)} #{index}"]
    ++ compile_exp_list(exp_list_parsed)
    ++ ["call #{type}.#{fn_name} #{number_of_expressions(exp_list_parsed) + 1}"]
  end

  def compile_do_statement(class_name,
        [{:keyword, "do"},
         {:identifier, fn_name, :attr, _},
         {:symbol, "("},
         {:expressionList, exp_list_parsed},
         {:symbol, ")"},
         {:symbol, ";"}]) do
    ["push pointer 0"]
    ++ compile_exp_list(exp_list_parsed)
    ++ ["call #{class_name}.#{fn_name} #{number_of_expressions(exp_list_parsed) + 1}"]
  end

  def compile_while_statement(class_name,
        [{:keyword, "while"},
         {:symbol, "("},
         {:expression, exp_parsed},
         {:symbol, ")"},
         {:symbol, "{"} | rest]) do
    label1 = "whileL1$#{JackUuid.generate()}"
    label2 = "whileL2$#{JackUuid.generate()}"
    exp = compile_exp(exp_parsed)
    {statements, rest1} = compile_statements(class_name, rest)
    [{:symbol, "}"}] = rest1
    ["label #{label1}"]
    ++ exp
    ++ ["not",
        "if-goto #{label2}"]
    ++ statements
    ++ ["goto #{label1}",
        "label #{label2}"]
  end

  def compile_if_statement(class_name,
        [{:keyword, "if"},
         {:symbol, "("},
         {:expression, exp_parsed},
         {:symbol, ")"},
         {:symbol, "{"},
         {:statements, statements_parsed},
         {:symbol, "}"}]) do
    label1 = "ifL1$#{JackUuid.generate()}"
    exp = compile_exp(exp_parsed)
    statements = compile_statement(class_name, statements_parsed)
    exp
    ++ ["not",
        "if-goto #{label1}"]
    ++ statements
    ++ ["label #{label1}"]
  end

  def compile_if_statement(class_name,
        [{:keyword, "if"},
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
    statements = compile_statement(class_name, statements_parsed)
    else_statements = compile_statement(class_name, else_parsed)
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

  def compile_term([{:keyword, "this"}]), do: ["push pointer 0"]
  def compile_term([{:keyword, "true"}]), do: ["push constant 1", "neg"]
  def compile_term([{:keyword, "false"}]), do: ["push constant 0"]

  def compile_term([{:identifier, _var_name,
                     :attr, %{kind: kind, index: index, type: "Array"}},
                    {:symbol, "["},
                    {:expression, exp_parsed},
                    {:symbol, "]"}]) do
    compile_exp(exp_parsed)
    ++ ["push #{segment_of(kind)} #{index}",
        "add",
        "pop pointer 1",
        "push that 0"]
  end
  
  def compile_term([{:identifier, _var_name, :attr, %{kind: kind, index: index}}]) do
    ["push #{segment_of(kind)} #{index}"]
  end
  
  def compile_term([{:symbol, "-"},{:term, term}]) do
    compile_term(term) ++ ["neg"]
  end

  def compile_term([{:symbol, "~"},{:term, term}]) do
    compile_term(term) ++ ["not"]
  end

  def compile_term([{:stringConstant, str}]) when is_bitstring(str) do
    ["push constant #{String.length(str)}",
     "call String.new 1"]
    ++ compile_str(str)
  end
  
  def compile_term([{:integerConstant, i}]) do
    ["push constant #{i}"]
  end

  def compile_term([{:symbol, "("},
                    {:expression, exp_parsed},
                    {:symbol, ")"}]) do
    compile_exp(exp_parsed)
  end

  def compile_term([{:identifier, class_name, :attr, %{category: :class}},
                    {:symbol, "."},
                    {:identifier, fn_name, :attr, %{category: :subroutine}},
                    {:symbol, "("},
                    {:expressionList, exp_list_parsed},
                    {:symbol, ")"}]) do
    compile_exp_list(exp_list_parsed)
    ++ ["call #{class_name}.#{fn_name} #{number_of_expressions(exp_list_parsed)}"]
  end

  def compile_term([{:identifier, _var_name,
                     :attr, %{type: class_name, kind: kind, index: index}},
                    {:symbol, "."},
                    {:identifier, fn_name, :attr, %{category: :subroutine}},
                    {:symbol, "("},
                    {:expressionList, exp_list_parsed},
                    {:symbol, ")"}]) do
    ["push #{segment_of(kind)} #{index}"]
    ++ compile_exp_list(exp_list_parsed)
    ++ ["call #{class_name}.#{fn_name} #{number_of_expressions(exp_list_parsed) + 1}"]
  end

  
  def compile_term([]), do: []
  
  def compile_str(<<h>> <> rest) do
    ["push constant #{h}",
     "call String.appendChar 2"]
    ++ compile_str(rest)
  end

  def compile_str(""), do: []
  
  def number_of_expressions(exp_list) do
    Enum.filter(exp_list, fn (tup) ->
      List.keymember?([tup], :expression, 0)
    end) |> length()
  end

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
