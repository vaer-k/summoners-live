defmodule SummonersWeb.IndexLive do
  use SummonersWeb, :live_view
  alias Summoners.RiotApi
  alias SummonersWeb.Index.MatchList
  alias Phoenix.Socket.Broadcast

  @impl true
  def mount(_params, _session, socket) do
    now = DateTime.utc_now() |> DateTime.to_unix()

    {:ok,
     assign(socket, time: now, regions: Constants.regions(), tracked_summoner: nil, teammates: [])}
  end

  @impl true
  def handle_event("search", %{"summoner" => summoner_params}, socket) do
    %{"summoner" => summoner, "region" => region} = summoner_params

    case RiotApi.search_summoner(summoner, region) do
      {:ok, {summoner, teammates}} ->
        for mate <- teammates do
          :ok = SummonersWeb.Endpoint.subscribe("summoner:" <> mate.id)
        end

        Process.send_after(self(), :tick, 5000)
        socket = assign(socket, tracked_summoner: summoner, region: region, teammates: teammates)
        {:noreply, socket}

      _error ->
        socket = assign(socket, tracked_summoner: summoner, region: region, teammates: [])
        {:noreply, put_flash(socket, :error, "summoner not found")}
    end
  end

  @impl true
  def handle_info(:tick, socket) do
    Process.send_after(self(), :tick, 5000)
    now = DateTime.utc_now() |> DateTime.to_unix()
    {:noreply, assign(socket, :time, now)}
  end

  @impl true
  @doc """
  Update liveview when new matches are played
  """
  def handle_info(
        %Broadcast{topic: "summoner:" <> summoner_id, payload: %{match_id: match_id}},
        socket
      ) do
    teammates =
      Enum.reduce(socket.assigns.teammates, [], fn
        %{id: id} = mate, acc when id == summoner_id ->
          # I'm conveniently manufacturing a very approximate match time just for show
          now = (DateTime.utc_now() |> DateTime.to_unix()) - 30
          # Ensure updated summoner is moved to front for highlighting in view
          updated_summoner = Map.merge(mate, %{last_match_id: match_id, last_match_time: now})
          acc ++ [updated_summoner]

        mate, acc ->
          [mate | acc]
      end)
      |> Enum.reverse()

    {:noreply, assign(socket, teammates: teammates)}
  end
end
