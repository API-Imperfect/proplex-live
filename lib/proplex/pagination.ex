defmodule Proplex.Pagination do
  import Ecto.Query

  alias Proplex.Repo

  @default_limit 20
  @max_limit 100

  @default_cursor_fields [:inserted_at, :id]

  defmodule Page do
    @type t :: %__MODULE__{rows: list(), next_cursor: binary() | nil}
    defstruct [:rows, :next_cursor]
  end

  @spec paginate(Ecto.Queryable.t(), keyword()) :: Page.t()
  def paginate(query, opts \\ []) do
    limit = opts |> Keyword.get(:limit, @default_limit) |> clamp_limit()
    cursor = Keyword.get(opts, :cursor)
    order = opts |> Keyword.get(:cursor_fields, @default_cursor_fields) |> normalize_order()

    fields = Enum.map(order, fn {_dir, field} -> field end)

    extractor =
      Keyword.get(opts, :cursor_extractor, fn row ->
        Enum.map(fields, &Map.fetch!(row, &1))
      end)

    rows =
      query
      |> apply_cursor_where(cursor, order)
      |> apply_order_by(order)
      |> limit(^(limit + 1))
      |> Repo.all()

    build_page(rows, limit, extractor)
  end

  defp normalize_order([]), do: raise(ArgumentError, ":cursor_fields must not be empty")

  defp normalize_order(fields) when is_list(fields) do
    Enum.map(fields, fn
      {dir, field} when dir in [:asc, :desc] and is_atom(field) -> {dir, field}
      field when is_atom(field) -> {:desc, field}
      other -> raise ArgumentError, "invalid entry in :cursor_fields: #{inspect(other)}"
    end)
  end

  @spec encode_cursor(list()) :: binary()
  def encode_cursor(values) when is_list(values) do
    values
    |> :erlang.term_to_binary()
    |> Base.url_encode64(padding: false)
  end

  @spec decode_cursor(binary() | nil) :: list() | nil
  def decode_cursor(nil), do: nil
  def decode_cursor(""), do: nil

  def decode_cursor(cursor) when is_binary(cursor) do
    with {:ok, binary} <- Base.url_decode64(cursor, padding: false),
         values when is_list(values) <- safe_binary_to_term(binary) do
      values
    else
      _ -> nil
    end
  end

  defp safe_binary_to_term(binary) do
    try do
      value = :erlang.binary_to_term(binary, [:safe])

      if is_list(value), do: value, else: nil
    rescue
      _ -> nil
    end
  end

  defp clamp_limit(limit) when is_integer(limit), do: limit |> max(1) |> min(@max_limit)
  defp clamp_limit(_limit), do: @default_limit

  defp apply_cursor_where(query, cursor, order) when is_binary(cursor) do
    fields = Enum.map(order, fn {_dir, field} -> field end)

    with values when is_list(values) <- decode_cursor(cursor),
         true <- length(values) == length(order),
         {:ok, values} <- cast_cursor_values(query, fields, values) do
      from q in query, where: ^keyset_condition(order, values)
    else
      _ -> query
    end
  end

  defp apply_cursor_where(query, _cursor, _fields), do: query

  defp cast_cursor_values(query, fields, values) do
    schema =
      case Ecto.Queryable.to_query(query) do
        %Ecto.Query{from: %{source: {_table, schema}}} when is_atom(schema) -> schema
        _ -> nil
      end

    fields
    |> Enum.zip(values)
    |> Enum.reduce_while({:ok, []}, fn {field, value}, {:ok, acc} ->
      case cast_cursor_value(schema, field, value) do
        {:ok, cast} -> {:cont, {:ok, [cast | acc]}}
        :error -> {:halt, :error}
      end
    end)
    |> case do
      {:ok, cast_values} -> {:ok, Enum.reverse(cast_values)}
      :error -> :error
    end
  end

  defp cast_cursor_value(_schema, _field, nil), do: :error

  # Schemaless source: there are no field types to check against.
  defp cast_cursor_value(nil, _field, value), do: {:ok, value}

  defp cast_cursor_value(schema, field, value) do
    case schema.__schema__(:type, field) do
      nil ->
        :error

      type ->
        case Ecto.Type.cast(type, value) do
          {:ok, nil} -> :error
          {:ok, cast} -> {:ok, cast}
          _ -> :error
        end
    end
  end

  defp keyset_condition([{dir, field}], [value]), do: after_value(dir, field, value)

  defp keyset_condition([{dir, field} | order], [value | values]) do
    rest = keyset_condition(order, values)

    dynamic([q], ^after_value(dir, field, value) or (field(q, ^field) == ^value and ^rest))
  end

  defp after_value(:asc, field, value), do: dynamic([q], field(q, ^field) > ^value)

  defp after_value(:desc, field, value), do: dynamic([q], field(q, ^field) < ^value)

  defp apply_order_by(query, order) do
    query
    |> exclude(:order_by)
    |> order_by(^order)
  end

  defp build_page(rows, limit, _extractor) when length(rows) <= limit do
    %Page{rows: rows, next_cursor: nil}
  end

  defp build_page(rows, limit, extractor) do
    visible = Enum.take(rows, limit)

    last_visible = List.last(visible)
    next_cursor = last_visible |> extractor.() |> encode_cursor()
    %Page{rows: visible, next_cursor: next_cursor}
  end
end
