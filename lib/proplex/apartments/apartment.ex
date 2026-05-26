defmodule Proplex.Apartments.Apartment do
  use Ecto.Schema
  import Ecto.Changeset

  @unit_number_regex ~r/^[A-Za-z0-9\-]+$/
  @floor_regex ~r/^[A-Za-z0-9\s\-]+$/

  schema "apartments" do
    field :building_name, :string
    field :unit_number, :string
    field :floor, :string

    field :archived_at, :utc_datetime

    has_many :tenancies, Proplex.Apartments.Tenancy

    timestamps(type: :utc_datetime)
  end

  def archived?(%__MODULE__{archived_at: nil}), do: false

  def archived?(%__MODULE__{archived_at: _}), do: true

  def changeset(apartment, attrs) do
    apartment
    |> cast(attrs, [:building_name, :unit_number, :floor])
    |> validate_required([:building_name, :unit_number, :floor])
    |> trim_text_fields([:building_name, :unit_number, :floor])
    |> validate_length(:building_name, min: 1, max: 80)
    |> validate_length(:unit_number, min: 1, max: 20)
    |> validate_length(:floor, min: 1, max: 30)
    |> validate_format(:unit_number, @unit_number_regex,
      message: "must contain only letters, numbers and hyphens"
    )
    |> validate_format(:floor, @floor_regex,
      message: "must contain only letters, numbers,spaces and hyphens"
    )
    |> unique_constraint([:building_name, :unit_number],
      name: :apartments_building_name_unit_number_index,
      message: "this unit has already been registered in this building"
    )
  end

  defp trim_text_fields(changeset, fields) do
    Enum.reduce(fields, changeset, fn field, acc ->
      update_change(acc, field, fn
        value when is_binary(value) ->
          case String.trim(value) do
            "" -> nil
            trimmed -> trimmed
          end

        other ->
          other
      end)
    end)
  end
end
