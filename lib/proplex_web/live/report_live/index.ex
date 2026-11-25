defmodule ProplexWeb.ReportLive.Index do
  use ProplexWeb, :live_view

  @impl true
 def render(assigns) do
  ~H"""
   <Layouts.app flash={@flash} current_scope={@current_scope}>
     <div class="mx-auto max-w-3xl">
       <div class="mb-6">
         <h1 class="text-2xl font-semibold tracking-tight">My Reports</h1>
         <p class="mt-1 text-sm text-base-content/70">
           The paginated list of reports you've filed will appear here shortly.
         </p>
       </div>


       <div class="rounded-box border border-base-300 bg-base-200 px-6 py-8 text-center">
         <.link navigate={~p"/reports/new"} class="btn btn-primary">
           <.icon name="hero-plus" class="size-4" /> File a report
         </.link>
       </div>
     </div>
   </Layouts.app>
   """
 end


 @impl true
 def mount(_params, _session, socket), do: {:ok, socket}
end
