#!/bin/bash

# Load environment variables
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
elif [ -f ../../.env ]; then
  export $(grep -v '^#' ../../.env | xargs)
fi

# Configuration
PORT=${MAIN_PORT:-"8085"}
HOST=${SERVER_HOST:-"0.0.0.0"}
KEY=${API_KEY:-""}
LOG_DIR="/home/llm/utils/launch/logs"
mkdir -p "$LOG_DIR"

SWAP_BIN="/home/llm/utils/launch/llama-swap"
CONFIG_FILE="/home/llm/utils/launch/llama-swap.yaml"

# Stop any running llama-server or llama-swap
echo "Stopping existing instances..."
killall -9 llama-server llama-swap 2>/dev/null
sleep 2

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/llama_swap_${TIMESTAMP}.log"

echo "Starting llama-swap Proxy on $HOST:$PORT..."
echo "Configuration: $CONFIG_FILE"
echo "Approach: SWAP (Single Model at a time)"
echo "Logging to: $LOG_FILE"

# Launch llama-swap
nohup "$SWAP_BIN" --listen "$HOST:$PORT" --config "$CONFIG_FILE" > "$LOG_FILE" 2>&1 &

disown

# Wait for proxy to be ready
echo "Waiting for proxy to initialize..."
for i in {1..30}; do
  if curl -s http://$HOST:$PORT/health | grep -q "ok" || curl -s http://$HOST:$PORT/ui > /dev/null; then
    echo "llama-swap Proxy is UP and ready."
    echo "Dashboard available at: http://$HOST:$PORT/ui"
    exit 0
  fi
  sleep 2
done

echo "Warning: llama-swap check timed out. Check logs at: $LOG_FILE"
