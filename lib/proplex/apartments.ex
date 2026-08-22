defmodule Proplex.Apartments do
  import Ecto.Query
  require Logger
  alias Proplex.Repo

  alias Proplex.Apartments.{Apartment, PendingTenancy, Tenancy}

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

  @spec archive_apartment(%Proplex.Apartments.Apartment{:id => any(), optional(any()) => any()}) ::
          any()
  def archive_apartment(%Apartment{} = apartment) do
    cond do
      get_active_tenancy_for_apartment(apartment) != nil ->
        {:error, :active_tenancy_exists}

      list_pending_tenancies_for_apartment(apartment) != [] ->
        {:error, :pending_tenancy_exists}

      true ->
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

  def list_eligible_tenants do
    active_tenant_ids_query =
      from t in Tenancy,
        where: is_nil(t.end_date),
        select: t.user_id

    from(u in Proplex.Accounts.User,
      join: ur in Proplex.Authorization.UserRole,
      on: ur.user_id == u.id,
      join: r in assoc(ur, :role),
      where: r.name == "tenant",
      where: u.id not in subquery(active_tenant_ids_query),
      order_by: u.username,
      distinct: true
    )
    |> Repo.all()
  end

  def archive_apartment(%Apartment{} = apartment) do
    cond do
      get_active_tenancy_for_apartment(apartment) != nil ->
        {:error, :active_tenancy_exists}

      list_pending_tenancies_for_apartment(apartment) != [] ->
        {:error, :pending_tenancy_exists}

      true ->
        result =
          apartment
          |> Ecto.Changeset.change(
            archived_at: Datetime.utc_now() |> Datetime.truncate(:second)
          )
          |> Repo.update()

      case result do
        {:ok, archived} ->
          Logger.warning("Apartment archived",
          event: :apartment_archived,
          apartment_id: archived.id,
          building_name: archived.building_name,
          unit_number: archived.unit_number)
      {:ok, archived}

      other ->
        other
      end
    end
  end


  def list_building_names do
    Repo.all(
      from a in Apartment,
        distinct: true,
        select: a.building_name,
        order_by: a.building_name
    )
  end

  @pending_tenancy_token_validity_days 7

  def create_pending_tenancy(attrs) do
    {raw_token, token_hash, expires_at} = generate_invite_credentials()

    attrs =
      attrs
      |> normalize_attrs()
      |> Map.put("token_hash", token_hash)
      |> Map.put("expires_at", expires_at)

    result =
      %PendingTenancy{}
      |> PendingTenancy.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, pending} ->
        Logger.info("Pending tenancy created",
        event: :pending_tenancy_created,
        pending_tenancy_id: pending.id,
        apartment_id: pending.apartment_id,
        invite_email: pending.invite_email,
        start_date: Date.to_iso8601(pending.start_date))

      enqueue_invite_email(pending.id, raw_token)
      {:ok, pending, raw_token}

      other ->
        other
    end
  end

  def get_pending_tenancy_by_token(raw_token) when is_binary(raw_token) do
    token_hash = :crypto.hash(:sha256, raw_token)
    now = DateTime.utc_now(:second)

    Repo.one(
      from p in PendingTenancy,
      where: p.token_hash == ^token_hash and p.expires_at > ^now,
      preload: [:apartment]
    )
  end

  def get_pending_tenancy_by_token(_), do: nil

  def get_pending_tenancy!(id), do: Repo.get!(PendingTenancy, id)

  def list_pending_tenancies_for_apartment(%Apartment{id: apartment_id}) do
    Repo.all(
      from p in PendingTenancy,
       where: p.apartment_id == ^apartment_id,
       order_by: [desc: p.inserted_at]
    )
  end

  def cancel_pending_tenancy(%PendingTenancy{} = pending) do
    case Repo.delete(pending) do
      {:ok, deleted} ->
        Logger.warning("Pending tenancy cancelled",
        event: :pending_tenancy_cancelled,
        pending_tenancy_id: deleted.id,
        apartment_id: deleted.apartment_id,
        invite_email: deleted.invite_email)

        {:ok, deleted}

     other ->
      other
    end
  end

  def regenerate_pending_tenancy_token(%PendingTenancy{} = pending) do
    {raw_token, token_hash, expires_at} = generate_invite_credentials()

    result =
      pending
      |> PendingTenancy.regenerate_token_changeset(
        %{token_hash: token_hash,
      expires_at: expires_at}
      )
      |> Repo.update()

    case result do
      {:ok, updated} ->
        Logger.info("Pending tenancy token regenerated",
        event: :pending_tenancy_resent,
        pending_tenancy_id: updated.id,
        apartment_id: updated.apartment_id,
        invite_email: updated.invite_email)

        enqueue_invite_email(updated.id, raw_token)

        {:ok, updated, raw_token}

    other ->
      other
    end
  end

  def consume_pending_tenancy(%PendingTenancy{} = pending, user) do
    tenancy_changeset =
      Tenancy.create_changeset(%Tenancy{}, %{
        user_id: user.id,
        apartment_id: pending.apartment_id,
        start_date: pending.start_date
      })

    result =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:tenancy, tenancy_changeset)
      |> Ecto.Multi.delete(:pending_tenancy, pending)
      |> Repo.transaction()

    case result do
      {:ok, %{tenancy: tenancy}} ->
        Logger.info("Pending tenancy consumed",
        event: :pending_tenancy_consumed,
        pending_tenancy_id: pending.id,
        tenancy_id: tenancy.id,
        user_id: user.id,
        apartment_id: tenancy.apartment_id,
        start_date: Date.to_iso8601(tenancy.start_date))

      {:ok, tenancy}

      {:error, :tenancy, changeset, _changes} ->
        {:error, changeset}

{:error, step, value, _changes} ->

   Logger.warning("Pending tenancy consume failed",
        event: :pending_tenancy_consume_failed,
        pending_tenancy_id: pending.id,
        failed_step: step,
        failed_value: inspect(value))

    {:error, {step, value}}

    end
  end

  defp generate_invite_credentials do
    raw_token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    token_hash = :crypto.hash(:sha256, raw_token)

    expires_at =
      DateTime.utc_now(:second)
      |> DateTime.add(@pending_tenancy_token_validity_days, :day)

      {raw_token, token_hash, expires_at}
  end

  defp normalize_attrs(attrs) when is_map(attrs) do
    Map.new(attrs, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} -> {k, v}
    end)
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

  defp enqueue_invite_email(pending_tenancy_id, raw_token) do
    %{pending_tenancy_id: pending_tenancy_id, raw_token: raw_token}
    |> Proplex.Workers.PendingTenancyInviteEmail.new()
    |> Oban.insert()

  end


end
