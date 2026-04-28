defmodule ProplexWeb.PageController do
  use ProplexWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
