defmodule Parser do

  @jack_statements ["let", "if", "while", "do", "return"]
  
  def parse([{:keyword, "class"},
             {:identifier, class_name},
             {:symbol, "{"}
             | rest]) do
    {class_var_decs, rest1} = parse_class_vars(rest)
    {subroutines, rest2} = parse_subroutines(rest1)
    {["<class>",
      "  <keyword> class </keyword>",
      "  <identifier> #{class_name} </identifier>",
      "  <symbol> { </symbol>"]
     ++ class_var_decs
     ++ subroutines
     ++
     ["  <symbol> } </symbol>",
      "</class>"], rest2}
  end

  def parse([{_, x} | rest]) do
    {["<other> #{x} <other>"], rest}
  end

  def parse([]), do: {[], []}

  def parse_class_vars([{:keyword, static_or_field},
                        {keyword_or_identifier, type},
                        {:identifier, var_name}
                        | rest])
  when static_or_field in ["static", "field"] do
    {more, rest1} = parse_class_vars_end(rest)
    {["  <classVarDec>",
      "    <keyword> #{static_or_field} </keyword>",
      "    <#{keyword_or_identifier}> #{type} </#{keyword_or_identifier}>",
      "    <identifier> #{var_name} </identifier>",
      ] ++ more, rest1}
  end

  def parse_class_vars(all), do: {[], all}

  def parse_class_vars_end([{:symbol, ","},
                            {:identifier, var_name}
                            | rest]) do
    {var, rest1} = parse_class_vars_end(rest)
    {["        <symbol> , </symbol>",
      "        <identifier> #{var_name} </identifier>"]
     ++ var, rest1}
  end

  def parse_class_vars_end([{:symbol, ";"} | rest]) do
    {more, rest1} = parse_class_vars(rest)
    {["        <symbol> ; </symbol>",
      "      </classVarDec>"] ++ more, rest1}
  end
  
  def parse_subroutines([{:keyword, cfm},
             {keyword_or_identifier, vort},
             {:identifier, subroutine_name}
             | rest])
  when cfm in ["constructor", "function", "method"] do
    {parameter_list, rest1} = parse_parameter_list(rest)
    {subroutine_body, rest2} = parse_subroutine_body(rest1)
    {more, rest3} = parse_subroutines(rest2)
    {["  <subroutineDec>",
      "    <keyword> #{cfm} </keyword>",
      "    <#{keyword_or_identifier}> #{vort} </#{keyword_or_identifier}>",
      "    <identifier> #{subroutine_name} </identifier>"]
     ++ parameter_list
     ++ subroutine_body
     ++
     ["  </subroutineDec>"] ++ more, rest3}
  end

  def parse_subroutines([{:symbol, "}"} | rest]), do: {[], rest}

  def parse_parameter_list([{:symbol, "("} | rest]) do
    {params, rest1} = parse_parameters(rest)
    {["    <symbol> ( </symbol>",
      "    <parameterList>"]
     ++ params
     ++
     ["    </parameterList>",
      "    <symbol> ) </symbol>"], rest1}
  end

  def parse_parameters([{:symbol, ")"} | rest]), do: {[], rest}

  def parse_parameters([{:symbol, ","} | rest]) do
    {params, rest1} = parse_parameters(rest)
    {["        <symbol> , </symbol>"] ++ params, rest1}
  end
  
  def parse_parameters([{keyword_or_identifier, type},
                        {:identifier, var_name}
                        | rest]) do
    {params, rest1} = parse_parameters(rest)
    {["      <#{keyword_or_identifier}> #{type} </#{keyword_or_identifier}>",
      "      <identifier> #{var_name} </identifier>"]
     ++ params, rest1}
  end

  def parse_subroutine_body([{:symbol, "{"}
                             | rest]) do
    {var_decs, rest1}   = parse_var_dec(rest)
    {statements, rest2} = parse_statements(rest1)
    {["    <subroutineBody>",
      "      <symbol> { </symbol>"]
     ++ var_decs
     ++ statements
     ++
     ["      <symbol> } </symbol>",
      "    </subroutineBody>"], rest2}
  end

  def parse_var_dec([{:keyword, "var"},
                     {keyword_or_identifier, type},
                     {:identifier, var_name}
                     | rest]) do
    {var, rest1} = parse_var_dec_end(rest)
    {["      <varDec>",
      "        <keyword> var </keyword>",
      "        <#{keyword_or_identifier}> #{type} </#{keyword_or_identifier}>",
      "        <identifier> #{var_name} </identifier>"]
     ++ var, rest1}
  end

  def parse_var_dec(all), do: {[], all}
  
  def parse_var_dec_end([{:symbol, ","},
                         {:identifier, var_name}
                         | rest]) do
    {var, rest1} = parse_var_dec_end(rest)
    {["        <symbol> , </symbol>",
      "        <identifier> #{var_name} </identifier>"]
     ++ var, rest1}
  end

  def parse_var_dec_end([{:symbol, ";"} | rest]) do
    {more, rest1} = parse_var_dec(rest)
    {["        <symbol> ; </symbol>",
      "      </varDec>"] ++ more, rest1}
  end

    
  def parse_statements([{:keyword, keyword}
                        | _]=all) when keyword in @jack_statements do
    {statements, rest} = parse_statement(all)
    {["      <statements>"]
     ++ statements
     ++
     ["      </statements>"], rest}
  end

  def parse_statement([{:symbol, "}"} | rest]), do: {[], rest}
  
  def parse_statement([{:keyword, "let"},
                       {:identifier, var_lhs},
                       {:symbol, "="},
                       {:identifier, var_rhs},
                       {:symbol, ";"} | rest]) do
    {statement, rest1} = parse_statement(rest)
    {["        <letStatement>",
      "          <keyword> let </keyword>",
      "          <identifier> #{var_lhs} </identifier>",
      "          <symbol> = </symbol>",
      "          <expression>",
      "            <term>",
      "              <identifier> #{var_rhs} </identifier>",
      "            </term>",
      "          </expression>",
      "          <symbol> ; </symbol>",
      "        </letStatement>"] ++ statement, rest1}
  end

  def parse_statement([{:keyword, "if"},
                       {:symbol, "("} | rest]) do
    {exp, rest1} = parse_expression(rest)
    [{:symbol, ")"},
     {:symbol, "{"}| rest2] = rest1
    {statements, rest3} = parse_statements(rest2)
    {else_statements, rest4} = parse_else_statements(rest3)
    {more, rest5} = parse_statement(rest4)
    {["        <ifStatement>",
      "          <keyword> if </keyword>",
      "          <symbol> ( </symbol>"]
     ++ exp
     ++
     ["          <symbol> ) </symbol>",
      "          <symbol> { </symbol>"]
     ++ statements
     ++
     ["          <symbol> } </symbol>"]
     ++ else_statements
     ++
     [
      "        </ifStatement>"] ++ more, rest5}
  end
  
  def parse_statement([{:keyword, "while"},
                       {:symbol, "("}| rest]) do
    {exp, rest1} = parse_expression(rest)
    [{:symbol, ")"},
     {:symbol, "{"}| rest2] = rest1
    {statements, rest3} = parse_statements(rest2)
    {more, rest4} = parse_statement(rest3)
    {["        <whileStatement>",
      "          <keyword> while </keyword>",
      "          <symbol> ( </symbol>"]
     ++ exp
     ++
     ["          <symbol> ) </symbol>",
      "          <symbol> { </symbol>"]
     ++ statements
     ++
     ["          <symbol> } </symbol>",
      "        </whileStatement>"] ++ more, rest4}
  end

  def parse_statement([{:keyword, "do"} | rest]) do
    {subroutine_call, rest1} = parse_subroutine_call(rest)
    [{:symbol, ";"} | rest2] = rest1;
    {statement, rest3} = parse_statement(rest2)
    {["        <doStatement>",
      "          <keyword> do </keyword>"]
     ++ subroutine_call
     ++
     ["          <symbol> ; </symbol>",
      "        </doStatement>"] ++ statement, rest3}
  end

  def parse_statement([{:keyword, "return"},
                       {:symbol, ";"}
                       | rest]) do
    {statement, rest1} = parse_statement(rest)
    {["        <returnStatement>",
      "          <keyword> return </keyword>",
      "          <symbol> ; </symbol>",
      "        </returnStatement>"] ++ statement, rest1}
  end

  def parse_statement([{:keyword, "return"}
                       | rest]) do
    {expression, rest1} = parse_expression(rest)
    [{:symbol, ";"} | rest2] = rest1
    {statement, rest3} = parse_statement(rest2)
    {["        <returnStatement>",
      "          <keyword> return </keyword>"]
     ++ expression
     ++
     ["          <symbol> ; </symbol>",
      "        </returnStatement>"]
     ++ statement, rest3}
  end

  def parse_expression([{:identifier, x} | rest]) do
    {more, rest1} = parse_expression(rest)
    {["          <expression>",
      "            <term>",
      "              <identifier> #{x} </identifier>",
      "            </term>",
      "          </expression>"] ++ more, rest1}
  end

  def parse_expression([{:symbol, ","} | rest]) do
    {exp, rest1} = parse_expression(rest)
    {["          <symbol> , </symbol>"] ++ exp, rest1}
  end

  def parse_expression(all), do: {[], all}
  
  def parse_subroutine_call([{:identifier, subroutine_name},
                             {:symbol, "("}
                             | rest]) do
    {exp_list, rest1} = parse_expression_list(rest)
    {["          <identifier> #{subroutine_name} </identifier>",
      "          <symbol> ( </symbol>"]
     ++ exp_list
     ++
     ["          <symbol> ) </symbol>"], rest1}
  end

  def parse_subroutine_call([{:identifier, class_or_var_name},
                             {:symbol, "."},
                             {:identifier, subroutine_name},
                             {:symbol, "("}
                             | rest]) do
    {exp_list, rest1} = parse_expression_list(rest)
    {["          <identifier> #{class_or_var_name} </identifier>",
      "          <symbol> . </symbol>",
      "          <identifier> #{subroutine_name} </identifier>",
      "          <symbol> ( </symbol>"]
     ++ exp_list
     ++
     ["          <symbol> ) </symbol>"], rest1}
  end

  def parse_expression_list([{:symbol, ")"} | rest]) do
    {["          <expressionList>",
      "          </expressionList>"], rest}
  end

  def parse_expression_list(all) do
    {exp, rest} = parse_expression(all)
    [{:symbol, ")"} | rest1] = rest
    {["          <expressionList>"]
     ++ exp
     ++
     ["          </expressionList>"], rest1}
  end

  def parse_else_statements([{:keyword, "else"},
                             {:symbol, "{"} | rest]) do
    {statements, rest1} = parse_statements(rest)
    [{:symbol, "}"} | rest2] = rest1
    {["          <keyword> else </keyword>",
      "          <symbol> { </symbol>"]
     ++ statements
     ++
     ["          <symbol> } </symbol>"], rest2}
  end

  def parse_else_statements(all), do: {[], all}
  
end
