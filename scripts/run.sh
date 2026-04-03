#!/bin/bash
# Exit immediately if a command exits with a non-zero status
set -e

# Function for logging with timestamps
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Function to format commands safely for log output
format_cmd() {
  local cmd=$1
  shift || true
  printf '%s' "$cmd"
  local arg
  for arg in "$@"; do
    printf ' %q' "$arg"
  done
}

# Default configuration values
WEB_ENABLE=${WEB_ENABLE:-false}
WEB_REMOTE_API=${WEB_REMOTE_API:-}
WEB_USERNAME=${WEB_USERNAME:-}
WEB_PORT=${WEB_PORT:-11211}
WEB_API_PORT=${WEB_API_PORT:-11211}
WEB_SERVER_PORT=${WEB_SERVER_PORT:-22020}
WEB_SERVER_PROTOCOL=${WEB_SERVER_PROTOCOL:-udp}
WEB_DEFAULT_API_HOST=${WEB_DEFAULT_API_HOST:-http://127.0.0.1:$WEB_API_PORT}
WEB_LOG_LEVEL=${WEB_LOG_LEVEL:-warn}
WEB_DATA_DIR=/app/data
CONFIG_DIR=/app/data/config
# New environment variable for GeoIP database path
WEB_GEOIP_DIR=${WEB_GEOIP_DIR:-}

# Handle positional parameters from command line (e.g., docker-compose command)
CORE_EXTRA_ARGS=()
if [ "$#" -gt 0 ]; then
  # If the first argument doesn't start with '-', treat it as a custom command
  if [ "${1#-}" = "$1" ]; then
    log "[Core] Custom command detected: $*"
    exec "$@"
  else
    # Store arguments starting with '-' as extra arguments for the core
    CORE_EXTRA_ARGS=("$@")
  fi
fi

# Start Web Management Interface if enabled
if [ "$WEB_ENABLE" = "true" ]; then
  # Ensure necessary data and log directories exist
  mkdir -p "$WEB_DATA_DIR/logs"
  mkdir -p "$CONFIG_DIR"
  log "[Web] Starting easytier-web-embed..."
  
  # Check if the web binary is available in the system PATH
  if command -v easytier-web-embed &> /dev/null; then
    BINARY=easytier-web-embed
  else
    log "[Web] Error: easytier-web-embed binary not found."
    exit 1
  fi

  # Determine the API URL based on protocol presence
  if [[ "$WEB_DEFAULT_API_HOST" == http* ]]; then
    API_URL="$WEB_DEFAULT_API_HOST"
  else
    # Default to http and append the specified API port
    API_URL="http://$WEB_DEFAULT_API_HOST:$WEB_API_PORT"
  fi
  
  log "[Web] Using API URL: $API_URL"

  # Construct arguments for the web process
  WEB_ARGS=(
    -d "$WEB_DATA_DIR/et.db"
    --file-log-level "$WEB_LOG_LEVEL"
    --file-log-dir "$WEB_DATA_DIR/logs"
    -c "$WEB_SERVER_PORT"
    -p "$WEB_SERVER_PROTOCOL"
    -a "$WEB_API_PORT"
    -l "$WEB_PORT"
    --api-host "$API_URL"
  )

  # Append GeoIP database argument if the environment variable is set
  if [ -n "$WEB_GEOIP_DIR" ]; then
    WEB_ARGS+=("--geoip-db" "$WEB_GEOIP_DIR")
  fi

  log "[Web] Executing command: $(format_cmd "$BINARY" "${WEB_ARGS[@]}")"

  # Run the web process in the background. CORE_EXTRA_ARGS are NOT passed here.
  $BINARY "${WEB_ARGS[@]}" &

  WEB_PID=$!
  log "[Web] easytier-web-embed started with PID $WEB_PID"
fi

log "[Core] Starting easytier-core..."

# Construct arguments for the core process
ARGS=()

if [ "$WEB_ENABLE" = "true" ]; then
  ARGS+=("--config-dir" "$CONFIG_DIR")
  
  # Configure web connection for the core
  if [ -n "$WEB_REMOTE_API" ]; then
      # Connect to a remote web console if specified
      ARGS+=("-w" "$WEB_REMOTE_API")
  elif [ -n "$WEB_USERNAME" ]; then
      # Connect to the local web console using specified username
      ARGS+=("-w" "$WEB_SERVER_PROTOCOL://127.0.0.1:$WEB_SERVER_PORT/$WEB_USERNAME")
  fi
fi

# Generate or load a persistent Machine ID for identification
if [ "$WEB_ENABLE" = "true" ] || [ -n "$WEB_REMOTE_API" ]; then
  MACHINE_ID_FILE="$WEB_DATA_DIR/et_machine_id"
  if [ ! -f "$MACHINE_ID_FILE" ]; then
      log "[Core] Generating new machine ID..."
      cat /proc/sys/kernel/random/uuid > "$MACHINE_ID_FILE"
  fi
  MACHINE_ID=$(cat "$MACHINE_ID_FILE")
  log "[Core] Using machine ID: $MACHINE_ID"
  ARGS+=("--machine-id" "$MACHINE_ID")
fi

# Log the final command before replacing the shell process
log "[Core] Executing command: $(format_cmd easytier-core "${ARGS[@]}" "${CORE_EXTRA_ARGS[@]}")"

# Execute the core process as PID 1, passing the extra command-line arguments
exec easytier-core "${ARGS[@]}" "${CORE_EXTRA_ARGS[@]}"
