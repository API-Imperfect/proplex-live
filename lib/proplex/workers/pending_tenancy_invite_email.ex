defmodule Proplex.Workers.PendingTenancyInviteEmail do
  use Oban.Worker, queue: :mailers

  alias Proplex.Repo
  alias Proplex.Apartments.InviteNotifier
  alias Proplex.Apartments.PendingTenancy

  @impl Oban.Worker
  def perform(%Oban.Job{
    args: %{"pending_tenancy_id" => id, "raw_token" => raw_token}
  }) do
    pending = Repo.get(PendingTenancy, id) |> Repo.preload(:apartment)

    cond do
      is_nil(pending) ->
        {:cancel, "pending tenancy #{id} not found (cancelled or consumed)"}

      not token_matches?(pending, raw_token) ->
        {:cancel, "token suspended by regeneration for pending tenancy #{id}"}

      true ->
        case InviteNotifier.deliver_invite(pending, raw_token) do
          {:ok, _email} -> :ok

          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp token_matches?(%PendingTenancy{token_hash: stored_hash}, raw_token) do
    :crypto.hash(:sha256, raw_token) == stored_hash
  end
end
