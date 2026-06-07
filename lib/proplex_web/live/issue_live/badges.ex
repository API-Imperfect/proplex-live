defmodule ProplexWeb.IssueLive.Badges do
  use Phoenix.Component

  attr :status, :atom, required: true, values: [:reported, :in_progress, :resolved]

  def status_badge(assigns) do
    ~H"""
    <span class={["badge", status_badge_class(@status)]}>
      {status_label(@status)}
    </span>
    """
  end

  defp status_badge_class(:reported), do: "badge-neutral"
  defp status_badge_class(:in_progress), do: "badge-warning"
  defp status_badge_class(:resolved), do: "badge-success"

  defp status_label(:reported), do: "Reported"
  defp status_label(:in_progress), do: "In progress"
  defp status_label(:resolved), do: "Resolved"

  attr :priority, :atom, required: true, values: [:low, :medium, :high]

  def priority_badge(assigns) do
    ~H"""
    <span class={["badge", priority_badge_class(@priority)]}>
      {priority_label(@priority)}
    </span>
    """
  end

  defp priority_badge_class(:low), do: "badge-neutral"
  defp priority_badge_class(:medium), do: "badge-warning"
  defp priority_badge_class(:high), do: "badge-error"

  defp priority_label(:low), do: "Low"
  defp priority_label(:medium), do: "Medium"
  defp priority_label(:high), do: "High"
end
