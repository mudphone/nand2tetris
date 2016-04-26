defmodule CompilationEngine do
  alias SymbolTable.VarInfo
  
  @jack_statements ["let", "if", "while", "do", "return"]
  @expression_closing_symbols ["}", "]", ";", ")"]
  @expression_keyword_constants ["true", "false", "this", "null"]
  @expression_operators ["+", "-", "*", "/", "&", "|", "<", ">", "="]
  @expression_unary_operators ["-", "~"]

  # category: var argument static field class subroutine
  # presently: defined used
  # if one of these 4, then...
  #   kind: var argument static field
  #   index
  def attr_info(category, presently) do
    %{category: category, presently: presently}
  end

  def attr_info(t, name, :unknown, presently) do
    if SymbolTable.has_key?(t, name) do
      attr_info(t, name, SymbolTable.kind_of(t, name), presently)
    else
      attr_info(:unknown, presently)
    end
  end
  
  def attr_info(t, name, category, presently)
  when category in [:arg, :var] do
    kind = SymbolTable.kind_of(t, name)
    index = SymbolTable.index_of(t, name)
    attr_info_format(category, presently, kind, index)
  end

  def attr_info(t, name, category, presently)
  when category in [:static, :field] do
    if SymbolTable.has_key?(t, name) do
      %VarInfo{name: _, type: _, kind: kind, index: index} = SymbolTable.lookup(t, name)
      attr_info_format(category, presently, kind, index)
    else
      attr_info(:unknown, presently)
    end
  end

  def attr_info_format(category, presently, kind, index) do
    %{category: category, presently: presently, kind: kind, index: index}
  end

  def void_or_type(v_or_t, name) do
    case v_or_t do
      :keyword ->
        {:keyword, name}
      :identifier ->
        {:identifier, name, :attr, attr_info(:class, :used)}
    end
  end

  def string2atom(s), do: List.to_atom(String.to_char_list(s))
  
  def parse(x),  do: parse(x, SymbolTable.create())
  
  def parse([{:keyword, "class"},
             {:identifier, class_name},
             {:symbol, "{"}
             | rest], t) do
    {class_var_decs, rest1, t1} = parse_class_vars(rest, t)
    {subroutines, rest2, t2} = parse_subroutines(rest1, t1)
    {[{:class,
       [{:keyword, "class"},
        {:identifier, class_name, :attr, attr_info(:class, :defined)},
        {:symbol, "{"}]
       ++ class_var_decs
       ++ subroutines
       ++
       [{:symbol, "}"}]}], rest2, t2}
  end

  def parse([{_, x} | rest], t), do: {[{:other, x}], rest, t}

  def parse([], t), do: {[], [], t}

  def parse_class_vars([{:keyword, static_or_field},
                        {keyword_or_identifier, type},
                        {:identifier, var_name}
                        | rest], t)
  when static_or_field in ["static", "field"] do
    s_or_f = string2atom(static_or_field)
    t1 = SymbolTable.define(t, var_name, type, s_or_f)
    {more, rest1, t2} = parse_class_vars_end(rest, type, s_or_f, t1)
    {next, rest2, t3} = parse_class_vars(rest1, t2)
    {[{:classVarDec,
       [{:keyword, static_or_field},
        void_or_type(keyword_or_identifier, type),
        {:identifier, var_name, :attr, attr_info(t1, var_name, s_or_f, :defined)}]
       ++ more}] ++ next, rest2, t3}
  end

  def parse_class_vars(all, t), do: {[], all, t}

  def parse_class_vars_end([{:symbol, ","},
                            {:identifier, var_name}
                            | rest], type, static_or_field, t) do
    t1 = SymbolTable.define(t, var_name, type, static_or_field)
    {var, rest1, t2} = parse_class_vars_end(rest, type, static_or_field, t1)
    {[{:symbol, ","},
      {:identifier, var_name, :attr, attr_info(t1, var_name, static_or_field, :defined)}]
     ++ var, rest1, t2}
  end

  def parse_class_vars_end([{:symbol, ";"} | rest], _type, _static_or_field, t) do
    {[{:symbol, ";"}], rest, t}
  end
  
  def parse_subroutines([{:keyword, cfm},
             {keyword_or_identifier, vort},
             {:identifier, subroutine_name}
             | rest], t)
  when cfm in ["constructor", "function", "method"] do
    t1 = SymbolTable.start_subroutine(t)
    {parameter_list, rest1, t2} = parse_parameter_list(rest, t1)
    {subroutine_body, rest2, t3} = parse_subroutine_body(rest1, t2)
    {more, rest3, t4} = parse_subroutines(rest2, t3)
    {[{:subroutineDec,
       [{:keyword, cfm},
        void_or_type(keyword_or_identifier, vort),
        {:identifier, subroutine_name, :attr, attr_info(:subroutine, :defined)}]
       ++ parameter_list
       ++ subroutine_body}] ++ more, rest3, t4}
  end

  def parse_subroutines([{:symbol, "}"} | rest], t), do: {[], rest, t}

  def parse_parameter_list([{:symbol, "("} | rest], t) do
    {params, rest1, t1} = parse_parameters(rest, t)
    {[{:symbol, "("},
      {:parameterList, params},
      {:symbol, ")"}], rest1, t1}
  end

  def parse_parameters([{:symbol, ")"} | rest], t), do: {[], rest, t}

  def parse_parameters([{:symbol, ","} | rest], t) do
    {params, rest1, t1} = parse_parameters(rest, t)
    {[{:symbol, ","}] ++ params, rest1, t1}
  end
  
  def parse_parameters([{keyword_or_identifier, type},
                        {:identifier, var_name}
                        | rest], t) do
    t1 = SymbolTable.define(t, var_name, type, :arg)
    {params, rest1, t2} = parse_parameters(rest, t1)
    {[void_or_type(keyword_or_identifier, type),
      {:identifier, var_name, :attr, attr_info(t1, var_name, :arg, :defined)}]
     ++ params, rest1, t2}
  end

  def parse_subroutine_body([{:symbol, "{"}
                             | rest], t) do
    {var_decs, rest1, t1}   = parse_var_dec(rest, t)
    {statements, rest2, t2} = parse_statements(rest1, t1)
    {[{:subroutineBody,
       [{:symbol, "{"}]
       ++ var_decs
       ++ statements
       ++
       [{:symbol, "}"}]}], rest2, t2}
  end

  def parse_var_dec([{:keyword, "var"},
                     {keyword_or_identifier, type},
                     {:identifier, var_name}
                     | rest], t) do
    t1 = SymbolTable.define(t, var_name, type, :var)
    {more, rest1, t2} = parse_var_dec_end(rest, type, t1)
    {next, rest2, t3} = parse_var_dec(rest1, t2)
    {[{:varDec,
       [{:keyword, "var"},
        void_or_type(keyword_or_identifier, type),
        {:identifier, var_name, :attr, attr_info(t1, var_name, :var, :defined)}]
       ++ more}] ++ next, rest2, t3}
  end

  def parse_var_dec(all, t), do: {[], all, t}
  
  def parse_var_dec_end([{:symbol, ","},
                         {:identifier, var_name}
                         | rest], type, t) do
    t1 = SymbolTable.define(t, var_name, type, :var)
    {var, rest1, t2} = parse_var_dec_end(rest, type, t1)
    {[{:symbol, ","},
      {:identifier, var_name, :attr, attr_info(t1, var_name, :var, :defined)}]
     ++ var, rest1, t2}
  end

  def parse_var_dec_end([{:symbol, ";"} | rest], _, t) do
    {[{:symbol, ";"}], rest, t}
  end
    
  def parse_statements([{:keyword, keyword}
                        | _]=all, t) when keyword in @jack_statements do
    {statements, rest, t1} = parse_statement(all, t)
    {[{:statements, statements}], rest, t1}
  end

  def parse_statement([{:symbol, "}"} | rest], t), do: {[], rest, t}
  
  def parse_statement([{:keyword, "let"},
                       {:identifier, var_lhs},
                       {:symbol, "="},
                       {:identifier, var_rhs},
                       {:symbol, ";"} | rest], t) do
    {statement, rest1, t1} = parse_statement(rest, t)
    {[{:letStatement,
       [{:keyword, "let"},
        {:identifier, var_lhs, :attr, attr_info(t, var_lhs, :unknown, :used)},
        {:symbol, "="},
        {:expression,
         [{:term,
           [{:identifier, var_rhs, :attr, attr_info(t, var_rhs, :unknown, :used)}]}]},
        {:symbol, ";"}]}]
     ++ statement, rest1, t1}
  end

  def parse_statement([{:keyword, "let"},
                       {:identifier, var_lhs},
                       {:symbol, "="}
                       | rest], t) do
    {rh_exp, rest1, t1} = parse_e(rest, t)
    [{:symbol, ";"} | rest2] = rest1
    {statement, rest3, t2} = parse_statement(rest2, t1)
    {[{:letStatement,
       [{:keyword, "let"},
        {:identifier, var_lhs, :attr, attr_info(t, var_lhs, :unknown, :used)},
        {:symbol, "="},
        {:expression, rh_exp},
        {:symbol, ";"}]}]
     ++ statement, rest3, t2}
  end

  def parse_statement([{:keyword, "let"},
                       {:identifier, var_lhs},
                       {:symbol, "["}
                       | rest], t) do
    {index_exp, rest1, t1} = parse_e(rest, t)
    [{:symbol, "]"},
     {:symbol, "="} | rest2] = rest1
    {rh_exp, rest3, t2} = parse_e(rest2, t1)
    [{:symbol, ";"} | rest4] = rest3
    {statement, rest5, t3} = parse_statement(rest4, t2)
    {[{:letStatement,
       [{:keyword, "let"},
        {:identifier, var_lhs, :attr, attr_info(:unknown, :used)},
        {:symbol, "["},
        {:expression, index_exp},
        {:symbol, "]"},
        {:symbol, "="},
        {:expression, rh_exp},
       {:symbol, ";"}]}] ++ statement, rest5, t3}
  end

  def parse_statement([{:keyword, "if"},
                       {:symbol, "("} | rest], t) do
    {exp, rest1, t1} = parse_e(rest, t)
    [{:symbol, ")"},
     {:symbol, "{"}| rest2] = rest1
    {statements, rest3, t2} = parse_statements(rest2, t1)
    {else_statements, rest4, t3} = parse_else_statements(rest3, t2)
    {more, rest5, t4} = parse_statement(rest4, t3)
    {[{:ifStatement,
       [{:keyword, "if"},
        {:symbol, "("},
        {:expression, exp},
        {:symbol, ")"},
        {:symbol, "{"}]
       ++ statements
       ++
       [{:symbol, "}"}]
       ++ else_statements}] ++ more, rest5, t4}
  end
  
  def parse_statement([{:keyword, "while"},
                       {:symbol, "("}| rest], t) do
    {exp, rest1, t1} = parse_e(rest, t)
    [{:symbol, ")"},
     {:symbol, "{"}| rest2] = rest1
    {statements, rest3, t2} = parse_statements(rest2, t1)
    {more, rest4, t3} = parse_statement(rest3, t2)
    {[{:whileStatement,
       [{:keyword, "while"},
        {:symbol, "("},
        {:expression, exp},
        {:symbol, ")"},
        {:symbol, "{"}]
       ++ statements
       ++
       [{:symbol, "}"}]}] ++ more, rest4, t3}
  end

  def parse_statement([{:keyword, "do"} | rest], t) do
    {subroutine_call, rest1, t1} = parse_subroutine_call(rest, t)
    [{:symbol, ";"} | rest2] = rest1;
    {statement, rest3, t2} = parse_statement(rest2, t1)
    {[{:doStatement,
       [{:keyword, "do"}]
       ++ subroutine_call
       ++
       [{:symbol, ";"}]}] ++ statement, rest3, t2}
  end

  def parse_statement([{:keyword, "return"},
                       {:symbol, ";"}
                       | rest], t) do
    {statement, rest1, t1} = parse_statement(rest, t)
    {[{:returnStatement,
       [{:keyword, "return"},
        {:symbol, ";"}]}] ++ statement, rest1, t1}
  end

  def parse_statement([{:keyword, "return"}
                       | rest], t) do
    {expression, rest1, t1} = parse_e(rest, t)
    [{:symbol, ";"} | rest2] = rest1
    {statement, rest3, t2} = parse_statement(rest2, t1)
    {[{:returnStatement,
       [{:keyword, "return"},
        {:expression, expression},
        {:symbol, ";"}]}] ++ statement, rest3, t2}
    
  end
  
  def parse_e(all, t) do
    {exp, rest, t1} = parse_expression(all, t)
    case List.first(rest) do
      {:symbol, op} when op in @expression_operators ->
        {exp1, rest1, t2} = parse_e(Enum.drop(rest, 1), t1)
        {exp ++ [{:symbol, op_to_xml(op)}] ++ exp1, rest1, t2}
      _ ->
        {exp, rest, t1}
    end
  end

  def parse_e_list(all, t) do
    {exp, rest, t1} = parse_e(all, t)
    case List.first(rest) do
      {:symbol, ","} ->
        {exp1, rest1, t2} = parse_e_list(Enum.drop(rest, 1), t1)
        {[{:expression, exp},
          {:symbol, ","}] ++ exp1, rest1, t2}
      _ ->
        {[{:expression, exp}], rest, t1}
    end
  end
    
  def parse_expression([{:symbol, "("} | rest], t) do
    {exp, rest1, t1} = parse_e(rest, t)
    [{:symbol, ")"} | rest2] = rest1
    {[{:term,
       [{:symbol, "("},
        {:expression, exp},
        {:symbol, ")"}]}], rest2, t1}
  end

  def parse_expression([{:integerConstant, i} | rest], t) do
    {[{:term, [{:integerConstant, "#{i}"}]}], rest, t}
  end

  def parse_expression([{:stringConstant, s} | rest], t) do
    {[{:term, [{:stringConstant, s}]}], rest, t}
  end

  def parse_expression([{:symbol, u} | rest], t)
  when u in @expression_unary_operators do
    {exp, rest1, t1} = parse_expression(rest, t)
    {[{:term, [{:symbol, u}] ++ exp}], rest1, t1}
  end
  
  def parse_expression([{:identifier, var_name},
                        {:symbol, s}=s_token | rest], t)
  when s in @expression_closing_symbols do
    {[{:term, [{:identifier, var_name, :attr, attr_info(t, var_name, :unknown, :used)}]}], [s_token | rest], t}
  end

  def parse_expression([{:keyword, k},
                        {:symbol, s}=s_token | rest], t)
  when s in @expression_closing_symbols
  and  k in @expression_keyword_constants do
    {[{:term, [{:keyword, k}]}], [s_token | rest], t}
  end

  # Delimited by comma: var
  def parse_expression([{:identifier, var_name},
                        {:symbol, ","}=s_token | rest], t) do
    {[{:term, [{:identifier, var_name, :attr, attr_info(t, var_name, :unknown, :used)}]}], [s_token | rest], t}
  end

  # Delimited by comma: keyword constant
  def parse_expression([{:keyword, keyword_const},
                        {:symbol, ","}=s_token | rest], t)
  when keyword_const in @expression_keyword_constants do
    {[{:term, [{:keyword, keyword_const}]}], [s_token | rest], t}
  end

  # LHS (var) of op
  def parse_expression([{:identifier, var_name},
                        {:symbol, op}=op_token | rest], t)
  when op in @expression_operators do
    {[{:term, [{:identifier, var_name, :attr, attr_info(t, var_name, :unknown, :used)}]}], [op_token | rest], t}
  end

  # LHS (keyword constand) of op
  def parse_expression([{:keyword, keyword_const},
                        {:symbol, op}=op_token | rest], t)
  when op in @expression_operators
  and  keyword_const in @expression_keyword_constants do
    {[{:term, {:keyword, keyword_const}}], [op_token | rest], t}
  end

  # subroutine 1 of 2 (where's #2?)
  def parse_expression([{:identifier, class_or_var_name},
                        {:symbol, "."},
                        {:identifier, subroutine_name},
                        {:symbol, "("}
                        | rest], t) do
    {exp_list, rest1, t1} = parse_expression_list(rest, t)
    {[{:term,
       [{:identifier, class_or_var_name, :attr, attr_info(t, class_or_var_name, :unknown, :used)},
        {:symbol, "."},
        {:identifier, subroutine_name, :attr, attr_info(:subroutine, :used)},
        {:symbol, "("}]
       ++ exp_list
       ++
       [{:symbol, ")"}]}], rest1, t1}
  end

  def parse_expression([{:identifier, var_name},
                        {:symbol, "["}
                        | rest], t) do
    {exp, rest1, t1} = parse_e(rest, t)
    [{:symbol, "]"} | rest2] = rest1
    {[{:term,
       [{:identifier, var_name, :attr, attr_info(t, var_name, :unknown, :used)},
        {:symbol, "["},
        {:expression, exp},
        {:symbol, "]"}]}], rest2, t1}
  end
  
  def parse_expression([{:symbol, s} | _]=all, t)
  when s in @expression_closing_symbols do
    {[], all, t}
  end

  def op_to_xml(">"), do: "&gt;"
  def op_to_xml("<"), do: "&lt;"
  def op_to_xml("&"), do: "&amp;"
  def op_to_xml(x), do: x
  
  def parse_subroutine_call([{:identifier, subroutine_name},
                             {:symbol, "("}
                             | rest], t) do
    {exp_list, rest1, t1} = parse_expression_list(rest, t)
    {[{:identifier, subroutine_name, :attr, attr_info(:subroutine, :used)},
      {:symbol, "("}]
     ++ exp_list
     ++
    [{:symbol, ")"}], rest1, t1}
  end

  def parse_subroutine_call([{:identifier, class_or_var_name},
                             {:symbol, "."},
                             {:identifier, subroutine_name},
                             {:symbol, "("}
                             | rest], t) do
    {exp_list, rest1, t1} = parse_expression_list(rest, t)
    {[{:identifier, class_or_var_name, :attr, attr_info(:unknown, :used)},
      {:symbol, "."},
      {:identifier, subroutine_name, :attr, attr_info(:subroutine, :used)},
      {:symbol, "("}]
     ++ exp_list
     ++
     [{:symbol, ")"}], rest1, t1}
  end

  def parse_expression_list([{:symbol, ")"} | rest], t) do
    {[{:expressionList, []}], rest, t}
  end

  def parse_expression_list(all, t) do
    {e_list, rest, t1} = parse_e_list(all, t)
    [{:symbol, ")"} | rest1] = rest
    {[{:expressionList, e_list}], rest1, t1}
  end
    
  def parse_else_statements([{:keyword, "else"},
                             {:symbol, "{"} | rest], t) do
    {statements, rest1, t1} = parse_statements(rest, t)
    [{:symbol, "}"} | rest2] = rest1
    {[{:keyword, "else"},
      {:symbol, "{"}]
     ++ statements
     ++
    [{:symbol, "}"}], rest2, t1}
  end

  def parse_else_statements(all, t), do: {[], all, t}

  def margin(level), do: String.duplicate("  ", level)

  def attr_str(_name, %{category: category, presently: presently, kind: kind, index: index}, _t) do
    " category=\"#{category}\" presently=\"#{presently}\" kind=\"#{kind}\" index=\"#{index}\""
  end

  def attr_str(name, %{category: :unknown, presently: presently}, t) do
    if SymbolTable.has_key?(t, name) do
      %VarInfo{name: _, type: _, kind: kind, index: index} = SymbolTable.lookup(t, name)
      " category=\"#{kind}\" presently=\"#{presently}\" kind=\"#{kind}\" index=\"#{index}\""
    else
      " category=\"class\" presently=\"#{presently}\""
    end
  end

  def attr_str(name, %{category: category, presently: presently}, t) do
    if SymbolTable.has_key?(t, name) do
      %VarInfo{name: _, type: _, kind: kind, index: index} = SymbolTable.lookup(t, name)
      " category=\"#{category}\" presently=\"#{presently}\" kind=\"#{kind}\" index=\"#{index}\""
    else
      " category=\"#{category}\" presently=\"#{presently}\""
    end
    
  end
  
  def tree_to_xml([{:identifier, _name, :attr, nil} | _rest]=tree, t, indent_level: i) do
    tree_to_xml(tree, t,  indent_level: i)
  end
  def tree_to_xml([{:identifier, name, :attr, attr} | rest], t, indent_level: i) do
    m = margin(i)
    ["#{m}<identifier#{attr_str(name, attr, t)}> #{name} </identifier>"]
    ++ tree_to_xml(rest, t, indent_level: i)
  end
  def tree_to_xml([{k, vs} | rest], t, indent_level: i) when is_list(vs) do
    m = margin(i)
    ["#{m}<#{k}>"]
    ++ tree_to_xml(vs, t, indent_level: i+1)
    ++
    ["#{m}</#{k}>"]
    ++ tree_to_xml(rest, t, indent_level: i)
  end
  def tree_to_xml([], _, _), do: []
  def tree_to_xml([{k, v} | rest], t, indent_level: i) do
    m = margin(i)
    ["#{m}<#{k}> #{v} </#{k}>"]
    ++ tree_to_xml(rest, t, indent_level: i)
  end

  def to_xml(tree, t), do: tree_to_xml(tree, t, indent_level: 0)  
end