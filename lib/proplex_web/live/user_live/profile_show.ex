defmodule ProplexWeb.UserLive.ProfileShow do
  use ProplexWeb, :live_view

  alias Proplex.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-2xl">
        <div class="relative rounded-box border border-base-300 bg-base-200 px-6 pb-8 pt-12 sm:px-10 sm:pb-10">
          <div class="absolute -top-12 left-1/2 inline-flex size-24 -translate-x-1/2 items-center justify-center rounded-full bg-primary/10 ring-4 ring-base-100">
            <%= if @user.profile.avatar_url do %>
              <img
                src={@user.profile.avatar_url}
                alt="Avatar"
                class="size-24 rounded-full object-cover"
              />
            <% else %>
              <.icon name="hero-user-circle" class="size-16 text-primary" />
            <% end %>
          </div>
          <div class="mt-4 text-center">
            <h1 class="text-2xl font-semibold tracking-tight">
              {display_name(@user)}
            </h1>
            <p class="mt-1 text-sm text-base-content/70">@{@user.username}</p>
          </div>

          <p :if={@user.profile.bio} class="mt-6 text-center text-base-content/80">
            {@user.profile.bio}
          </p>

          <div class="mt-6 grid grid-cols-3 gap-4 rounded-box border border-base-300 bg-base-100 p-4">
            <div class="text-center">
              <p class="text-2xl font-semibold">{@user.profile.reputation}</p>
              <p class="text-xs text-base-content/60">Reputation</p>
            </div>

            <div class="text-center">
              <p class="text-2xl font-semibold">{format_rating(@user.profile.average_rating)}</p>
              <p class="text-xs text-base-content/60">Avg. rating</p>
            </div>

            <div class="text-center">
              <p class="text-2xl font-semibold">{@user.profile.report_count}</p>
              <p class="text-xs text-base-content/60">Reports</p>
            </div>
          </div>

          <dl class="mt-6 space-y-3 text-sm">
            <div
              :if={@user.profile.gender}
              class="flex justify-between"
            >
              <dt class="text-base-content/60">Gender</dt>
              <dd class="font-medium">{format_gender(@user.profile.gender)}</dd>
            </div>

            <div
              :if={@user.profile.occupation && @user.profile.occupation != :none}
              class="flex justify-between"
            >
              <dt class="text-base-content/60">Occupation</dt>
              <dd class="font-medium">{format_occupation(@user.profile.occupation)}</dd>
            </div>

            <div
              :if={@user.profile.city || @user.profile.country}
              class="flex justify-between"
            >
              <dt class="text-base-content/60">Location</dt>
              <dd class="font-medium">{format_location(@user.profile)}</dd>
            </div>

            <div
              :if={@user.profile.phone_number}
              class="flex justify-between"
            >
              <dt class="text-base-content/60">Phone</dt>
              <dd class="font-medium">{@user.profile.phone_number}</dd>
            </div>

            <div class="flex justify-between">
              <dt class="text-base-content/60">Member since</dt>
              <dd class="font-medium">{Calendar.strftime(@user.inserted_at, "%B %Y")}</dd>
            </div>
          </dl>
          <div :if={own_profile?(@current_scope, @user)} class="mt-6">
            <.link navigate={~p"/users/settings/profile"} class="btn btn-primary w-full">
              <.icon name="hero-pencil-square" class="size-4" /> Edit Profile
            </.link>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp own_profile?(%{user: %{id: id}}, %{id: id}), do: true
  defp own_profile?(_scope, _user), do: false

  @impl true
  def mount(%{"username" => username}, _session, socket) do
    case Accounts.get_user_with_profile_by_username(username) do
      nil ->
        {:ok, socket |> put_flash(:error, "User not found.") |> redirect(to: ~p"/")}

      user ->
        {:ok, assign(socket, user: user)}
    end
  end

  defp display_name(user) do
    parts =
      [user.profile.first_name, user.profile.middle_name, user.profile.last_name]
      |> Enum.reject(&(is_nil(&1) or &1 == ""))

    case parts do
      [] -> user.username
      names -> Enum.join(names, " ")
    end
  end

  defp format_occupation(occupation) do
    occupation
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp format_location(profile) do
    [profile.city, profile.country]
    |> Enum.reject(&(is_nil(&1) or &1 == ""))
    |> Enum.join(", ")
  end

  defp format_rating(rating) when is_float(rating),
    do: :erlang.float_to_binary(rating, decimals: 1)

  defp format_rating(rating), do: to_string(rating)

  defp format_gender(:male), do: "Male"
  defp format_gender(:female), do: "Female"
  defp format_gender(:prefer_not_to_say), do: "Prefer not to say"
end
