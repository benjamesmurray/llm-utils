#!/bin/bash

# Default model and port
MODEL_TYPE=${1:-"gemma-26b-q5"}
DEFAULT_PORT=${2:-"8085"}
LOG_DIR="/home/llm/utils/launch/logs"
mkdir -p "$LOG_DIR"

# Load environment variables
if [ -f .env ]; then
  # Simple env loading
  export $(grep -v '^#' .env | xargs)
fi

HOST=${SERVER_HOST:-"0.0.0.0"}
PORT=${DEFAULT_PORT:-${MAIN_PORT:-"8085"}}
KEY=${API_KEY:-""}

# Path to the llama-server binary
SERVER_BIN="/home/llm/llama.cpp/build/bin/llama-server"
CONFIG_FILE="/home/llm/utils/test/framework/models.json"

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. It is required for parsing config files."
    exit 1
fi

# Load model data from JSON
MODEL_DATA=$(jq -r --arg MODEL "$MODEL_TYPE" '.[$MODEL] | select(. != null)' "$CONFIG_FILE")

if [ -z "$MODEL_DATA" ]; then
    echo "Unknown model type: $MODEL_TYPE. Please check $CONFIG_FILE."
    exit 1
fi

# Extract variables from JSON
MODEL_PATH=$(echo "$MODEL_DATA" | jq -r '.path')
ALIAS=$(echo "$MODEL_DATA" | jq -r '.alias')
CONTEXT_SIZE=$(echo "$MODEL_DATA" | jq -r '.context_size // 81920')
GPU_LAYERS=$(echo "$MODEL_DATA" | jq -r '.gpu_layers // 99')
KV_FLAGS=$(echo "$MODEL_DATA" | jq -r '.kv_flags // ""')
THREADS=$(echo "$MODEL_DATA" | jq -r '.threads // 12')
N_PARALLEL=$(echo "$MODEL_DATA" | jq -r '.n_parallel // empty')
EXTRA_FLAGS=$(echo "$MODEL_DATA" | jq -r '.extra_flags // ""')
CHAT_TEMPLATE_KWARGS=$(echo "$MODEL_DATA" | jq -r '.chat_template_kwargs // empty')

# Launch the server
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/${MODEL_TYPE}_${TIMESTAMP}.log"

echo "Starting $MODEL_TYPE server (Context: $CONTEXT_SIZE, Layers: $GPU_LAYERS)..."
echo "Logging to: $LOG_FILE"

# Prepare launch command
CMD=("$SERVER_BIN" \
  -m "$MODEL_PATH" \
  -ngl "$GPU_LAYERS" \
  -fa on \
  -c "$CONTEXT_SIZE" \
  -t "$THREADS" \
  --host "$HOST" --port "$PORT" \
  --alias "$ALIAS" \
  --jinja \
  --metrics \
  --api-key "$KEY" \
  --verbose)

# Add optional flags
if [ -n "$N_PARALLEL" ]; then
  CMD+=("-np" "$N_PARALLEL")
fi

if [ -n "$KV_FLAGS" ]; then
  # Split KV_FLAGS into separate arguments
  read -ra FLAGS <<< "$KV_FLAGS"
  CMD+=("${FLAGS[@]}")
fi

if [ -n "$EXTRA_FLAGS" ]; then
  # Split EXTRA_FLAGS into separate arguments
  read -ra EFLAGS <<< "$EXTRA_FLAGS"
  CMD+=("${EFLAGS[@]}")
fi

if [ -n "$CHAT_TEMPLATE_KWARGS" ]; then
  CMD+=(--chat-template-kwargs "$CHAT_TEMPLATE_KWARGS")
fi

# Run in background and redirect output
nohup "${CMD[@]}" > "$LOG_FILE" 2>&1 &
disown


# Wait for server to be ready
echo "Waiting for server to initialize on $HOST:$PORT..."
for i in {1..120}; do
  if curl -s http://$HOST:$PORT/v1/models | grep -q "$ALIAS"; then
    echo "Server is UP and ready."
    exit 0
  fi
  sleep 2
done

echo "Error: Server failed to start within 120 seconds. Check logs at: $LOG_FILE"
exit 1
ep -q "$ALIAS"; then
    echo "Server is UP and ready."
    exit 0
  fi
  sleep 2
done

echo "Error: Server failed to start within 120 seconds. Check logs at: $LOG_FILE"
exit 1
