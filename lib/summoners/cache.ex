defmodule Summoners.Cache do
  @moduledoc """
  State of cache contains values {update_timer, summoner} keyed by region:puuid
  """
  use GenServer
  alias Summoners.RiotApi.Summoner
  alias Summoners.RiotApi

  @update_interval :timer.minutes(1)
  @clear_interval :timer.hours(24)

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def handle_call({:lookup, summoner_name, region}, _from, cache) do
    result =
      case Map.get(cache, key(region, summoner_name)) do
        nil -> nil
        {_, summoner} -> summoner
      end

    {:reply, result, cache}
  end

  def handle_call({:lookup, cache_key}, _from, cache) when is_binary(cache_key) do
    result =
      case Map.get(cache, cache_key) do
        nil -> nil
        {_, summoner} -> summoner
      end

    {:reply, result, cache}
  end

  def handle_cast({:cache, %Summoner{} = summoner}, cache) do
    cache_key = key(summoner)

    {timer, summoner} =
      case Map.get(cache, cache_key) do
        {_timer, _summoner} = cache_result ->
          {timer, cached_summoner} = schedule_update(cache_result)
          summoner = Map.merge(cached_summoner, summoner)
          {timer, summoner}

        nil ->
          schedule_update({nil, summoner})
      end

    {:noreply, Map.put(cache, cache_key, {timer, summoner})}
  end

  def handle_info(:clear, _cache) do
    cache = init_state() |> schedule_clear()
    {:noreply, cache}
  end

  def handle_info({:update, cache_key}, cache) do
    Task.Supervisor.start_child(Summoners.TaskSupervisor, fn -> do_update(cache_key) end)

    {:noreply, cache}
  end

  @doc """
  Updates a timer for a summoner's recent match to be refreshed
  """
  def schedule_update({timer, summoner}) do
    timer = cancel_timer(timer)

    if summoner.updates_remaining > 0 do
      timer = Process.send_after(self(), {:update, key(summoner)}, :timer.minutes(1))
      {timer, summoner}
    else
      {timer, summoner}
    end
  end

  defp do_update(cache_key) do
    summoner = lookup(cache_key)
    {:ok, [match_id]} = RiotApi.fetch_matches(summoner, 1)

    # Don't log the first update, since it's not live
    if is_new_match(summoner, match_id) && summoner.updates_remaining <= 59 do
      log_new_match(summoner, match_id)

      SummonersWeb.Endpoint.broadcast!("summoner:" <> summoner.id, "new_match", %{
        match_id: match_id
      })
    end

    summoner
    |> Map.put(:last_match_id, match_id)
    |> Map.put(:updates_remaining, summoner.updates_remaining - 1)
    |> insert_or_update()
  end

  defp schedule_clear(cache) do
    %{cache | clear_timer: Process.send_after(self(), :clear, cache.clear_interval)}
  end

  defp init_state() do
    cache = %{
      clear_interval: @clear_interval,
      update_interval: @update_interval,
      clear_timer: nil,
      update_timer: nil
    }

    schedule_clear(cache)
  end

  def cancel_timer(nil), do: nil

  def cancel_timer(timer) do
    Process.cancel_timer(timer)
    nil
  end

  defp key(summoner) do
    key(summoner.region, summoner.name)
  end

  defp key(region, summoner_name) do
    region <> ":" <> summoner_name
  end

  defp log_new_match(summoner, match_id) do
    IO.inspect("Summoner #{summoner.name} completed match #{match_id}")
  end

  defp is_new_match(%Summoner{last_match_id: id}, _) when is_nil(id), do: true

  defp is_new_match(summoner, match_id) do
    curr_last_match = match_id_to_integer(summoner.last_match_id)
    new_last_match = match_id_to_integer(match_id)
    curr_last_match < new_last_match
  end

  defp match_id_to_integer(match_id) do
    match_id
    |> String.split("_")
    |> List.last()
    |> String.to_integer()
  end

  # Client

  def init(_) do
    cache = init_state() |> schedule_clear()
    {:ok, cache}
  end

  def lookup(cache_key) when is_binary(cache_key) do
    GenServer.call(__MODULE__, {:lookup, cache_key})
  end

  def lookup(summoner_name, region) do
    GenServer.call(__MODULE__, {:lookup, summoner_name, region})
  end

  def insert_or_update(%Summoner{} = summoner) do
    GenServer.cast(__MODULE__, {:cache, summoner})
  end

  def insert_or_update([%Summoner{} | _rest] = summoners) do
    for %Summoner{} = summoner <- summoners do
      GenServer.cast(__MODULE__, {:cache, summoner})
    end
  end

  def insert_or_update([]), do: :ok
end
