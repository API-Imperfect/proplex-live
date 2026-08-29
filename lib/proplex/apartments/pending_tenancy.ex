defmodule Proplex.Apartments.PendingTenancy do
  use Ecto.Schema
  import Ecto.Changeset

  schema "pending_tenancies" do

    field :invite_email, :string

    field :start_date, :date

    field :token_hash, :binary

    field :expires_at, :utc_datetime

    belongs_to :apartment, Proplex.Apartments.Apartment

    timestamps(type: :utc_datetime)
  end

  def changeset(pending, attrs) do
    pending
    |> cast(attrs, [:invite_email, :apartment_id, :start_date, :token_hash, :expires_at])
    |> trim_email()
    |> downcase_email()
    |> validate_required([:invite_email, :apartment_id, :start_date, :token_hash, :expires_at])
    |> validate_format(:invite_email, ~r/^[^@,;\s]+@[^@,;\s]+$/, message: "must be a valid email")
    |> validate_length(:invite_email, max: 160)
    |> unique_constraint(:apartment_id, message: "this apartment already has a pending invite")
    |> unique_constraint(:invite_email, message: "this email already has a pending invite")
    |> unique_constraint(:token_hash)
    |> assoc_constraint(:apartment)
  end

  def regenerate_token_changeset(pending,attrs) do
    pending
    |> cast(attrs, [:token_hash, :expires_at])
    |> validate_required([:token_hash, :expires_at])
    |> unique_constraint(:token_hash)
  end

  defp downcase_email(changeset) do
    case get_change(changeset, :invite_email) do
      email when is_binary(email) ->
        put_change(changeset, :invite_email, String.downcase((email)))

      _ ->
        changeset

    end
  end

  defp trim_email(changeset) do
    case get_change(changeset, :invite_email) do
      email when is_binary(email) ->
        put_change(changeset, :invite_email, String.trim(email))

      _ ->
        changeset
    end
  end
end
