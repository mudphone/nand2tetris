defmodule Tokenizer do
  alias Env
  
  defmodule Env do
	  defstruct str_const: nil, comments: 0, acc: ""
  end

  @jack_keywords ["class", "constructor", "function", "method",
                  "field", "static", "var", "int", "char", "boolean",
                  "void", "true", "false", "null", "this", "let",
                  "do", "if", "else", "while", "return"]
  
  @jack_symbols ["{", "}", "(", ")", "[", "]", ".", ",", ";",
                 "+", "-", "*", "/", "&", "|", "<", ">", "=",
                 "~"]

  @doc """
  Chomps off the front character and tokenizes based on what it finds
  """
  # Starts chomping off a multi-line comment
  def bite("/*" <> rest, %Env{comments: level}=env) do
    bite(rest, %Env{env | comments: level + 1})
  end

  # Finishes chomping off a multi-line comment
  def bite("*/" <> rest, %Env{comments: level}=env) do
    bite(rest, %{env | comments: level - 1})
  end

  # Continues chomping off a multi-line comment
  def bite(<<_>> <> rest, %Env{comments: level}=env) when level > 0 do
    bite(rest, env)
  end

  # Starts storing a string constant
  def bite("\"" <> rest, %Env{str_const: nil}) do
    bite(rest, %Env{str_const: "\""})
  end

  # Finishes storing a string constant
  def bite("\"" <> rest, %Env{str_const: str_const}=env) do
    [to_token_tup(str_const <> "\"")]
    ++ bite(rest, %Env{env | str_const: nil})
  end

  # Continues storing a string constant
  def bite(<<f>> <> rest, %Env{str_const: str_const}=env) when not is_nil(str_const) do
    bite(rest, %Env{env | str_const: str_const <> <<f>>})
  end

  # Hasn't saved any characters, so just saves the Jack symbol
  def bite(<<f>> <> rest, %Env{acc: ""}=env) when <<f>> in @jack_symbols do
    [to_token_tup(<<f>>)]
    ++ bite(rest, %Env{env | acc: ""})
  end

  # Emits saved characters and Jack symbol
  def bite(<<f>> <> rest, %Env{acc: acc}=env) when <<f>> in @jack_symbols do
    [to_token_tup(acc), to_token_tup(<<f>>)]
    ++ bite(rest, %Env{env | acc: ""})
  end

  # Handles multiple spaces
  def bite(<<f>> <> rest, %Env{acc: ""}=env) when f == ?\s do
    bite(rest, %Env{env | acc: ""})
  end

  # Emits saved characters lying before a space
  def bite(<<f>> <> rest, %Env{acc: acc}=env) when f == ?\s do
    [to_token_tup(acc)]
    ++ bite(rest, %Env{env | acc: ""})
  end

  # Save characters until we encounter a delimiter
  def bite(<<f>> <> rest, %Env{acc: acc}=env) when not <<f>> in @jack_symbols and f != ?\s do
    bite(rest, %Env{env | acc: acc <> <<f>>})
  end

  # Nothing left to chomp off
  def bite("", _), do: []
  
  def to_token_tup(t) when t in @jack_symbols,  do: {:symbol,  t}
  def to_token_tup(t) when t in @jack_keywords, do: {:keyword, t}
  def to_token_tup(t) do
    cond do
      string_convertible_to_integer?(t) ->
        {:integerConstant, t}
      string_constant?(t) ->
        {:stringConstant, String.slice(t, 1..-2)}
      true ->
        {:identifier, t}
    end
  end

  def string_constant?(s) do
    String.starts_with?(s, "\"") && String.ends_with?(s, "\"")
  end
  
  def string_convertible_to_integer?(s) do
    case Integer.parse(s) do
      :error    -> false
      {_int, _} -> true
    end
  end
  
  def tokenize(lines) do
    Enum.join(lines)
    |> bite(%Env{})
  end

  def xml_word({:symbol, "<"}),        do: "<symbol> &lt; </symbol>"
  def xml_word({:symbol, ">"}),        do: "<symbol> &gt; </symbol>"
  def xml_word({:symbol, "&"}),        do: "<symbol> &amp; </symbol>"  
  def xml_word({:symbol, w}),          do: "<symbol> #{w} </symbol>"
  def xml_word({:keyword, w}),         do: "<keyword> #{w} </keyword>"
  def xml_word({:stringConstant, w}),  do: "<stringConstant> #{w} </stringConstant>"
  def xml_word({:integerConstant, w}), do: "<integerConstant> #{w} </integerConstant>"
  def xml_word({_, w}),                do: "<identifier> #{w} </identifier>"
  
  def tokenize_xml(lines) do
    ["<tokens>"] ++ Enum.map(tokenize(lines), &xml_word/1) ++ ["</tokens>"]
  end
  
end
