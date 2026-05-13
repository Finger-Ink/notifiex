# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-05-14

### Changed

- **BREAKING** Replaced `httpoison` with [`req`](https://hex.pm/packages/req) (`~> 0.5`)
  as the underlying HTTP client. Req is built on Finch/Mint, is actively
  maintained, and avoids the security concerns associated with Hackney
  (the HTTPoison adapter).
- **BREAKING** Replaced `poison` with [`jason`](https://hex.pm/packages/jason)
  (`~> 1.4`) for JSON encoding. Req uses Jason internally, so this collapses
  two JSON libraries into one.
- **BREAKING** Minimum Elixir version bumped from `~> 1.12` to `~> 1.15`.
  Required by Req's dependency chain.
- The transport-error reason returned in `{:error, {:error, reason}}` tuples
  is now an `Exception.message/1` string (e.g. `"connection refused"`) rather
  than an HTTPoison atom (e.g. `:econnrefused`). The tuple shape is unchanged.
- Bumped `ex_doc` to `~> 0.40`, `credo` to `~> 1.7`, `dialyxir` to `~> 1.4`.
- CI now targets OTP 26 / Elixir 1.17.

### Added

- Slack endpoint URLs are now overridable via application config — see
  `:slack_post_message_url` and `:slack_files_upload_url`. Defaults are
  unchanged; this exists so test suites can point Slack requests at a local
  HTTP mock (e.g. Bypass).
- Test suite now covers the HTTP behaviour of the Slack and Discord services
  using [Bypass](https://hex.pm/packages/bypass).

### Removed

- `httpoison` is no longer a dependency. If your application relied on
  Notifiex pulling HTTPoison in transitively, declare it explicitly.
- `poison` is no longer a dependency. Same caveat as above for Jason.

### Migration

See [guides/upgrading_to_v2.md](guides/upgrading_to_v2.md) for a step-by-step
upgrade guide.

## [1.2.0] - 2023-05-27

### Added

- `Notifiex.send_multiple/1` and `Notifiex.send_async_multiple/1` for
  dispatching batches of notifications.
- `Notifiex.send_async/3` for fire-and-forget dispatch via a Task supervisor.
- Slack file uploads via `files.upload`.

## [1.1.0]

### Added

- Custom plugin support via `Notifiex.ServiceBehaviour` and
  `:notifiex, :services` application config.

## [1.0.0]

### Added

- Initial release with Slack and Discord support.

[2.0.0]: https://github.com/burntcarrot/notifiex/releases/tag/v2.0.0
[1.2.0]: https://github.com/burntcarrot/notifiex/releases/tag/v1.2.0
