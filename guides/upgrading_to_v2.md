# Upgrading to Notifiex 2.0

Notifiex 2.0 swaps the HTTP client (HTTPoison → [Req](https://hex.pm/packages/req))
and the JSON library (Poison → [Jason](https://hex.pm/packages/jason)). The
public `Notifiex.send/3` / `send_async/3` / `send_multiple/1` API is unchanged.

## Dependencies

| | 1.x | 2.0 |
|---|---|---|
| Notifiex | `~> 1.2` | `~> 2.0` |
| HTTP client | `httpoison ~> 2.1` | `req ~> 0.5` (transitive) |
| JSON library | `poison ~> 5.0` | `jason ~> 1.4` (transitive) |
| Elixir | `~> 1.12` | `~> 1.15` |

If your `mix.exs` declared `httpoison` or `poison` only because Notifiex
pulled them in, you can remove them. If your own code uses them, keep them
declared explicitly.

## Code changes

The shape of error tuples is unchanged — `{:error, {:error, reason}}` — but
`reason` is now an `Exception.message/1` string (e.g. `"connection refused"`)
rather than an HTTPoison atom like `:econnrefused`. If you pattern-match on
the inner reason, update those clauses:

```elixir
# 1.x
{:error, {:error, :econnrefused}} -> retry()

# 2.0
{:error, {:error, reason}} when is_binary(reason) ->
  if reason =~ "connection refused", do: retry()
```

If you reference `HTTPoison.*` or `Poison.*` directly anywhere in your own
code (outside of Notifiex calls), migrate those call sites to Req / Jason or
declare the old library as an explicit dependency.

## Plugins

The `Notifiex.ServiceBehaviour` callback (`call/2`) is unchanged. Existing
plugins continue to compile and work — Notifiex doesn't prescribe which HTTP
or JSON library plugins use internally.
