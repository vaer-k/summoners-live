defmodule SummonersWeb.Index.MatchList do
  use Phoenix.Component

  def list(assigns) do
    ~H"""
    <%= unless Enum.empty?(@teammates) do %>
      <div class="mx-4">
        <div class="max-w-3xl mx-auto text-center my-4">
          <h2 class="text-3xl font-extrabold text-white"><%= @tracked_summoner.name %>'s recent teammates</h2>
        </div>
        <ul role="list" class="grid grid-cols-1 gap-6 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4">
          <%= for mate <- @teammates do %>
            <li class="col-span-1 flex flex-col text-center bg-tertiary rounded-lg shadow divide-y divide-gray-200">
              <div class="flex-1 flex flex-col p-8">
                <object class="w-32 h-32 flex-shrink-0 mx-auto rounded-full ring-2 ring-white ring-offset-2 ring-offset-primary" data={"https://ddragon.leagueoflegends.com/cdn/11.14.1/img/profileicon/#{mate.profile_icon_id}.png"} type="image/jpg">
                  <img class="w-32 h-32 flex-shrink-0 mx-auto rounded-full ring-2 ring-white ring-offset-2 ring-offset-primary" src="https://ddragon.leagueoflegends.com/cdn/11.14.1/img/profileicon/4303.png" alt="">
                </object>
                <h3 class="mt-6 text-white text-sm font-medium"><%= mate.name %></h3>
                <dl class="mt-1 flex-grow flex flex-col justify-between">
                  <dt class="sr-only"><%= mate.name %></dt>
                  <%= unless is_nil(mate.last_match_id) do %>
                    <dd class="text-gray-500 text-sm">Time since last match:</dd>
                    <dd class="text-gray-500 text-sm">~<%= @time - mate.last_match_time %> seconds</dd>
                    <dt class="sr-only"><%= mate.last_match_time %></dt>
                  <% end %>
                  <dd class="mt-3">
                    <span class="px-2 py-1 text-white text-xs font-medium bg-pink-500 rounded-full">Account Level <%= mate.summoner_level %></span>
                  </dd>
                </dl>
              </div>
            </li>
          <% end %>
        </ul>
      </div>
    <% end %>
    """
  end
end
