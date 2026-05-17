defmodule ProplexWeb.UserLive.ProfileEdit do
  use ProplexWeb, :live_view

  require Logger
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
            <div class="mb-6">
              <label class="mb-2 block text-sm font-medium">Avatar</label>

              <div class="flex items-center gap-4">
                <div class="size-20 shrink-0 overflow-hidden rounded-full bg-base-300 ring-1 ring-base-300">
                  <%= case avatar_preview_state(@uploads, @profile) do %>
                    <% :upload_preview -> %>
                      <.live_img_preview
                        entry={List.first(@uploads.avatar.entries)}
                        class="size-20 object-cover"
                      />
                    <% :current_avatar -> %>
                      <img
                        src={@profile.avatar_url}
                        alt="Current avatar"
                        class="size-20 object-cover"
                      />
                    <% :placeholder -> %>
                      <div class="flex size-20 items-center justify-center">
                        <.icon name="hero-user-circle" class="size-14 text-base-content/40" />
                      </div>
                  <% end %>
                </div>

                <div class="flex-1">
                  <.live_file_input
                    upload={@uploads.avatar}
                    class="file-input file-input-bordered w-full"
                  />
                  <p class="mt-1 text-xs text-base-content/60">JPG, PNG or WEBP - max 5MB</p>

                  <%= if entry= List.first(@uploads.avatar.entries) do %>
                    <div class="mt-2 flex items-center gap-2">
                      <progress
                        class="progress progress-primary flex-1"
                        value={entry.progress}
                        max="100"
                      />

                      <span class="text-xs tabular-nums text-base-content/60">{entry.progress}%</span>

                      <button
                        type="button"
                        phx-click="cancel-avatar-upload"
                        phx-value-ref={entry.ref}
                        class="btn btn-ghost btn-xs"
                        aria-label="Cancel upload"
                      >
                        <.icon name="hero-x-mark" class="size-4" />
                      </button>
                    </div>
                  <% end %>

                  <p :for={err <- upload_errors(@uploads.avatar)} class="mt-1 text-xs text-error">
                    {upload_error_to_string(err)}
                  </p>

                  <%= if entry=List.first(@uploads.avatar.entries) do %>
                    <p
                      :for={err <- upload_errors(@uploads.avatar, entry)}
                      class="mt-1 text-xs text-error"
                    >
                      {upload_error_to_string(err)}
                    </p>
                  <% end %>
                </div>
              </div>
            </div>

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
     |> assign_form(changeset)
     |> allow_upload(:avatar,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 1,
       max_file_size: 5_000_000,
       auto_upload: true
     )}
  end

  @impl true
  def handle_event("validate", %{"profile" => attrs}, socket) do
    changeset =
      socket.assigns.profile
      |> Accounts.change_user_profile(attrs)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("cancel-avatar-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :avatar, ref)}
  end

  def handle_event("save", %{"profile" => attrs}, socket) do
    case consume_avatar_uploads(socket) do
      [{:error, _reason}] ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "We couldn't process that image. Please try a different file (JPG, PNG or WEBP)."
         )}

      avatar_result ->
        save_profile(socket, attrs, avatar_result)
    end
  end

  defp save_profile(socket, attrs, avatar_result) do
    attrs =
      case avatar_result do
        [{:ok, url}] -> Map.put(attrs, "avatar_url", url)
        [] -> attrs
      end

    case Accounts.update_user_profile(socket.assigns.profile, attrs) do
      {:ok, profile} ->
        if avatar_result != [] do
          delete_old_avatar_file(socket.assigns.profile.avatar_url)
        end

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

  defp avatar_preview_state(uploads, profile) do
    cond do
      uploads.avatar.entries != [] -> :upload_preview
      profile.avatar_url -> :current_avatar
      true -> :placeholder
    end
  end

  defp consume_avatar_uploads(socket) do
    consume_uploaded_entries(socket, :avatar, fn %{path: tmp_path}, _entry ->
      filename = "#{Ecto.UUID.generate()}.jpg"

      dest_dir = uploads_dir()

      File.mkdir_p!(dest_dir)

      dest_path = Path.join(dest_dir, filename)

      case process_image(tmp_path, dest_path) do
        :ok ->
          {:ok, {:ok, "/uploads/avatars/#{filename}"}}

        {:error, _reason} = error ->
          File.rm(dest_path)
          Logger.warning("Avatar processing failed: #{inspect(error)}")
          {:ok, error}
      end
    end)
  end

  defp process_image(tmp_path, dest_path) do
    with {:ok, thumb} <- Image.thumbnail(tmp_path, 400, crop: :center),
         {:ok, _} <-
           Image.write(thumb, dest_path,
             quality: 85,
             strip_metadata: true,
             progressive: true
           ) do
      :ok
    end
  end

  defp uploads_dir do
    Path.join([
      Application.app_dir(:proplex, "priv"),
      "static",
      "uploads",
      "avatars"
    ])
  end

  defp delete_old_avatar_file(nil), do: :ok

  defp delete_old_avatar_file("/uploads/avatars/" <> filename) do
    path = Path.join(uploads_dir(), filename)

    File.rm(path)
    :ok
  end

  defp delete_old_avatar_file(_), do: :ok

  defp upload_error_to_string(:too_large), do: "File is too large (max 5MB)"
  defp upload_error_to_string(:not_accepted), do: "Invalid file type - use JPG, PNG or WEBP"
  defp upload_error_to_string(:too_many_files), do: "Only one avatar allowed"
  defp upload_error_to_string(err), do: "Upload error: #{inspect(err)}"

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
