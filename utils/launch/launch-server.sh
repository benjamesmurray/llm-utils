#!/bin/bash

# Default model
MODEL_TYPE=${1:-"gemma-26b-q5"}
LOG_DIR="/home/llm/utils/launch/logs"
mkdir -p "$LOG_DIR"

# Path to the llama-server binary
SERVER_BIN="/home/llm/llama.cpp/build/bin/llama-server"

# Model paths and aliases
CONTEXT_SIZE=81920
GPU_LAYERS=99
KV_FLAGS=""

case $MODEL_TYPE in
  "gemma-26b-q5")
    MODEL_PATH="/home/llm/downloads/gemma/gemma-4-26B-A4B-it-UD-Q5_K_M.gguf"
    ALIAS="gemma-4-26b-q5"
    CONTEXT_SIZE=72768
    KV_FLAGS="-ctk q8_0 -ctv q8_0"
    ;;
  "gemma-31b-iq4")
    MODEL_PATH="/home/llm/downloads/gemma/gemma-4-31B-it-IQ4_NL.gguf"
    ALIAS="gemma-4-31b-iq4"
    KV_FLAGS="-ctk q8_0 -ctv q8_0"
    CONTEXT_SIZE=32768
    ;;
  "gemma-31b-q4s")
    MODEL_PATH="/home/llm/downloads/gemma/gemma-4-31B-it-Q4_K_S.gguf"
    ALIAS="gemma-4-31b-q4s"
    KV_FLAGS="-ctk q8_0 -ctv q8_0"
    CONTEXT_SIZE=32768
    ;;
  "qwen-27b")
    MODEL_PATH="/home/llm/downloads/qwen/Qwen3.5-27B-Q5_K_M.gguf"
    ALIAS="qwen-3.5-27b"
    ;;
  *)
    echo "Unknown model type: $MODEL_TYPE. Supported: gemma-26b-q5, gemma-31b-iq4, gemma-31b-q4s, qwen-27b."
    exit 1
    ;;
esac

# Stop any running llama-server
echo "Stopping existing llama-server instances..."
killall -9 llama-server 2>/dev/null
sleep 1

# Launch the server
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/${MODEL_TYPE}_${TIMESTAMP}.log"

echo "Starting $MODEL_TYPE server (Context: $CONTEXT_SIZE, Layers: $GPU_LAYERS)..."
echo "Logging to: $LOG_FILE"

# Run in background and redirect output
$SERVER_BIN \
  -m "$MODEL_PATH" \
  -ngl $GPU_LAYERS \
  -fa on \
  $KV_FLAGS \
  -c $CONTEXT_SIZE \
  -t 12 \
  --host 0.0.0.0 --port 8085 \
  --alias "$ALIAS" \
  --jinja \
  --metrics \
  --api-key "2250" \
  --verbose > "$LOG_FILE" 2>&1 &

# Wait for server to be ready
echo "Waiting for server to initialize..."
for i in {1..120}; do
  if curl -s http://localhost:8085/v1/models | grep -q "$ALIAS"; then
    echo "Server is UP and ready."
    exit 0
  fi
  sleep 2
done

echo "Error: Server failed to start within 120 seconds. Check logs at: $LOG_FILE"
exit 1
