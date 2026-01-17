defmodule Hytalix.Repo do
  use Ecto.Repo,
    otp_app: :hytalix,
    adapter: Ecto.Adapters.Postgres
end
