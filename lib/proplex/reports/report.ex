defmodule Proplex.Reports.Report do

  use Ecto.Schema
  import Ecto.Changeset

  @categories [:noise, :property_damage, :harassment, :safety, :other]

  schema "reports" do

    belongs_to :reporter, Proplex.Accounts.User, foreign_key: :reporter_id
    belongs_to :reported, Proplex.Accounts.User, foreign_key: :reported_id

    field :title, :string
    field :description, :string
    field :category, Ecto.Enum, values: @categories

    timestamps(type: :utc_datetime)

  end

  def categories, do: @categories

  def category_label(:noise), do: "Noise disturbance"
  def category_label(:property_damage), do: "Property damage"
  def category_label(:harassment), do: "Harassment"
  def category_label(:safety), do: "Safety concern"
  def category_label(:other), do: "Other"

  def category_options do
    for c <- @categories, do: {category_label(c), c}
  end

  def create_changeset(report, attrs) do
    report
    |> cast(attrs, [:reporter_id, :reported_id, :title, :description, :category])
    |> validate_required([:reporter_id, :reported_id, :title, :description, :category])
    |> validate_length(:title, min: 3, max: 120)
    |> validate_length(:description, min: 10, max: 2_000)
    |> validate_not_self_report()
    |> trim_text_fields([:title, :description])
    |> assoc_constraint(:reporter)
    |> assoc_constraint(:reported)
    |> unique_constraint([:reporter_id, :reported_id],
    name: :reports_reporter_id_reported_id_index,
    message: "you have already reported this user")
    |> check_constraint(:reported_id,
    name: :no_self_report,
    message: "you cannot report yourself")
  end

  defp validate_not_self_report(changeset) do
    reporter_id = get_field(changeset, :reporter_id)
    reported_id = get_field(changeset, :reported_id)

    cond do
      is_nil(reporter_id) or is_nil(reported_id) ->
        changeset

      reporter_id == reported_id ->
        add_error(changeset, :reported_id, "you cannot report yourself")

      true ->
        changeset
    end

  end

  defp trim_text_fields(changeset, fields) do
    Enum.reduce(fields, changeset, fn field, acc ->
      update_change(acc, field, fn
        value when is_binary(value) ->
          case String.trim(value) do
            ""-> nil
            trimmed -> trimmed
          end

          other ->
            other
        end
        )
    end)
  end
end
