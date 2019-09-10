defmodule Engine.View.Macro do
  @moduledoc """
  Imported into views
  """

  @doc """
  Creates ~E which runs through EEx templating
  """
  defmacro sigil_E({:<<>>, _, [expr]}, _opts) do
    EEx.compile_string(expr, line: __CALLER__.line + 1, engine: Engine.View.EExEngine, trim: true)
  end

  @doc """
  Creates ~i to create IO lists that look like standard interpolation
  """
  defmacro sigil_i({:<<>>, _, text}, _) do
    Enum.map(text, &sigil_i_unwrap/1)
  end

  defp sigil_i_unwrap({:"::", _, interpolation}) do
    [text | _] = interpolation
    {_, _, text} = text
    text
  end

  defp sigil_i_unwrap(text) when is_binary(text) do
    :elixir_interpolation.unescape_chars(text)
  end
end

defmodule Engine.View.EExEngine do
  @moduledoc """
  An EEx Engine that returns IO data instead of a string

  Taken from [Phoenix.HTML.Engine](https://github.com/phoenixframework/phoenix_html/blob/master/lib/phoenix_html/engine.ex)
  """

  @behaviour EEx.Engine

  @impl true
  def init(_opts) do
    %{
      iodata: [],
      dynamic: [],
      vars_count: 0
    }
  end

  @impl true
  def handle_begin(state) do
    %{state | iodata: [], dynamic: []}
  end

  @impl true
  def handle_end(quoted) do
    handle_body(quoted)
  end

  @impl true
  def handle_body(state) do
    %{iodata: iodata, dynamic: dynamic} = state
    iodata = Enum.reverse(iodata)
    {:__block__, [], Enum.reverse([iodata | dynamic])}
  end

  @impl true
  def handle_text(state, text) do
    %{iodata: iodata} = state
    %{state | iodata: [text | iodata]}
  end

  @impl true
  def handle_expr(state, "=", ast) do
    ast = Macro.prewalk(ast, &EEx.Engine.handle_assign/1)
    %{iodata: iodata, dynamic: dynamic, vars_count: vars_count} = state
    var = Macro.var(:"arg#{vars_count}", __MODULE__)
    ast = quote do: unquote(var) = unquote(ast)
    %{state | dynamic: [ast | dynamic], iodata: [var | iodata], vars_count: vars_count + 1}
  end

  def handle_expr(state, "", ast) do
    ast = Macro.prewalk(ast, &EEx.Engine.handle_assign/1)
    %{dynamic: dynamic} = state
    %{state | dynamic: [ast | dynamic]}
  end

  def handle_expr(state, marker, ast) do
    EEx.Engine.handle_expr(state, marker, ast)
  end
end

defmodule View do
  import Engine.View.Macro

  def render("iodata", %{name: name}) do
    ~i(Hello, #{name})
  end

  def render("string", %{name: name}) do
    ~s(Hello, #{name})
  end

  def render("iodata-long", %{character: character}) do
    ~E"""
    <%= character.name %>
        -----
          HP: <%= character.hp %>/<%= character.maxhp %>
    SP: <%= character.sp %>/<%= character.maxsp %>
    EP: <%= character.ep %>/<%= character.maxep %>
    Items:
    -------
      <%= Enum.map(character.items, &render("item-io", &1)) %>
    """
  end

  def render("item-io", %{name: name}) do
    ~i(- #{name})
  end

  def render("string-long", %{character: character}) do
    """
    #{character.name}
    -----
    HP: #{character.hp}/#{character.maxhp}
    SP: #{character.sp}/#{character.maxsp}
    EP: #{character.ep}/#{character.maxep}
    Items:
    -------
    #{Enum.map(character.items, &render("item-string", &1))}
    """
  end

  def render("item-string", %{name: name}) do
    ~s(- #{name})
  end
end

character = %{
 name: "Eric",
 hp: 50,
 maxhp: 50,
 sp: 35,
 maxsp: 35,
 ep: 22,
 maxep: 25,
 items: [
   %{name: "Potion"},
   %{name: "Sword"}
 ]
}

#Benchee.run(
#  %{
#    "iodata" => fn -> View.render("iodata", %{name: "Eric"}) end,
#    "string" => fn -> View.render("string", %{name: "Eric"}) end
#  },
#  formatters: [Benchee.Formatters.HTML]
#)


Benchee.run(
  %{
    "iodata" => fn -> View.render("iodata-long", %{character: character}) end,
    "string" => fn -> View.render("string-long", %{character: character}) end,
  },
  formatters: [Benchee.Formatters.HTML]
)
