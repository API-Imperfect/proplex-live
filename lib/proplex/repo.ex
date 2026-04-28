defmodule Proplex.Repo do
  use Ecto.Repo,
    otp_app: :proplex,
    adapter: Ecto.Adapters.Postgres
end
