defmodule AnnotatorWeb.Router do
  use AnnotatorWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AnnotatorWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", AnnotatorWeb do
    pipe_through :browser
    live "/", CollectionLive.Index
    live "/collections", CollectionLive.Index
    live "/collections/new", TextAnnotatorLive
    live "/collections/:id", TextAnnotatorLive
    get "/collections/:id/export/html", ExportController, :html_table
    get "/collections/:id/export/md", ExportController, :markdown_table
  end

  # Other scopes may use custom stacks.
  # scope "/api", AnnotatorWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:annotator, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: AnnotatorWeb.Telemetry
    end
  end
end
