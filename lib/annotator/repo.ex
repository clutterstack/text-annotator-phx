defmodule Annotator.Repo do
  use Ecto.Repo,
    otp_app: :annotator,
    adapter: Ecto.Adapters.SQLite3
end
