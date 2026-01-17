defmodule HytalixWeb.PageController do
  use HytalixWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
