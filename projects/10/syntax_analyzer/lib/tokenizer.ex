defmodule Tokenizer do

  @jack_keywords ["class", "constructor", "function", "method",
                  "field", "static", "var", "int", "char", "boolean",
                  "void", "true", "false", "null", "this", "let",
                  "do", "if", "else", "while", "return"]
  
  @jack_symbols ["{", "}", "(", ")", "[", "]", ".", ",", ";",
                 "+", "-", "*", "/", "&", "|", "<", ">", "=",
                 "~"]

  
  
  def get_while(p, [h|rest]) do
    if p.(h) do
      {succeeds, remainder} = get_while(p, rest)
    end
  end

  def split_lines(lines) do
    Enum.reduce(lines, &(&2 <> " " <> &1))
    |> String.split
  end

  def remove_comments(words), do: remove_comments(words, 0)
  
  def remove_comments(["/*" <> _llo | rest], level) do
    remove_comments(rest, level + 1)
  end

  def remove_comments([end_comment | rest], level)
  when binary_part(end_comment, byte_size(end_comment)-2, 2) == "*/" do
    remove_comments(rest, level - 1)
  end

  def remove_comments([_|rest], level) when level > 0 do
    remove_comments(rest, level)
  end

  def remove_comments([f|rest], level) when level == 0 do
    [f] ++ remove_comments(rest, level)
  end

  def remove_comments([], 0), do: []

  def split_word(word, delim) do
    String.split(word, delim)
    |> Enum.intersperse(delim)
    |> Enum.filter(&(&1 != ""))
  end

  def split_words_on(words, delim) do
    Enum.map(words, &split_word(&1, delim))
    |> List.flatten
  end

  def split_all_words(words, [delim | rest]) do
    split_words_on(words, delim)
    |> split_all_words(rest)
  end

  def split_all_words(words, []), do: words
  
  def tokenize(lines) do
    split_lines(lines)
    |> remove_comments()
    |> split_all_words(@jack_symbols)
  end

  def xml_word(w) when w in @jack_symbols, do: "<symbol> #{w} </symbol>"
  def xml_word(w) when w in @jack_keywords, do: "<keyword> #{w} </keyword>"
  def xml_word(w), do: "<identifier> #{w} </identifier>"
  
  def tokenize_xml(lines) do
    ["<tokens>"] ++ Enum.map(tokenize(lines), &xml_word/1) ++ ["</tokens>"]
  end
  
end
