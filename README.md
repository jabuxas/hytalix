# Hytalix

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Elixir](https://img.shields.io/badge/Elixir-1.19+-purple.svg)](https://elixir-lang.org/)
[![Phoenix](https://img.shields.io/badge/Phoenix-1.8-orange.svg)](https://phoenixframework.org/)

A web-based Hytale dedicated server manager built with Phoenix LiveView. Similar to [Crafty Controller](https://craftycontrol.com/) but for Hytale.

## Features

- 🎮 Create and manage multiple Hytale server instances
- 📺 Real-time console with ANSI color support
- ⬇️ Automatic server file downloads via OAuth
- ⚙️ Configurable server options (memory, ports, auth mode, backups, etc.)
- 🚀 Start/stop servers with live status updates
- 🐳 Docker-ready with automatic migrations

## Development

### Requirements

- Elixir 1.19+
- PostgreSQL 16+
- Java 25 (for running Hytale servers)

```bash
mix setup
iex -S mix phx.server
```

Visit [localhost:4000](http://localhost:4000)

## Production (Docker)

```bash
docker compose up --build
```

Migrations run automatically. Server files persist in a Docker volume.

## Configuration

| Option | Default | Description |
|--------|---------|-------------|
| `port` | 5520 | Server port (UDP/QUIC) |
| `memory_min_mb` | 1024 | Minimum heap size |
| `memory_max_mb` | 4096 | Maximum heap size |
| `auth_mode` | authenticated | `authenticated` or `offline` |
| `view_distance` | 12 | Chunk view distance |
| `use_aot_cache` | true | Use AOT cache for faster startup |
| `disable_sentry` | false | Disable crash reporting |
| `backup_enabled` | false | Enable automatic backups |

## License

MIT
