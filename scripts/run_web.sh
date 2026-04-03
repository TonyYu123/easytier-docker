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
WEB_PORT=${WEB_PORT:-11211}
WEB_API_PORT=${WEB_API_PORT:-11211}
WEB_SERVER_PORT=${WEB_SERVER_PORT:-22020}
WEB_SERVER_PROTOCOL=${WEB_SERVER_PROTOCOL:-udp}
WEB_DEFAULT_API_HOST=${WEB_DEFAULT_API_HOST:-http://127.0.0.1:$WEB_API_PORT}
WEB_LOG_LEVEL=${WEB_LOG_LEVEL:-warn}
WEB_DATA_DIR=/app/data
# New environment variable for GeoIP database path
WEB_GEOIP_DIR=${WEB_GEOIP_DIR:-}

# Handle positional parameters for Core (if applicable in this context)
CORE_EXTRA_ARGS=()
if [ "$#" -gt 0 ]; then
  if [ "${1#-}" = "$1" ]; then
    log "[Core] Custom command detected: $*"
    exec "$@"
  else
    CORE_EXTRA_ARGS=("$@")
  fi
fi

# Ensure web log directory exists
mkdir -p "$WEB_DATA_DIR/logs"

# Handle positional parameters specifically for the Web process
WEB_EXTRA_ARGS=()
if [ "$#" -gt 0 ]; then
  if [ "${1#-}" = "$1" ]; then
    log "[Web] Custom command detected: $*"
    exec "$@"
  else
    WEB_EXTRA_ARGS=("$@")
  fi
fi

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
  --console-log-level "$WEB_LOG_LEVEL"
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

# Append extra command-line arguments if provided
if [ ${#WEB_EXTRA_ARGS[@]} -gt 0 ]; then
  WEB_ARGS+=("${WEB_EXTRA_ARGS[@]}")
fi

log "[Web] Executing command: $(format_cmd "$BINARY" "${WEB_ARGS[@]}")"

# Replace the shell process with the web binary
exec "$BINARY" "${WEB_ARGS[@]}"
