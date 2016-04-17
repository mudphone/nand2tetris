defmodule SymbolTable do
  
  @class_types [:STATIC, :FIELD]
  @subroutine_types [:ARG, :VAR]

  defmodule VarInfo do
    defstruct name: nil, type: nil, kind: nil, index: 0
  end
  
  def create(class_table, subroutine_table) do
    %{ class: class_table,
       subroutine: subroutine_table }
  end
  
  def create(), do: create(%{}, %{})

  def class_table(t) do
    {:ok, ct} = Map.fetch(t, :class)
    ct
  end

  def subroutine_table(t) do
    {:ok, st} = Map.fetch(t, :subroutine)
    st
  end

  def start_subroutine(t) do
    class_table(t)
    |> create(%{})
  end

  def var_count(ct_or_st, kind) do
    Map.values(ct_or_st)
    |> Enum.filter(fn (%VarInfo{name: _, type: _, kind: k, index: _}) ->
      k == kind
    end)
    |> length()
  end

  def define(t, name, type, kind) when kind in @class_types do
    ct = class_table(t)
    cond do
      Map.has_key?(ct, name) ->
        t
      true ->
        create(define_var(ct, name, type, kind),
               subroutine_table(t))
    end
  end

  def define(t, name, type, kind) when kind in @subroutine_types do
    st = subroutine_table(t)
    cond do
      Map.has_key?(st, name) ->
        t
      true ->
        create(class_table(t),
               define_var(st, name, type, kind))
    end
  end
  
  def define_var(ct_or_st, name, type, kind) do
    i = var_count(ct_or_st, kind)
    v = %VarInfo{name: name, type: type, kind: kind, index: i}
    Map.put_new(ct_or_st, name, v)
  end

end
