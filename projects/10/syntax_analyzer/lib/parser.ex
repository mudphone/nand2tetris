defmodule Parser do

  @jack_statements ["let", "if", "while", "do", "return"]
  
  def parse([{:keyword, "class"},
             {:identifier, class_name},
             {:symbol, "{"}
             | rest]) do
    {subroutines, rest1} = parse(rest)
    [{:symbol, "}"}] = rest1
    {["<class>",
      "  <keyword> class </keyword>",
      "  <identifier> #{class_name} </identifier>",
      "  <symbol> { </symbol>"]
     ++
     subroutines
     ++
     ["  <symbol> } </symbol>",
      "</class>"], []}
  end

  def parse([{:keyword, cfm},
             {keyword_or_identifier, vort},
             {:identifier, subroutine_name}
             | rest])
  when cfm in ["constructor", "function", "method"] do
    {parameter_list, rest1} = parse_parameter_list(rest)
    {subroutine_body, rest2} = parse_subroutine_body(rest1)
    {["  <subroutineDec>",
      "    <keyword> #{cfm} </keyword>",
      "    <#{keyword_or_identifier}> #{vort} </#{keyword_or_identifier}>",
      "    <identifier> #{subroutine_name} </identifier>"]
     ++
     parameter_list
     ++
     subroutine_body
     ++
     ["  </subroutineDec>"], rest2}
  end

  def parse([{_, x} | rest]) do
    {["<other> #{x} <other>"], rest}
  end

  def parse([]), do: {[], []}

  def parse_parameter_list([{:symbol, "("} | rest]) do
    {params, rest1} = parse_parameters(rest)
    {["    <symbol> ( </symbol>",
      "    <parameterList>"]
     ++
     params
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
     ++
     var_decs
     ++
     statements
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
  
  def parse_var_dec_end([{:symbol, ","},
                         {:identifier, var_name}
                         | rest]) do
    {var, rest1} = parse_var_dec_end(rest)
    {["        <symbol> , </symbol>",
      "        <identifier> #{var_name} </identifier>"]
     ++ var, rest1}
  end

  def parse_var_dec_end([{:symbol, ";"} | rest]) do
    {["        <symbol> ; </symbol>",
      "      </varDec>"], rest}
  end

    
  def parse_statements([{:keyword, keyword}
                        | _]=all) when keyword in @jack_statements do
    {statements, rest} = parse_statement(all)
    {["      <statements>"]
     ++
     statements
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

  def parse_statement([{:keyword, "if"} | rest]) do
    []
  end

  def parse_statement([{:keyword, "while"} | rest]) do
    []
  end

  def parse_statement([{:keyword, "do"} | rest]) do
    {subroutine_call, rest1} = parse_subroutine_call(rest)
    {statement, rest2} = parse_statement(rest1)
    {["        <doStatement>",
      "          <keyword> do </keyword>"]
     ++
     subroutine_call
     ++
     ["        </doStatement>"] ++ statement, rest2}
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
    {exp, rest1} = parse_expression(rest)
    {statement, rest2} = parse_statement(rest1)
    {["        <returnStatement>",
      "          <keyword> return </keyword>",
      "          <symbol> ; </symbol>",
      "        </returnStatement>"] ++ statement, rest2}
  end

  def parse_expression([{:identifier, x} | rest]) do
    {["          <expression>",
      "            <term>",
      "              <identifier> #{x} </identifier>",
      "            </term>",
      "          </expression>"], rest}
  end
  
  def parse_subroutine_call([{:identifier, subroutine_name},
                             {:symbol, "("}
                             | rest]) do
    {exp_list, rest1} = parse_expression_list(rest)
    {["          <identifier> #{subroutine_name} </identifier>",
      "          <symbol> ( </symbol>"]
     ++
     exp_list
     ++
     ["          <symbol> ) </symbol>",
      "          <symbol> ; </symbol>"], rest1}
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
     ++
     exp_list
     ++
     ["          <symbol> ) </symbol>",
      "          <symbol> ; </symbol>"], rest1}
  end

  def parse_expression_list([{:symbol, ")"},
                             {:symbol, ";"} | rest]) do
    {["          <expressionList>",
      "          </expressionList>"], rest}
  end

end
