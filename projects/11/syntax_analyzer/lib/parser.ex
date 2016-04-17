defmodule Parser do

  @jack_statements ["let", "if", "while", "do", "return"]
  @expression_closing_symbols ["}", "]", ";", ")"]
  @expression_keyword_constants ["true", "false", "this", "null"]
  @expression_operators ["+", "-", "*", "/", "&", "|", "<", ">", "="]
  @expression_unary_operators ["-", "~"]
  
  def parse([{:keyword, "class"},
             {:identifier, class_name},
             {:symbol, "{"}
             | rest]) do
    {class_var_decs, rest1} = parse_class_vars(rest)
    {subroutines, rest2} = parse_subroutines(rest1)
    {[{:class,
       [{:keyword, "class"},
        {:identifier, class_name},
        {:symbol, "{"}]
       ++ class_var_decs
       ++ subroutines
       ++
       [{:symbol, "}"}]}], rest2}
  end

  def parse([{_, x} | rest]), do: {[{:other, x}], rest}

  def parse([]), do: {[], []}

  def parse_class_vars([{:keyword, static_or_field},
                        {keyword_or_identifier, type},
                        {:identifier, var_name}
                        | rest])
  when static_or_field in ["static", "field"] do
    {more, rest1} = parse_class_vars_end(rest)
    {next, rest2} = parse_class_vars(rest1)
    {[{:classVarDec,
       [{:keyword, static_or_field},
        {keyword_or_identifier, type},
        {:identifier, var_name}]
       ++ more}] ++ next, rest2}
  end

  def parse_class_vars(all), do: {[], all}

  def parse_class_vars_end([{:symbol, ","},
                            {:identifier, var_name}
                            | rest]) do
    {var, rest1} = parse_class_vars_end(rest)
    {[{:symbol, ","},
      {:identifier, var_name}]
     ++ var, rest1}
  end

  def parse_class_vars_end([{:symbol, ";"} | rest]) do
    {[{:symbol, ";"}], rest}
  end
  
  def parse_subroutines([{:keyword, cfm},
             {keyword_or_identifier, vort},
             {:identifier, subroutine_name}
             | rest])
  when cfm in ["constructor", "function", "method"] do
    {parameter_list, rest1} = parse_parameter_list(rest)
    {subroutine_body, rest2} = parse_subroutine_body(rest1)
    {more, rest3} = parse_subroutines(rest2)
    {[{:subroutineDec,
       [{:keyword, cfm},
        {keyword_or_identifier, vort},
        {:identifier, subroutine_name}]
       ++ parameter_list
       ++ subroutine_body}] ++ more, rest3}
  end

  def parse_subroutines([{:symbol, "}"} | rest]), do: {[], rest}

  def parse_parameter_list([{:symbol, "("} | rest]) do
    {params, rest1} = parse_parameters(rest)
    {[{:symbol, "("},
      {:parameterList, params},
      {:symbol, ")"}], rest1}
  end

  def parse_parameters([{:symbol, ")"} | rest]), do: {[], rest}

  def parse_parameters([{:symbol, ","} | rest]) do
    {params, rest1} = parse_parameters(rest)
    {[{:symbol, ","}] ++ params, rest1}
  end
  
  def parse_parameters([{keyword_or_identifier, type},
                        {:identifier, var_name}
                        | rest]) do
    {params, rest1} = parse_parameters(rest)
    {[{keyword_or_identifier, type},
      {:identifier, var_name}] ++ params, rest1}
  end

  def parse_subroutine_body([{:symbol, "{"}
                             | rest]) do
    {var_decs, rest1}   = parse_var_dec(rest)
    {statements, rest2} = parse_statements(rest1)
    {[{:subroutineBody,
       [{:symbol, "{"}]
       ++ var_decs
       ++ statements
       ++
       [{:symbol, "}"}]}], rest2}
  end

  def parse_var_dec([{:keyword, "var"},
                     {keyword_or_identifier, type},
                     {:identifier, var_name}
                     | rest]) do
    {more, rest1} = parse_var_dec_end(rest)
    {next, rest2} = parse_var_dec(rest1)
    {[{:varDec,
       [{:keyword, "var"},
        {keyword_or_identifier, type},
        {:identifier, var_name}]
       ++ more}] ++ next, rest2}
  end

  def parse_var_dec(all), do: {[], all}
  
  def parse_var_dec_end([{:symbol, ","},
                         {:identifier, var_name}
                         | rest]) do
    {var, rest1} = parse_var_dec_end(rest)
    {[{:symbol, ","},
      {:identifier, var_name}]
     ++ var, rest1}
  end

  def parse_var_dec_end([{:symbol, ";"} | rest]) do
    {[{:symbol, ";"}], rest}
  end
    
  def parse_statements([{:keyword, keyword}
                        | _]=all) when keyword in @jack_statements do
    {statements, rest} = parse_statement(all)
    {[{:statements, statements}], rest}
  end

  def parse_statement([{:symbol, "}"} | rest]), do: {[], rest}
  
  def parse_statement([{:keyword, "let"},
                       {:identifier, var_lhs},
                       {:symbol, "="},
                       {:identifier, var_rhs},
                       {:symbol, ";"} | rest]) do
    {statement, rest1} = parse_statement(rest)
    {[{:letStatement,
       [{:keyword, "let"},
        {:identifier, var_lhs},
        {:symbol, "="},
        {:expression,
         [{:term,
           [{:identifier, var_rhs}]}]},
        {:symbol, ";"}]}]
     ++ statement, rest1}
  end

  def parse_statement([{:keyword, "let"},
                       {:identifier, var_lhs},
                       {:symbol, "="}
                      | rest]) do
    {rh_exp, rest1} = parse_e(rest)
    [{:symbol, ";"} | rest2] = rest1
    {statement, rest3} = parse_statement(rest2)
    {[{:letStatement,
       [{:keyword, "let"},
        {:identifier, var_lhs},
        {:symbol, "="},
        {:expression, rh_exp},
        {:symbol, ";"}]}]
     ++ statement, rest3}
  end

  def parse_statement([{:keyword, "let"},
                       {:identifier, var_lhs},
                       {:symbol, "["}
                       | rest]) do
    {index_exp, rest1} = parse_e(rest)
    [{:symbol, "]"},
     {:symbol, "="} | rest2] = rest1
    {rh_exp, rest3} = parse_e(rest2)
    [{:symbol, ";"} | rest4] = rest3
    {statement, rest5} = parse_statement(rest4)
    {[{:letStatement,
       [{:keyword, "let"},
        {:identifier, var_lhs},
        {:symbol, "["},
        {:expression, index_exp},
        {:symbol, "]"},
        {:symbol, "="},
        {:expression, rh_exp},
       {:symbol, ";"}]}] ++ statement, rest5}
  end

  def parse_statement([{:keyword, "if"},
                       {:symbol, "("} | rest]) do
    {exp, rest1} = parse_e(rest)
    [{:symbol, ")"},
     {:symbol, "{"}| rest2] = rest1
    {statements, rest3} = parse_statements(rest2)
    {else_statements, rest4} = parse_else_statements(rest3)
    {more, rest5} = parse_statement(rest4)
    {[{:ifStatement,
       [{:keyword, "if"},
        {:symbol, "("},
        {:expression, exp},
        {:symbol, ")"},
        {:symbol, "{"}]
       ++ statements
       ++
       [{:symbol, "}"}]
       ++ else_statements}] ++ more, rest5}
  end
  
  def parse_statement([{:keyword, "while"},
                       {:symbol, "("}| rest]) do
    {exp, rest1} = parse_e(rest)
    [{:symbol, ")"},
     {:symbol, "{"}| rest2] = rest1
    {statements, rest3} = parse_statements(rest2)
    {more, rest4} = parse_statement(rest3)
    {[{:whileStatement,
       [{:keyword, "while"},
        {:symbol, "("},
        {:expression, exp},
        {:symbol, ")"},
        {:symbol, "{"}]
       ++ statements
       ++
       [{:symbol, "}"}]}] ++ more, rest4}
  end

  def parse_statement([{:keyword, "do"} | rest]) do
    {subroutine_call, rest1} = parse_subroutine_call(rest)
    [{:symbol, ";"} | rest2] = rest1;
    {statement, rest3} = parse_statement(rest2)
    {[{:doStatement,
       [{:keyword, "do"}]
       ++ subroutine_call
       ++
       [{:symbol, ";"}]}] ++ statement, rest3}
  end

  def parse_statement([{:keyword, "return"},
                       {:symbol, ";"}
                       | rest]) do
    {statement, rest1} = parse_statement(rest)
    {[{:returnStatement,
       [{:keyword, "return"},
        {:symbol, ";"}]}] ++ statement, rest1}
  end

  def parse_statement([{:keyword, "return"}
                       | rest]) do
    {expression, rest1} = parse_e(rest)
    [{:symbol, ";"} | rest2] = rest1
    {statement, rest3} = parse_statement(rest2)
    {[{:returnStatement,
       [{:keyword, "return"},
        {:expression, expression},
        {:symbol, ";"}]}] ++ statement, rest3}
    
  end
  
  def parse_e(all) do
    {exp, rest} = parse_expression(all)
    case List.first(rest) do
      {:symbol, op} when op in @expression_operators ->
        {exp1, rest1} = parse_e(Enum.drop(rest, 1))
        {exp ++ [{:symbol, op_to_xml(op)}] ++ exp1, rest1}
      _ ->
        {exp, rest}
    end
  end

  def parse_e_list(all) do
    {exp, rest} = parse_e(all)
    case List.first(rest) do
      {:symbol, ","} ->
        {exp1, rest1} = parse_e_list(Enum.drop(rest, 1))
        {[{:expression, exp},
          {:symbol, ","}] ++ exp1, rest1}
      _ ->
        {[{:expression, exp}], rest}
    end
  end
    
  def parse_expression([{:symbol, "("} | rest]) do
    {exp, rest1} = parse_e(rest)
    [{:symbol, ")"} | rest2] = rest1
    {[{:term,
       [{:symbol, "("},
        {:expression, exp},
        {:symbol, ")"}]}], rest2}
  end

  def parse_expression([{:integerConstant, i} | rest]) do
    {[{:term, [{:integerConstant, "#{i}"}]}], rest}
  end

  def parse_expression([{:stringConstant, s} | rest]) do
    {[{:term, [{:stringConstant, s}]}], rest}
  end

  def parse_expression([{:symbol, u} | rest])
  when u in @expression_unary_operators do
    {exp, rest1} = parse_expression(rest)
    {[{:term, [{:symbol, u}] ++ exp}], rest1}
  end
  
  def parse_expression([{:identifier, var_name},
                        {:symbol, s}=s_token | rest])
  when s in @expression_closing_symbols do
    {[{:term, [{:identifier, var_name}]}], [s_token | rest]}
  end

  def parse_expression([{:keyword, k},
                        {:symbol, s}=s_token | rest])
  when s in @expression_closing_symbols
  and  k in @expression_keyword_constants do
    {[{:term, [{:keyword, k}]}], [s_token | rest]}
  end

  # Delimited by comma: var
  def parse_expression([{:identifier, var_name},
                        {:symbol, ","}=s_token | rest]) do
    {[{:term, [{:identifier, var_name}]}], [s_token | rest]}
  end

  # Delimited by comma: keyword constant
  def parse_expression([{:keyword, keyword_const},
                        {:symbol, ","}=s_token | rest])
  when keyword_const in @expression_keyword_constants do
    {[{:term, [{:keyword, keyword_const}]}], [s_token | rest]}
  end

  # LHS (var) of op
  def parse_expression([{:identifier, var_name},
                        {:symbol, op}=op_token | rest])
  when op in @expression_operators do
    {[{:term, [{:identifier, var_name}]}], [op_token | rest]}
  end

  # LHS (keyword constand) of op
  def parse_expression([{:keyword, keyword_const},
                        {:symbol, op}=op_token | rest])
  when op in @expression_operators
  and  keyword_const in @expression_keyword_constants do
    {[{:term, {:keyword, keyword_const}}], [op_token | rest]}
  end

  # subroutine 1 of 2 (where's #2?)
  def parse_expression([{:identifier, class_or_var_name},
                        {:symbol, "."},
                        {:identifier, subroutine_name},
                        {:symbol, "("}
                        | rest]) do
    {exp_list, rest1} = parse_expression_list(rest)
    {[{:term,
       [{:identifier, class_or_var_name},
        {:symbol, "."},
        {:identifier, subroutine_name},
        {:symbol, "("}]
       ++ exp_list
       ++
       [{:symbol, ")"}]}], rest1}
  end

  def parse_expression([{:identifier, var_name},
                        {:symbol, "["}
                        | rest]) do
    {exp, rest1} = parse_e(rest)
    [{:symbol, "]"} | rest2] = rest1
    {[{:term,
       [{:identifier, var_name},
        {:symbol, "["},
        {:expression, exp},
        {:symbol, "]"}]}], rest2}
  end
  
  def parse_expression([{:symbol, s} | _]=all)
  when s in @expression_closing_symbols do
    {[], all}
  end

  def op_to_xml(">"), do: "&gt;"
  def op_to_xml("<"), do: "&lt;"
  def op_to_xml("&"), do: "&amp;"
  def op_to_xml(x), do: x
  
  def parse_subroutine_call([{:identifier, subroutine_name},
                             {:symbol, "("}
                             | rest]) do
    {exp_list, rest1} = parse_expression_list(rest)
    {[{:identifier, subroutine_name},
      {:symbol, "("}]
     ++ exp_list
     ++
    [{:symbol, ")"}], rest1}
  end

  def parse_subroutine_call([{:identifier, class_or_var_name},
                             {:symbol, "."},
                             {:identifier, subroutine_name},
                             {:symbol, "("}
                             | rest]) do
    {exp_list, rest1} = parse_expression_list(rest)
    {[{:identifier, class_or_var_name},
      {:symbol, "."},
      {:identifier, subroutine_name},
      {:symbol, "("}]
     ++ exp_list
     ++
     [{:symbol, ")"}], rest1}
  end

  def parse_expression_list([{:symbol, ")"} | rest]) do
    {[{:expressionList, []}], rest}
  end

  def parse_expression_list(all) do
    {e_list, rest} = parse_e_list(all)
    [{:symbol, ")"} | rest1] = rest
    {[{:expressionList, e_list}], rest1}
  end
    
  def parse_else_statements([{:keyword, "else"},
                             {:symbol, "{"} | rest]) do
    {statements, rest1} = parse_statements(rest)
    [{:symbol, "}"} | rest2] = rest1
    {[{:keyword, "else"},
      {:symbol, "{"}]
     ++ statements
     ++
    [{:symbol, "}"}], rest2}
  end

  def parse_else_statements(all), do: {[], all}

  def margin(level), do: String.duplicate("  ", level)
  
  def tree_to_xml([{k, vs} | rest], indent_level: i) when is_list(vs) do
    m = margin(i)
    ["#{m}<#{k}>"]
    ++ tree_to_xml(vs, indent_level: i+1)
    ++
    ["#{m}</#{k}>"]
    ++ tree_to_xml(rest, indent_level: i)
  end
  def tree_to_xml([], _), do: []
  def tree_to_xml([{k, v} | rest], indent_level: i) do
    m = margin(i)
    ["#{m}<#{k}> #{v} </#{k}>"]
    ++ tree_to_xml(rest, indent_level: i)
  end

  def to_xml(tree), do: tree_to_xml(tree, indent_level: 0)
end
