# Grafana Alloy Log Monitoring Stack - AI Agent Instructions

## Project Architecture

This is a **standalone Docker-based monitoring stack** that reads JSON log files from the filesystem and provides log analysis through Grafana. The architecture follows a simple pipeline:

**Log Files → Alloy Agent → Loki Storage → Grafana Visualization**

### Key Components
- **Alloy Agent** (`config.alloy`): File watcher + JSON parser + log forwarder
- **Loki**: Log storage backend with LogQL query capabilities  
- **Grafana**: Web UI with pre-configured Loki datasource
- **Environment Config** (`grafana-set-env.sh`): Central configuration for all paths and ports

## Critical Configuration Patterns

### Environment-First Design
The entire stack is configured through `grafana-set-env.sh` environment variables. **Always source this file** before Docker operations:
```bash
source ./grafana-set-env.sh && docker-compose up -d
```

### Alloy Configuration Syntax
The `config.alloy` file uses Grafana's River syntax. Critical patterns:

**JSON Path Expressions**: Use quoted keys for special characters:
```alloy
user_agent = "req.headers.\"user-agent\""  # NOT "req.headers.user-agent"
```

**Component Chaining**: Data flows through linked components:
```alloy
local.file_match → loki.source.file → loki.process → loki.write
```

**Missing Trailing Commas**: Always check for trailing commas in field lists - this is a common syntax error.

## Essential Workflows

### Container Management
Always use the provided scripts with environment sourcing:
```bash
./start.sh          # Idempotent startup with env validation
./stop.sh           # Clean shutdown
./restart.sh        # Standard restart
./restart.sh --complete  # Full recreate (for config changes)
```

**Never use raw `docker-compose` commands** - they lack the required environment variables.

### Configuration Changes
1. Edit `config.alloy` or `docker-compose.yml`
2. Validate with `./restart.sh --complete` (recreates containers)
3. Check logs with `docker logs alloy-dev` if Alloy fails to start

### Multi-Environment Setup
Use `GRAFANA_ENV_SUFFIX` for running multiple instances:
```bash
export GRAFANA_ENV_SUFFIX="prod"  # Creates containers: alloy-prod, loki-prod, grafana-prod
export GRAFANA_PORT="3001"        # Avoid port conflicts
```

## Debugging Common Issues

### Alloy Container Crashes
1. **Check syntax**: `docker logs alloy-dev` shows River syntax errors
2. **Validate JSON paths**: Ensure quoted keys for special characters  
3. **Verify file paths**: Log source directory must be absolute path and exist

### Port Conflicts
Edit `grafana-set-env.sh` ports, then use `./restart.sh --complete`

### Volume Mount Issues
- All paths in `grafana-set-env.sh` must be **absolute paths**
- `GRAFANA_LOGS_SOURCE_DIR` must contain `.log` files with JSON content
- `GRAFANA_DB_BASE_DIR` stores persistent data across restarts

## JSON Log Processing

### Expected Log Format
Single-line JSON objects (compatible with Pino logging):
```json
{"level":30,"time":"2025-10-04T17:49:20.713Z","pid":111184,"hostname":"XPS-9300","reqId":"req-352","req":{"method":"GET","url":"/api","headers":{"user-agent":"curl/7.68.0"},"remoteAddress":"::1"},"res":{"statusCode":200},"responseTime":14,"msg":"request completed"}
```

### Alloy JSON Processing Pipeline
The `loki.process "json_parser"` stage extracts specific fields and creates labels for efficient querying. When adding new fields:
1. Add to `expressions` block for extraction
2. Add to `stage.labels.values` for filtering (optional)
3. Restart with `./restart.sh --complete`

## Project Structure & Conventions

### File Responsibilities
- `start.sh`, `stop.sh`, `restart.sh`: **Primary interface** - use these, not direct docker-compose
- `grafana-set-env.sh`: **Single source of truth** for all configuration
- `config.alloy`: Alloy agent configuration (River syntax)
- `docker-compose.yml`: Container orchestration with env var interpolation
- `package.json`: Optional NPM convenience scripts (`npm start`, `npm stop`)

### Naming Conventions
- Container names: `{service}-${GRAFANA_ENV_SUFFIX}` (e.g., `alloy-dev`)
- Volume paths: Use environment variables, never hardcode
- Log job labels: Set in `config.alloy` path_targets (`"job" = "your-app-name"`)

## Integration Points

### External Dependencies
- **Log Source**: Reads from `${GRAFANA_LOGS_SOURCE_DIR}/*.log` files
- **Data Persistence**: Stores in `${GRAFANA_DB_BASE_DIR}/{grafana,loki,alloy}/`
- **Network**: Internal Docker network with service discovery (`loki:3100`)

### Log File Monitoring
- File discovery: `path_targets` glob patterns in `local.file_match`
- Sync frequency: `sync_period = "5s"` for new file detection
- Reading mode: `tail_from_end = false` reads entire files (including historical logs)

## Troubleshooting Checklist

When assisting with issues:
1. **Environment**: Verify `grafana-set-env.sh` paths exist and are absolute
2. **Container Status**: Check `docker ps` - is alloy-dev running?
3. **Alloy Logs**: `docker logs alloy-dev` for syntax/config errors
4. **File Access**: Can alloy container read the log directory?
5. **JSON Validity**: Are log files valid single-line JSON objects?
6. **Port Conflicts**: Are configured ports available?

## Common Modifications

### Adding New Log Sources
Edit `config.alloy` to add additional `local.file_match` and `loki.source.file` blocks with different job labels.

### Customizing JSON Field Extraction  
Modify the `expressions` block in `loki.process "json_parser"` to extract additional fields from your JSON logs.

### Performance Tuning
For high-volume logs, set `tail_from_end = true` to skip historical data and only process new entries.