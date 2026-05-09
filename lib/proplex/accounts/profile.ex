defmodule Proplex.Accounts.Profile do
  use Ecto.Schema
  import Ecto.Changeset

  schema "profiles" do
    belongs_to :user, Proplex.Accounts.User

    field :first_name, :string
    field :middle_name, :string
    field :last_name, :string

    field :gender, Ecto.Enum, values: [:male, :female, :prefer_not_to_say]

    field :occupation, Ecto.Enum,
      values: [
        :none,
        :mason,
        :carpenter,
        :plumber,
        :roofer,
        :painter,
        :electrician,
        :hvac_technician
      ],
      default: :none

    field :bio, :string
    field :phone_number, :string
    field :country, :string
    field :city, :string
    field :avatar_url, :string
    field :reputation, :integer, default: 100
    field :average_rating, :float, default: 0.0
    field :report_count, :integer, default: 0

    timestamps(type: :utc_datetime)
  end

  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [
      :first_name,
      :middle_name,
      :last_name,
      :gender,
      :occupation,
      :bio,
      :phone_number,
      :country,
      :city,
      :avatar_url
    ])
    |> validate_length(:first_name, max: 80)
    |> validate_length(:middle_name, max: 80)
    |> validate_length(:last_name, max: 80)
    |> validate_length(:bio, max: 500)
    |> validate_length(:phone_number, max: 30)
    |> validate_length(:country, max: 80)
    |> validate_length(:city, max: 80)
  end

  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:user_id])
    |> validate_required([:user_id])
  end
end
