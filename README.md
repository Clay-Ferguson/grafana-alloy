# Grafana Alloy Log Monitoring - Standalone Project

This is a **standalone project** containing a Grafana Alloy monitoring stack for analyzing JSON-formatted application logs.

## Overview

This setup uses Grafana Alloy to collect logs from any directory containing JSON log files, forwards them to Loki for storage, and makes them available for visualization in Grafana. The configuration is based on the [Grafana Alloy scenario](https://github.com/grafana/alloy-scenarios/tree/main/logs-file).

**Key Features:**
- **Standalone project** - can be used independently to monitor any application that produces JSON logs
- **Docker-based** - runs entirely in Docker containers (Alloy, Loki, Grafana)
- **Zero code dependencies** - only reads log files from the filesystem
- **Configurable** - easy to point at different log directories
- **Persistent storage** - logs and configurations survive container restarts

## Quick Start

### Prerequisites
- Docker and Docker Compose installed
- Application producing JSON-formatted log files (e.g., using Pino for Node.js)

### Installation

1. **Clone or copy this directory** to your preferred location
2. **Configure the environment** by editing `grafana-set-env.sh`:
   ```bash
   # Point to your application's log directory
   export GRAFANA_LOGS_SOURCE_DIR="/path/to/your/app/logs"
   
   # Set where to store Grafana data
   export GRAFANA_DB_BASE_DIR="/path/to/grafana-data"
   ```
3. **Start the stack**:
   ```bash
   ./start.sh
   ```

That's it! Access Grafana at `http://localhost:3000`

## Configuration Requirements

Before running, you must configure where your application logs are located. Edit `grafana-set-env.sh`:

```bash
# REQUIRED: Point this to your application's log directory (absolute path)
export GRAFANA_LOGS_SOURCE_DIR="/path/to/your/application/logs"

# REQUIRED: Where to store persistent Grafana/Loki data (absolute path)  
export GRAFANA_DB_BASE_DIR="/home/yourusername/grafana-data"

# OPTIONAL: Environment identifier (useful for running multiple instances)
export GRAFANA_ENV_SUFFIX="dev"  # or "prod", "test", etc.

# OPTIONAL: Port configurations (change if ports are already in use)
export GRAFANA_PORT="3000"
export LOKI_PORT="3100"
export ALLOY_HTTP_PORT="12345"
```

**Important:** The `GRAFANA_LOGS_SOURCE_DIR` must point to a directory containing `.log` files with JSON-formatted log entries.

## Configuration

### Alloy Configuration (`config.alloy`)

The Alloy agent is configured to:
- Monitor `/temp/logs/*.log` (mapped to Quanta's log directory)
- **Parse JSON logs** and extract structured metadata
- Use job label "quanta" for log identification
- Read entire log files including existing content (`tail_from_end = false`)
- Check for new files every 5 seconds
- Forward processed logs with labels to Loki

Key configuration with JSON parsing:
```alloy
local.file_match "local_files" {
    path_targets = [{"__path__" = "/temp/logs/*.log", "job" = "quanta", "hostname" = constants.hostname}]
    sync_period  = "5s"
}

loki.source.file "log_scrape" {
    targets    = local.file_match.local_files.targets
    forward_to = [loki.process.json_parser.receiver]
    tail_from_end = false
}

// Process JSON logs and extract structured metadata
loki.process "json_parser" {
    stage.json {
        expressions = {
            level     = "level",
            timestamp = "time", 
            message   = "msg",
            pid       = "pid",
            hostname  = "hostname",
        }
    }

    // Add labels for better querying
    stage.labels {
        values = {
            level    = "",
            hostname = "",
        }
    }

    // Format timestamp if needed
    stage.timestamp {
        source = "timestamp"
        format = "RFC3339"
    }

    forward_to = [loki.write.local.receiver]
}
```

### Docker Compose Setup

The stack includes three containers:
- **Alloy**: Log collection agent (port ${ALLOY_HTTP_PORT})
- **Loki**: Log storage backend (port ${LOKI_PORT})  
- **Grafana**: Visualization frontend (port ${GRAFANA_PORT})

Volume mount configuration:
```yaml
volumes:
  - ./config.alloy:/etc/alloy/config.alloy
  - /home/clay/ferguson/quanta/dist/server/logs:/temp/logs
```

**Note**: Use absolute paths for volume mounts to ensure reliable access to log files.

## Expected Log Format

This monitoring stack expects **structured JSON logs**. Each log entry should be a valid JSON object on a single line.

### Example JSON Log Format (using Pino)
```json
{
  "level": 30,
  "time": "2025-09-26T18:48:32.628Z",
  "pid": 111184,
  "hostname": "XPS-9300",
  "msg": "Application started successfully"
}
```

### HTTP Request/Response Logs
```json
{
  "level": 30,
  "time": "2025-09-26T18:48:32.628Z",
  "pid": 111184,
  "hostname": "XPS-9300",
  "reqId": "req-352",
  "req": {
    "method": "GET",
    "url": "/api/data",
    "headers": { "host": "localhost:8000" },
    "remoteAddress": "::1"
  },
  "res": {
    "statusCode": 200,
    "headers": { "content-type": "application/json" }
  },
  "responseTime": 14,
  "msg": "request completed"
}
```

**For Node.js applications**, we recommend using [Pino](https://github.com/pinojs/pino) for structured JSON logging.

## Usage

### Starting the Stack
```bash
./start.sh
```
- Automatically creates required data directories
- Checks if containers are already running (idempotent)
- Starts only if needed
- Provides status feedback and URLs

### Stopping the Stack
```bash
./stop.sh
```
- Safely stops all containers
- Preserves all data and configuration

### Restarting the Stack
```bash
# Quick restart (recommended)
./restart.sh

# Complete restart (recreates containers)
./restart.sh --complete
```

### Using Docker Compose Directly
You can also use standard Docker Compose commands:
```bash
docker-compose up -d    # Start
docker-compose down     # Stop
docker-compose restart  # Restart
```

### Access Points
After starting, access the web interfaces:
- **Grafana UI**: `http://localhost:${GRAFANA_PORT}` (default: 3000)
- **Alloy UI**: `http://localhost:${ALLOY_HTTP_PORT}` (default: 12345)

### Running Multiple Instances
To run multiple monitoring stacks simultaneously (e.g., for dev and prod):

1. Create separate copies of this directory
2. Edit `grafana-set-env.sh` in each copy:
   ```bash
   # Instance 1 (dev)
   export GRAFANA_ENV_SUFFIX="dev"
   export GRAFANA_PORT="3000"
   export GRAFANA_LOGS_SOURCE_DIR="/path/to/dev/logs"
   
   # Instance 2 (prod)  
   export GRAFANA_ENV_SUFFIX="prod"
   export GRAFANA_PORT="3001"  # Different port!
   export GRAFANA_LOGS_SOURCE_DIR="/path/to/prod/logs"
   ```
3. Start each instance with `./start.sh`

## File Structure

```
grafana-alloy/
├── README.md                   # This documentation
├── package.json                # NPM scripts for convenience
├── grafana-set-env.sh          # Environment configuration (CUSTOMIZE THIS)
├── config.alloy                # Alloy agent configuration
├── loki-config.yaml            # Loki storage configuration
├── docker-compose.yml          # Container orchestration
├── init-data-folders.sh        # Data directory initialization
├── start.sh                    # Start script
├── stop.sh                     # Stop script
└── restart.sh                  # Restart script
```

## NPM Scripts (Optional)

If you have Node.js installed, you can use NPM scripts for convenience:

```bash
npm start              # Same as ./start.sh
npm run stop           # Same as ./stop.sh
npm run restart        # Same as ./restart.sh
npm run init           # Same as ./init-data-folders.sh
```

## Features

- **Standalone & Portable**: No runtime dependencies on the application being monitored
- **Docker-Based**: Runs entirely in containers with Docker Compose
- **Structured JSON Logging**: Parses JSON logs with rich metadata extraction
- **HTTP Request Tracing**: Advanced filtering on HTTP requests, responses, and timing
- **Automatic Log Discovery**: Monitors directories for all `.log` files
- **Real-time Monitoring**: New log entries are ingested as they're written
- **Historical Data**: Existing log files are read in their entirety
- **Persistent Storage**: Logs and dashboards survive container restarts
- **Advanced Querying**: LogQL queries on structured JSON fields
- **Web Interface**: Easy visualization and searching through Grafana
- **Multi-Instance Support**: Run multiple stacks for different environments
- **Zero Application Changes**: Works by reading log files - no code integration required

## Advanced Configuration

## Viewing Logs in Grafana

1. **Access Grafana**: Go to `http://localhost:${GRAFANA_PORT}` (default: 3000)
2. **Navigate to Explore**: Click the compass icon (🧭) in the left sidebar
3. **Select Loki Data Source**: Ensure "Loki" is selected in the dropdown
4. **Query Your Logs**: Use these LogQL queries for different insights:

### Basic Queries
```logql
{job="quanta"}                          # All logs (replace "quanta" with your job name)
{job="quanta"} | json                   # Parse JSON structure
{job="quanta", level="error"}           # Error logs only
{job="quanta"} | json | level="warn"    # Warning logs
```

### HTTP Request Analysis
```logql
# All HTTP requests
{job="quanta"} | json | has("req")

# Error responses (4xx/5xx)
{job="quanta"} | json | res_statusCode >= 400

# Slow requests (response time > 100ms)
{job="quanta"} | json | responseTime > 100

# Specific endpoints
{job="quanta"} | json | req_method="POST"
{job="quanta"} | json | req_url =~ "/api/.*"

# Requests by status code
{job="quanta"} | json | res_statusCode="200"
```

### Advanced Filtering
```logql
# Combine multiple conditions
{job="quanta"} | json | req_method="GET" | res_statusCode >= 400

# Search in message content
{job="quanta"} |= "error" | json

# Exclude certain paths
{job="quanta"} | json | req_url !~ "/assets/.*"
```

5. **Adjust Time Range**: If needed, expand to "Last 24 hours" or "Last 7 days"

## Integration with Your Application

This stack only requires that your application writes JSON-formatted logs to files. There is **no runtime coupling** - the stack reads log files from the filesystem.

### For Node.js Applications (Example)

1. **Install Pino** for structured logging:
   ```bash
   npm install pino pino-pretty pino-http
   ```

2. **Configure Pino** in your application:
   ```javascript
   import pino from 'pino';
   import fs from 'fs';
   
   const logger = pino({
       level: 'info',
       formatters: {
           level: (label) => ({ level: label }),
       },
       timestamp: pino.stdTimeFunctions.isoTime
   }, pino.multistream([
       { stream: fs.createWriteStream('./logs/app.log', { flags: 'a' }) },
       { stream: process.stdout }
   ]));
   
   logger.info({ user: 'john' }, 'User logged in');
   ```

3. **Point Grafana Alloy** to your log directory:
   ```bash
   # In grafana-set-env.sh
   export GRAFANA_LOGS_SOURCE_DIR="/path/to/your/app/logs"
   ```

4. **Start the monitoring stack**:
   ```bash
   ./start.sh
   ```

That's it! Your application continues running normally, writing logs to files, and Grafana Alloy monitors those files.

## Customizing the Job Label

By default, logs are tagged with `job="quanta"`. To change this for your application:

1. Edit `config.alloy`
2. Find the line: `"__path__" = "/temp/logs/*.log", "job" = "quanta"`
3. Change `"quanta"` to your application name
4. Restart: `./restart.sh`

## Advanced Configuration

### Monitoring Multiple Log Directories

To monitor logs from multiple applications or directories:

1. Edit `config.alloy`
2. Add additional `local.file_match` and `loki.source.file` blocks:
   ```alloy
   local.file_match "app2_files" {
       path_targets = [{"__path__" = "/temp/logs2/*.log", "job" = "app2"}]
   }
   
   loki.source.file "app2_scrape" {
       targets = local.file_match.app2_files.targets
       forward_to = [loki.process.json_parser.receiver]
   }
   ```
3. Add the new directory to docker-compose.yml volumes
4. Restart: `./restart.sh`

### Customizing JSON Field Extraction

Edit the `loki.process "json_parser"` section in `config.alloy` to extract additional fields:

```alloy
stage.json {
    expressions = {
        level     = "level",
        timestamp = "time", 
        message   = "msg",
        pid       = "pid",
        hostname  = "hostname",
        user_id   = "userId",        // Add custom field
        request_id = "reqId",         // Add custom field
    }
}
```

### Changing Data Retention

Edit `loki-config.yaml` to change how long logs are stored:

```yaml
limits_config:
  retention_period: 168h  # Default is 7 days (168 hours)
```

### Performance Tuning

For high-volume logging, adjust these settings in `config.alloy`:

```alloy
loki.source.file "log_scrape" {
    targets = local.file_match.local_files.targets
    forward_to = [loki.process.json_parser.receiver]
    tail_from_end = true  // Only read new entries (skip historical)
}
```

## Troubleshooting

### Logs Not Appearing

1. **Check the log directory path**:
   ```bash
   echo $GRAFANA_LOGS_SOURCE_DIR
   ls -la $GRAFANA_LOGS_SOURCE_DIR
   ```

2. **Verify containers are running**:
   ```bash
   docker-compose ps
   ```

3. **Check Alloy logs**:
   ```bash
   docker logs alloy-dev  # or alloy-{your-env-suffix}
   ```

4. **Verify JSON format**: Ensure your logs are valid JSON (one object per line)

### Port Conflicts

If ports are already in use, edit `grafana-set-env.sh`:

```bash
export GRAFANA_PORT="3001"  # Change from default 3000
export LOKI_PORT="3101"     # Change from default 3100
```

Then restart: `./restart.sh --complete`

### Permission Issues

If you get permission errors:

```bash
# Fix data directory permissions
sudo chown -R $USER:$USER $GRAFANA_DB_BASE_DIR
```

## Contributing

This is a standalone monitoring project. Feel free to:
- Customize it for your specific use case
- Add additional Grafana dashboards
- Extend the Alloy configuration for your needs
- Share your improvements!

## License

MIT License - See LICENSE file for details

## Related Projects

This monitoring stack was originally created for the [Quanta Platform](https://github.com/Clay-Ferguson/quanta) but has been extracted as a standalone project for general use.

