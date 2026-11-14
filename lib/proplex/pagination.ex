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
    cursor_fields = Keyword.get(opts, :cursor_fields, @default_cursor_fields)

    if cursor_fields == [] or not Enum.all?(cursor_fields, &is_atom/1) do
      raise ArgumentError,
            ":cursor_fields must be a non-empty list of atoms, got: #{inspect(cursor_fields)}"
    end

    extractor =
      Keyword.get(opts, :cursor_extractor, fn row ->
        Enum.map(cursor_fields, &Map.fetch!(row, &1))
      end)

    rows =
      query
      |> apply_cursor_where(cursor, cursor_fields)
      |> apply_order_by(cursor_fields)
      |> limit(^(limit + 1))
      |> Repo.all()

    build_page(rows, limit, extractor)
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

  # Values from 1 to @max_limit are used as-is; out-of-range integers are
  # clamped, and anything that isn't an integer falls back to the default.
  defp clamp_limit(limit) when is_integer(limit), do: limit |> max(1) |> min(@max_limit)
  defp clamp_limit(_limit), do: @default_limit

  # Any cursor that is missing, malformed, or tampered with is ignored and
  # the first page is returned, rather than raising inside Repo.all/1.
  defp apply_cursor_where(query, cursor, fields) when is_binary(cursor) do
    with values when is_list(values) <- decode_cursor(cursor),
         true <- length(values) == length(fields),
         {:ok, values} <- cast_cursor_values(query, fields, values) do
      from q in query, where: ^keyset_condition(fields, values)
    else
      _ -> query
    end
  end

  defp apply_cursor_where(query, _cursor, _fields), do: query

  # Cast each cursor value to the type of its field on the query's source
  # schema, so a value of the wrong type is rejected here instead of raising
  # Ecto.Query.CastError when the query runs. nil is rejected because Ecto
  # does not allow comparisons with nil.
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

  # Keyset condition for a DESC ordering over any number of fields:
  #   f1 < v1 OR (f1 = v1 AND (f2 < v2 OR (f2 = v2 AND ...)))
  defp keyset_condition([field], [value]) do
    dynamic([q], field(q, ^field) < ^value)
  end

  defp keyset_condition([field | fields], [value | values]) do
    rest = keyset_condition(fields, values)

    dynamic([q], field(q, ^field) < ^value or (field(q, ^field) == ^value and ^rest))
  end

  defp apply_order_by(query, cursor_fields) do
    order = Enum.map(cursor_fields, fn f -> {:desc, f} end)

    query
      |> Ecto.Query.exclude(:order_by)
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
