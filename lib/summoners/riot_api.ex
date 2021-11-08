defmodule Summoners.RiotApi do
  alias Summoners.RiotApi.Cache

  @servers_by_region Constants.regions()
  @servers @servers_by_region |> Map.values() |> List.flatten()

  defmodule Summoner do
    @type t :: %Summoner{
            id: String.t(),
            name: String.t(),
            region: String.t(),
            last_match_id: String.t(),
            profile_icon_id: integer,
            summoner_level: integer,
            updates_remaining: integer
          }
    defstruct id: nil,
              name: nil,
              region: nil,
              last_match_id: nil,
              profile_icon_id: nil,
              summoner_level: nil,
              updates_remaining: 60
  end

  @spec search_summoner(String.t(), String.t()) ::
          {:error, :not_found | :unexpected_response}
          | {:ok, {Summoners.RiotApi.Summoner.t(), [Summoners.RiotApi.Summoner.t()]}}
  def search_summoner(summoner_name, server) when server in @servers do
    case find_summoner_by_name(summoner_name, server) do
      {:ok, summoner} ->
        {:ok, teammates} = fetch_teammates(summoner, server)
        Summoners.Cache.insert_or_update([summoner | teammates])
        {:ok, {summoner, teammates}}

      error ->
        error
    end
  end

  def spec_compliant_search_summoner(summoner_name, server) when server in @servers do
    case find_summoner_by_name(summoner_name, server) do
      {:ok, summoner} ->
        {:ok, teammates} = fetch_teammates(summoner, server)
        Summoners.Cache.insert_or_update([summoner | teammates])
        teammates = Enum.map(teammates, & &1.name)

        {:ok, teammates}

      error ->
        error
    end
  end

  @doc """
  Search for summoner in following locations in order:
  1) Summoners Cache
  2) Riot API endpoint query cache
  3) Riot API endpoint
  """
  def find_summoner_by_name(summoner_name, server) do
    case Summoners.Cache.lookup(summoner_name, server) do
      nil ->
        request_summoner_by_name(summoner_name, server)

      %Summoner{} = summoner ->
        {:ok, summoner}
    end
  end

  defp request_summoner_by_name(summoner_name, server) do
    summoner_name
    |> summoner_query(server)
    |> execute_query()
    |> case do
      {:ok, summoner} ->
        {:ok,
         %Summoner{
           id: summoner["puuid"],
           name: summoner_name,
           region: server,
           profile_icon_id: summoner["profileIconId"],
           summoner_level: summoner["summonerLevel"]
         }}

      error ->
        error
    end
  end

  defp fetch_teammates(summoner, region) do
    case fetch_matches(summoner, 5) do
      {:ok, match_ids} ->
        participants =
          match_ids
          |> Enum.map(fn id -> fetch_match(id, region) end)
          |> Enum.map(fn
            {:ok, match} ->
              match["info"]["participants"]

            {:error, _} ->
              []
          end)
          |> List.flatten()
          |> Enum.map(fn participant ->
            %Summoner{
              id: participant["puuid"],
              name: participant["summonerName"],
              region: region,
              profile_icon_id: participant["profileIcon"],
              summoner_level: participant["summonerLevel"]
            }
          end)
          |> Enum.filter(&(&1.id != summoner.id))

        {:ok, participants}

      {:error, _reason} ->
        {:error, :not_found}
    end
  end

  def fetch_matches(summoner, count) do
    summoner.id
    |> matches_query(summoner.region, count)
    |> execute_query()
  end

  def fetch_match(match_id, region) do
    match_id
    |> match_query(region)
    |> execute_query()
  end

  defp execute_query(query) do
    case Cache.lookup(query) do
      nil ->
        case execute_query(query, cache: false) do
          {:ok, body} = response ->
            Cache.insert_or_update(query, body)
            response

          error ->
            error
        end

      response ->
        {:ok, response}
    end
  end

  defp execute_query(query, times_tried \\ 1, cache: false) do
    Finch.build(:get, query)
    |> Finch.request(Riot)
    |> case do
      {:ok, resp} ->
        body = Jason.decode!(resp.body)
        {:ok, body}

      _ ->
        {:error, :unexpected_response}
    end
    |> format_response()
    |> throttle(query, times_tried)
  end

  # Exponential backoff when rate limit exceeded
  defp throttle({:error, :rate_limit_exceeded}, query, times_tried) do
    :timer.sleep(Integer.pow(2, times_tried + :rand.uniform(3)) * 1000)
    execute_query(query, times_tried + 1, cache: false)
  end

  defp throttle(response, _, _), do: response

  defp summoner_query(summoner_name, server) do
    "https://#{server}.api.riotgames.com/lol/summoner/v4/summoners/by-name/#{summoner_name}?api_key=#{api_key()}"
  end

  defp matches_query(puuid, server, count) do
    region = get_region(server)

    "https://#{region}.api.riotgames.com/lol/match/v5/matches/by-puuid/#{puuid}/ids?start=0&count=#{count}&api_key=#{api_key()}"
  end

  defp match_query(match_id, server) do
    region = get_region(server)

    "https://#{region}.api.riotgames.com/lol/match/v5/matches/#{match_id}?api_key=#{api_key()}"
  end

  defp format_response(response) do
    case response do
      {:ok, %{"status" => %{"status_code" => 401}}} ->
        {:error, :unauthorized}

      {:ok, %{"status" => %{"status_code" => 404}}} ->
        {:error, :not_found}

      {:ok, %{"status" => %{"status_code" => 429}}} ->
        {:error, :rate_limit_exceeded}

      {:ok, _body} = success ->
        success

      error ->
        error
    end
  end

  defp api_key(), do: Application.fetch_env!(:summoners, :riot_api_key)

  defp get_region(server) do
    {region, _regions} =
      Enum.find(@servers_by_region, fn {_region, servers} ->
        server in servers
      end)

    region
  end
end
