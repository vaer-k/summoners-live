# Summoners

To start your Phoenix server:

  * Install dependencies with `mix deps.get`
  * Add RIOT_API_KEY to shell environment with `export RIOT_API_KEY="[yourkey]"`
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

  * Enter a summoner name and region to search for recent teammates
  * When one of those teammates completes another match, their card will update


## Project description
Because this is a toy project, there is no database layer; all state is kept in memory. I felt that the Ecto/Postgres mechanisms would just detract from the Elixir application itself, which is what I expected was a greater priority. I also wanted to have a rudimentary UI to view the results in the browser, and I thought a basic liveview would be fun for that. 

There are two caches implementing GenServer, a short-lived one for caching the results of api queries, and a longer one for storing metadata about summoners. The summoners could also have gone into ETS or a database, but I thought this was simpler and sufficient. There's also a task supervisor for querying the riot api for updates on recent matches.

API queries are throttled after hitting the riot rate limit.

New matches are logged from the server, and also broadcast to the liveview over Phoenix pubsub.