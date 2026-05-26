defmodule Proplex.Apartments.Tenancy do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tenancies" do
    belongs_to :user, Proplex.Accounts.User
    belongs_to :apartment, Proplex.Apartments.Apartment

    field :start_date, :date
    field :end_date, :date

    timestamps(type: :utc_datetime)
  end

  def create_changeset(tenancy, attrs) do
    tenancy
    |> cast(attrs, [:user_id, :apartment_id, :start_date])
    |> validate_required([:user_id, :apartment_id, :start_date])
    |> assoc_constraint(:user)
    |> assoc_constraint(:apartment)
    |> unique_constraint(:apartment_id,
      name: :tenancies_active_apartment_index,
      message: "this apartment already has an active tenant"
    )
    |> unique_constraint(:user_id,
      name: :tenancies_active_user_index,
      message: "this user already has an active tenancy"
    )
  end

  def end_changeset(tenancy, attrs) do
    tenancy
    |> cast(attrs, [:end_date])
    |> validate_required([:end_date])
    |> validate_end_after_start()
  end

  defp validate_end_after_start(changeset) do
    start_date = get_field(changeset, :start_date)
    end_date = get_field(changeset, :end_date)

    cond do
      is_nil(start_date) or is_nil(end_date) ->
        changeset

      Date.compare(end_date, start_date) == :lt ->
        add_error(changeset, :end_date, "must be on or after the start date")

      true ->
        changeset
    end
  end
end
