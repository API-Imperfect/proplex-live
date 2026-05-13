defmodule ProplexWeb.UserLive.ProfileEdit do
  use ProplexWeb, :live_view

  alias Proplex.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-2xl">
        <div class="relative rounded-box border border-base-300 bg-base-200 px-6 pb-8 pt-12 sm:px-10 sm:pb-10">
          <div class="absolute -top-7 left-1/2 inline-flex size-14 -translate-x-1/2 items-center justify-center rounded-full bg-primary/10 ring-4 ring-base-100">
            <.icon name="hero-pencil-square" class="size-9 text-primary" />
          </div>

          <div class="mb-6 text-center">
            <h1 class="text-2xl font-semibold tracking-tight">
              Edit your profile
            </h1>
            <p class="mt-2 text-sm text-base-content/70">
              Update your personal information and contact details.
            </p>
          </div>

          <.form
            for={@form}
            id="profile_form"
            phx-submit="save"
            phx-change="validate"
            phx-debounce="400"
          >
            <div class="grid grid-cols-1 gap-4 sm:grid-cols-3">
              <.input
                field={@form[:first_name]}
                type="text"
                label="First Name"
              />
              <.input
                field={@form[:middle_name]}
                type="text"
                label="Middle Name"
              />
              <.input
                field={@form[:last_name]}
                type="text"
                label="Last Name"
              />
            </div>

            <.input
              field={@form[:gender]}
              type="select"
              label="Gender"
              prompt="Select..."
              options={gender_options()}
            />
            <.input
              field={@form[:occupation]}
              type="select"
              label="Occupation"
              options={occupation_options()}
            />
            <.input
              field={@form[:bio]}
              type="textarea"
              label="Bio"
              placeholder="A short description about yourself"
            />
            <.input
              field={@form[:phone_number]}
              type="tel"
              label="Phone Number"
            />

            <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <.input
                field={@form[:country]}
                type="text"
                label="Country"
              />
              <.input
                field={@form[:city]}
                type="text"
                label="City"
              />
            </div>

            <.button phx-disable-with="Saving..." class="btn btn-primary mt-4 w-full">
              Save changes
            </.button>
          </.form>

          <p class="mt-6 text-center text-sm text-base-content/70">
            <.link
              navigate={~p"/users/#{@current_scope.user.username}/profile"}
              class="font-semibold text-primary hover:underline"
            >
              Back to profile
            </.link>
          </p>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = Accounts.get_user_with_profile_by_username(socket.assigns.current_scope.user.username)

    changeset = Accounts.change_user_profile(user.profile)

    {:ok,
     socket
     |> assign(:profile, user.profile)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"profile" => attrs}, socket) do
    changeset =
      socket.assigns.profile
      |> Accounts.change_user_profile(attrs)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"profile" => attrs}, socket) do
    case Accounts.update_user_profile(socket.assigns.profile, attrs) do
      {:ok, profile} ->
        {:noreply,
         socket
         |> assign(:profile, profile)
         |> assign_form(Accounts.change_user_profile(profile))
         |> put_flash(:info, "Profile updated successfully.")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, form: to_form(changeset, as: "profile"))
  end

  defp gender_options do
    [
      {"Male", :male},
      {"Female", :female},
      {"Prefer not to say", :prefer_not_to_say}
    ]
  end

  defp occupation_options do
    [
      {"None", :none},
      {"Mason", :mason},
      {"Carpenter", :carpenter},
      {"Plumber", :plumber},
      {"Roofer", :roofer},
      {"Painter", :painter},
      {"Electrician", :electrician},
      {"HVAC Technician", :hvac_technician}
    ]
  end
end
