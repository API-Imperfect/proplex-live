defmodule Proplex.Issues.Issue do
  use Ecto.Schema

  import Ecto.Changeset

  schema "issues" do
    field :title, :string
    field :description, :string
    field :priority, Ecto.Enum, values: [:low, :medium, :high]
    field :status, Ecto.Enum, values: [:reported, :in_progress, :resolved], default: :reported
    field :resolved_on, :date
    field :deleted_at, :utc_datetime

    belongs_to :reporter, Proplex.Accounts.User, foreign_key: :reporter_id
    belongs_to :apartment, Proplex.Apartments.Apartment
    belongs_to :assigned_technician, Proplex.Accounts.User, foreign_key: :assigned_technician_id

    timestamps(type: :utc_datetime)
  end

  def deleted?(%__MODULE__{deleted_at: nil}), do: false
  def deleted?(%__MODULE__{deleted_at: _}), do: true
  def resolved?(%__MODULE__{status: :resolved}), do: true
  def resolved?(%__MODULE__{}), do: false

  def assigned?(%__MODULE__{assigned_technician_id: nil}), do: false
  def assigned?(%__MODULE__{assigned_technician_id: _}), do: true

  def report_changeset(issue, attrs) do
    issue
    |> cast(attrs, [:title, :description, :priority, :reporter_id, :apartment_id])
    |> validate_required([:title, :description, :priority, :reporter_id, :apartment_id])
    |> validate_length(:title, min: 3, max: 120)
    |> validate_length(:description, min: 10, max: 2_000)
    |> trim_text_fields([:title, :description])
    |> assoc_constraint(:reporter)
    |> assoc_constraint(:apartment)
  end

  def assign_changeset(issue, attrs) do
    issue
    |> cast(attrs, [:assigned_technician_id])
    |> validate_required([:assigned_technician_id])
    |> assoc_constraint(:assigned_technician)
  end

  def start_progress_changeset(%__MODULE__{status: :reported} = issue) do
    change(issue, status: :in_progress)
  end

  def resolve_changeset(%__MODULE__{status: :in_progress} = issue) do
    change(issue, status: :resolved, resolved_on: Date.utc_today())
  end

  def soft_delete_changeset(%__MODULE__{} = issue) do
    change(issue, deleted_at: DateTime.utc_now() |> DateTime.truncate(:second))
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
