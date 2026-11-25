defmodule ProplexWeb.ReportLive.New do
  use ProplexWeb, :live_view

  alias Proplex.Reports
  alias Proplex.Reports.Report

  @title_min 3
  @title_max 120
  @description_min 10
  @description_max 2_000

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-xl">
        <div class="relative rounded-box border border-base-300 bg-base-200 px-6 pb-8 pt-12 sm:px-10 sm:pb-10">
          <div class="absolute -top-7 left-1/2 inline-flex size-14 -translate-x-1/2 items-center justify-center rounded-full bg-warning/10 ring-4 ring-base-100">
            <.icon name="hero-flag" class="size-9 text-warning" />
          </div>

          <div class="mb-6 text-center">
            <h1 class="text-2xl font-semibold tracking-tight">Report a tenant</h1>
            <p class="mt-2 text-sm text-base-content/70">
              Flag misconduct so your landlord can review. Keep it factual — admins see every report, and repeated filings against the same person are tracked.
            </p>
          </div>

          <%= case @state do %>
            <% :no_apartment -> %>
              <div class="rounded-box bg-base-100 px-6 py-8 text-center">
                <.icon name="hero-building-office-2" class="size-12 text-base-content/40" />
                <p class="mt-4 font-medium">You don't have an active apartment.</p>
                <p class="mt-2 text-sm text-base-content/70">
                  You can only file reports about neighbors in your own building, so you'll need an active tenancy first. Please contact your landlord.
                </p>
                <.link navigate={~p"/users/my-apartment"} class="btn btn-outline btn-sm mt-4">
                  Go to My Apartment
                </.link>
              </div>
            <% :no_neighbors -> %>
              <div class="mb-6 rounded-box border border-base-300 bg-base-100 px-4 py-3 text-sm">
                <span class="text-base-content/60">Building:</span>
                <span class="font-medium">{@reporter_apartment.building_name}</span>
              </div>
              <div class="rounded-box bg-base-100 px-6 py-8 text-center">
                <.icon name="hero-user-group" class="size-12 text-base-content/40" />
                <p class="mt-4 font-medium">No neighbors to report right now.</p>
                <p class="mt-2 text-sm text-base-content/70">
                  Either the rest of the building is vacant, or you've already filed against every other tenant here.
                </p>
                <.link navigate={~p"/reports"} class="btn btn-outline btn-sm mt-4">
                  Back to My Reports
                </.link>
              </div>
            <% :ready -> %>
              <div class="mb-6 rounded-box border border-base-300 bg-base-100 px-4 py-3 text-sm">
                <span class="text-base-content/60">Reporting in:</span>
                <span class="font-medium">{@reporter_apartment.building_name}</span>
              </div>

              <div class="mb-6 rounded-box border border-base-300 bg-base-100 px-4 py-3 text-xs text-base-content/70">
                Reports are confidential to admins. The reported tenant isn't shown who filed the report.
              </div>

              <.form
                for={@form}
                id="report_form"
                phx-change="validate"
                phx-submit="save"
                phx-debounce="400"
              >
                <.input
                  field={@form[:reported_apartment_id]}
                  type="select"
                  label="Which neighbor?"
                  prompt="Pick an apartment"
                  options={@neighbor_options}
                  required
                  phx-mounted={JS.focus()}
                />
                <p class="-mt-1 mb-3 text-xs text-base-content/60">
                  Only occupied apartments in {@reporter_apartment.building_name} are listed. Neighbors you've already reported are hidden.
                </p>

                <.input
                  field={@form[:category]}
                  type="select"
                  label="Category"
                  prompt="Choose one"
                  options={Report.category_options()}
                  required
                />
                <p class="-mt-1 mb-3 text-xs text-base-content/60">
                  Pick the best fit. Use "Other" only if nothing else applies.
                </p>

                <.input
                  field={@form[:title]}
                  type="text"
                  label="Title"
                  placeholder="e.g. Loud music past midnight on weekdays"
                  required
                />
                <p class="-mt-1 mb-3 text-xs text-base-content/60">
                  A short summary ({@title_min}–{@title_max} characters).
                </p>

                <.input
                  field={@form[:description]}
                  type="textarea"
                  label="Description"
                  placeholder="When did it happen? What did you observe? Anything you've already tried (e.g. asking them to stop)?"
                  required
                />
                <p class="-mt-1 mb-3 text-xs text-base-content/60">
                  Specific and factual ({@description_min}–{@description_max} characters). Avoid speculation.
                </p>

                <div class="mt-4 grid grid-cols-1 gap-2 sm:grid-cols-3">
                  <.link navigate={~p"/reports"} class="btn btn-outline w-full">
                    Cancel
                  </.link>
                  <.button
                    phx-disable-with="Filing..."
                    class="btn btn-primary w-full sm:col-span-2"
                  >
                    File report
                  </.button>
                </div>
              </.form>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    reporter = socket.assigns.current_scope.user

    case Reports.list_reportable_neighbors(reporter) do
      {:error, :no_active_apartment} ->
        {:ok,
         socket
         |> assign(:state, :no_apartment)
         |> assign(:reporter_apartment, nil)}

      {:ok, reporter_apt, []} ->
        {:ok,
         socket
         |> assign(:state, :no_neighbors)
         |> assign(:reporter_apartment, reporter_apt)}

      {:ok, reporter_apt, neighbors} ->
        {:ok,
         socket
         |> assign(:state, :ready)
         |> assign(:reporter_apartment, reporter_apt)
         |> assign(:neighbors, neighbors)
         |> assign(:neighbor_options, build_options(neighbors))
         |> assign(:title_min, @title_min)
         |> assign(:title_max, @title_max)
         |> assign(:description_min, @description_min)
         |> assign(:description_max, @description_max)
         |> assign_form(build_changeset(%{}))}
    end
  end

  @impl true
  def handle_event("validate", %{"report" => attrs}, socket) do
    changeset =
      attrs
      |> build_changeset()
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  @impl true
  def handle_event("save", %{"report" => attrs}, socket) do
    reporter = socket.assigns.current_scope.user
    form_changeset = build_changeset(attrs)

    if form_changeset.valid? do
      submit(socket, reporter, attrs, form_changeset)
    else
      {:noreply, assign_form(socket, Map.put(form_changeset, :action, :validate))}
    end
  end

  defp submit(socket, reporter, attrs, form_changeset) do
    apartment_id = parse_apartment_id(Map.get(attrs, "reported_apartment_id"))

    neighbor = Enum.find(socket.assigns.neighbors, &(&1.apartment_id == apartment_id))

    cond do
      is_nil(apartment_id) ->
        invalid_apartment(socket, form_changeset, "pick an apartment")

      is_nil(neighbor) ->
        refresh_and_flash(
          socket,
          reporter,
          "That apartment isn't available to report right now - the list has been refreshed."
        )

      true ->
        create_report(socket, reporter, neighbor, attrs, form_changeset)
    end
  end

  defp create_report(socket, reporter, neighbor, attrs, form_changeset) do
    report_attrs = %{
      "reported_id" => neighbor.user_id,
      "title" => Map.get(attrs, "title"),
      "description" => Map.get(attrs, "description"),
      "category" => Map.get(attrs, "category")
    }

    case Reports.create_report(reporter, report_attrs) do
      {:ok, _report, escalation} ->
        {:noreply,
         socket
         |> put_flash(:info, success_flash(escalation))
         |> push_navigate(to: ~p"/reports")}

      {:error, :rate_limited, retry_after_ms} ->
        {:noreply,
         socket
         |> put_flash(:error, rate_limit_flash(retry_after_ms))
         |> assign_form(form_changeset)}

      {:error, :not_reportable} ->
        refresh_and_flash(
          socket,
          reporter,
          "That tenant's account is no longer available - the list has been refreshed."
        )

      {:error, %Ecto.Changeset{} = report_changeset} ->
        merged =
          form_changeset
          |> copy_error(report_changeset, :title)
          |> copy_error(report_changeset, :description)
          |> copy_error(report_changeset, :category)
          |> copy_error(report_changeset, :reported_id, :reported_apartment_id)
          |> Map.put(:action, :validate)

        {:noreply, assign_form(socket, merged)}

      # Any other error (:no_active_apartment, :profile_not_found, ...).
      # Without this clause, an unexpected error would raise CaseClauseError.
      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "We couldn't file that report. Please try again.")
         |> assign_form(form_changeset)}
    end
  end

  defp refresh_and_flash(socket, reporter, message) do
    case Reports.list_reportable_neighbors(reporter) do
      {:ok, reporter_apt, neighbors} when neighbors != [] ->
        {:noreply,
         socket
         |> put_flash(:error, message)
         |> assign(:neighbors, neighbors)
         |> assign(:neighbor_options, build_options(neighbors))
         |> assign(:reporter_apartment, reporter_apt)
         |> assign_form(build_changeset(%{}))}

      _ ->
        {:noreply,
         socket
         |> put_flash(:error, message)
         |> push_navigate(to: ~p"/reports/new")}
    end
  end

  defp invalid_apartment(socket, form_changeset, message) do
    changeset =
      form_changeset
      |> Ecto.Changeset.add_error(:reported_apartment_id, message)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  defp build_changeset(attrs) do
    types = %{
      reported_apartment_id: :integer,
      category: Ecto.ParameterizedType.init(Ecto.Enum, values: Report.categories()),
      title: :string,
      description: :string
    }

    {%{}, types}
    |> Ecto.Changeset.cast(attrs, Map.keys(types))
    |> Ecto.Changeset.validate_required([
      :reported_apartment_id,
      :category,
      :title,
      :description
    ])
    |> Ecto.Changeset.validate_length(:title, min: @title_min, max: @title_max)
    |> Ecto.Changeset.validate_length(:description, min: @description_min, max: @description_max)
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, form: to_form(changeset, as: "report"))
  end

  defp parse_apartment_id(value) when is_integer(value), do: value

  defp parse_apartment_id(value) when is_binary(value) do
    case Integer.parse(value) do
      {id, ""} -> id
      _ -> nil
    end
  end

  defp parse_apartment_id(_), do: nil

  defp build_options(neighbors) do
    Enum.map(neighbors, fn row ->
      {option_label(row), row.apartment_id}
    end)
  end

  defp option_label(row) do
    "Unit #{row.unit_number} - #{display_name(row)}"
  end

  defp display_name(%{first_name: first, last_name: last})
       when is_binary(first) and is_binary(last) and first != "" and last != "" do
    "#{first} #{last}"
  end

  defp display_name(%{username: username}) when is_binary(username), do: "@#{username}"

  defp copy_error(target, source, source_field, target_field \\ nil) do
    target_field = target_field || source_field

    case source.errors[source_field] do
      nil -> target
      {msg, opts} -> Ecto.Changeset.add_error(target, target_field, msg, opts)
    end
  end

  defp success_flash(:no_escalation), do: "Report filed."

  defp success_flash(:warning_triggered),
    do: "Report filed. The tenant will receive an advisory email."

  defp success_flash(:admin_review_triggered),
    do: "Report filed. This tenant has been flagged for admin review."

  defp rate_limit_flash(retry_after_ms) do
    retry_after = humanize_retry_after(retry_after_ms)
    "You've hit the weekly limit on report filings. Try again in #{retry_after}."
  end

  defp humanize_retry_after(ms) when is_integer(ms) and ms >= 0 do
    hours = div(ms, 3_600_000)
    days = div(hours, 24)

    cond do
      days >= 1 -> "#{days} #{pluralize(days, "day")}"
      hours >= 1 -> "#{hours} #{pluralize(hours, "hour")}"
      true -> "a few minutes"
    end
  end

  defp pluralize(1, word), do: word
  defp pluralize(_n, word), do: word <> "s"
end
