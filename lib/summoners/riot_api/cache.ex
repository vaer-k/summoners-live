defmodule Summoners.RiotApi.Cache do
  use GenServer

  @clear_interval :timer.seconds(60)

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: RiotApiCache)
  end

  def handle_cast({:update, {query, result}}, cache) do
    cache = Map.put(cache, query, result)
    {:noreply, cache}
  end

  def handle_call({:lookup, query}, _from, cache) do
    {:reply, Map.get(cache, query), cache}
  end

  def handle_info(:clear, _cache) do
    cache = init_state() |> schedule_clear()
    {:noreply, cache}
  end

  defp init_state() do
    schedule_clear(%{interval: @clear_interval, timer: nil})
  end

  defp schedule_clear(cache) do
    %{cache | timer: Process.send_after(self(), :clear, cache.interval)}
  end

  # Client

  def init(_) do
    cache = init_state() |> schedule_clear()
    {:ok, cache}
  end

  def lookup(query) do
    GenServer.call(RiotApiCache, {:lookup, query})
  end

  def insert_or_update(query, result) do
    GenServer.cast(RiotApiCache, {:update, {query, result}})
  end
end
