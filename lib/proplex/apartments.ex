defmodule Proplex.Apartments do
  import Ecto.Query
  require Logger
  alias Proplex.Repo

  alias Proplex.Apartments.{Apartment, Tenancy}

  def list_apartments(opts \\ []) do
    include_archived? = Keyword.get(opts, :include_archived, false)

    query =
      from a in Apartment,
        order_by: [asc: a.building_name, asc: a.unit_number]

    query =
      if include_archived? do
        query
      else
        from a in query, where: is_nil(a.archived_at)
      end

    Repo.all(query)
  end

  def get_apartment(id), do: Repo.get(Apartment, id)

  def get_apartment!(id), do: Repo.get!(Apartment, id)

  def create_apartment(attrs \\ %{}) do
    result =
      %Apartment{}
      |> Apartment.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, apartment} ->
        Logger.info("Apartment created",
          event: :apartment_created,
          apartment_id: apartment.id,
          building_name: apartment.building_name,
          unit_number: apartment.unit_number,
          floor: apartment.floor
        )

        {:ok, apartment}

      other ->
        other
    end
  end

  def update_apartment(%Apartment{} = apartment, attrs) do
    result =
      apartment
      |> Apartment.changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, updated} ->
        Logger.info("Apartment updated",
          event: :apartment_updated,
          apartment_id: updated.id,
          building_name: updated.building_name,
          unit_number: updated.unit_number,
          floor: updated.floor
        )

        {:ok, updated}

      other ->
        other
    end
  end

  def archive_apartment(%Apartment{} = apartment) do
    case get_active_tenancy_for_apartment(apartment) do
      nil ->
        result =
          apartment
          |> Ecto.Changeset.change(archived_at: DateTime.utc_now() |> DateTime.truncate(:second))
          |> Repo.update()

        case result do
          {:ok, archived} ->
            Logger.warning("Apartment archived",
              event: :apartment_archived,
              apartment_id: archived.id,
              building_name: archived.building_name,
              unit_number: archived.unit_number
            )

            {:ok, archived}

          other ->
            other
        end

      _tenancy ->
        {:error, :active_tenancy_exists}
    end
  end

  def unarchive_apartment(%Apartment{archived_at: nil} = apartment) do
    {:ok, apartment}
  end

  def unarchive_apartment(%Apartment{} = apartment) do
    result =
      apartment
      |> Ecto.Changeset.change(archived_at: nil)
      |> Repo.update()

    case result do
      {:ok, unarchived} ->
        Logger.info("Apartment unarchived",
          event: :apartment_unarchived,
          apartment_id: unarchived.id,
          building_name: unarchived.building_name,
          unit_number: unarchived.unit_number
        )

        {:ok, unarchived}

      other ->
        other
    end
  end

  def change_apartment(%Apartment{} = apartment, attrs \\ %{}) do
    Apartment.changeset(apartment, attrs)
  end

  def start_tenancy(attrs \\ %{}) do
    apartment_id = attrs[:apartment_id] || attrs["apartment_id"]

    apartment = apartment_id && get_apartment(apartment_id)

    if apartment && apartment.archived_at do
      {:error, :apartment_archived}
    else
      result =
        %Tenancy{}
        |> Tenancy.create_changeset(attrs)
        |> Repo.insert()

      case result do
        {:ok, tenancy} ->
          Logger.info("Tenancy started",
            event: :tenancy_started,
            tenancy_id: tenancy.id,
            user_id: tenancy.user_id,
            apartment_id: tenancy.apartment_id,
            start_date: Date.to_iso8601(tenancy.start_date)
          )

          {:ok, tenancy}

        other ->
          other
      end
    end
  end

  def end_tenancy(%Tenancy{} = tenancy, %Date{} = end_date) do
    result =
      tenancy
      |> Tenancy.end_changeset(%{end_date: end_date})
      |> Repo.update()

    case result do
      {:ok, updated} ->
        Logger.info("Tenancy ended",
          event: :tenancy_ended,
          tenancy_id: updated.id,
          user_id: updated.user_id,
          apartment_id: updated.apartment_id,
          start_date: Date.to_iso8601(updated.start_date),
          end_date: Date.to_iso8601(updated.end_date)
        )

        {:ok, updated}

      other ->
        other
    end
  end

  def get_current_apartment_for_user(%{id: user_id}) do
    Repo.one(
      from t in Tenancy,
        join: a in assoc(t, :apartment),
        where: t.user_id == ^user_id and is_nil(t.end_date),
        select: a
    )
  end

  def get_active_tenancy_for_user(%{id: user_id}) do
    Repo.one(
      from t in Tenancy,
        where: t.user_id == ^user_id and is_nil(t.end_date),
        preload: [:apartment]
    )
  end

  def get_active_tenancy_for_apartment(%Apartment{id: apartment_id}) do
    Repo.one(
      from t in Tenancy,
        where: t.apartment_id == ^apartment_id and is_nil(t.end_date)
    )
  end

  def list_tenancies_for_user(%{id: user_id}) do
    Repo.all(
      from t in Tenancy,
        where: t.user_id == ^user_id,
        order_by: [desc: t.start_date],
        preload: [:apartment]
    )
  end

  def list_tenancies_for_apartment(%Apartment{id: apartment_id}) do
    Repo.all(
      from t in Tenancy,
        where: t.apartment_id == ^apartment_id,
        order_by: [desc: t.start_date],
        preload: [:user]
    )
  end

  def list_apartments_with_current_tenant(opts \\ []) do
    query =
      from(a in Apartment,
        left_join: t in assoc(a, :tenancies),
        on: t.apartment_id == a.id and is_nil(t.end_date),
        left_join: u in assoc(t, :user),
        order_by: [asc: a.building_name, asc: a.unit_number],
        select: %{apartment: a, current_tenant: u}
      )

    query
    |> maybe_filter_archived(Keyword.get(opts, :include_archived, true))
    |> maybe_filter_building(Keyword.get(opts, :building_name))
    |> maybe_filter_occupancy(Keyword.get(opts, :occupancy, :all))
    |> Repo.all()
  end

  def list_building_names do
    Repo.all(
      from a in Apartment,
        distinct: true,
        select: a.building_name,
        order_by: a.building_name
    )
  end

  defp maybe_filter_archived(query, true), do: query

  defp maybe_filter_archived(query, false) do
    from [a, _t, _u] in query, where: is_nil(a.archived_at)
  end

  defp maybe_filter_building(query, nil), do: query

  defp maybe_filter_building(query, name) when is_binary(name) and name != "" do
    from [a, _t, _u] in query, where: a.building_name == ^name
  end

  defp maybe_filter_building(query, _), do: query

  defp maybe_filter_occupancy(query, :all), do: query

  defp maybe_filter_occupancy(query, :vacant) do
    from [_a, t, _u] in query, where: is_nil(t.id)
  end

  defp maybe_filter_occupancy(query, :occupied) do
    from [_a, t, _u] in query, where: not is_nil(t.id)
  end
end
