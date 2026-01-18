# Hytalix

A web-based Hytale dedicated server manager built with Phoenix LiveView.

## Features

- Create and manage multiple Hytale server instances
- Real-time console with ANSI color support
- Automatic server file downloads via OAuth
- Configurable server options (memory, ports, auth mode, backups, etc.)
- Start/stop servers with live status updates

## Development

### Requirements

- Elixir 1.19+
- PostgreSQL 16+
- Java 25 (for running Hytale servers)

```bash
# Install dependencies
mix setup

# Start the server
iex -S mix phx.server
```

Visit [localhost:4000](http://localhost:4000)

## Production (Docker)

```bash
docker compose up --build
```

This will:
- Start PostgreSQL
- Run database migrations automatically
- Start the application on port 4000

Server files are persisted in a Docker volume.

## Configuration

Server configurations are stored in the database. Each server can be configured with:

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
