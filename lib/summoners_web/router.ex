defmodule SummonersWeb.Router do
  use SummonersWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {SummonersWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", SummonersWeb do
    pipe_through :browser

    live "/", IndexLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", SummonersWeb do
  #   pipe_through :api
  # end
end
