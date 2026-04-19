#!/bin/bash

# Default model and port
MODEL_TYPE=${1:-"gemma-26b-q5"}
PORT=${2:-"8085"}
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
  "gemma-26b-q4xl")
    MODEL_PATH="/home/llm/downloads/gemma/gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf"
    ALIAS="gemma-4-26b-q4xl"
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
  "qwen-35b")
    MODEL_PATH="/home/llm/downloads/qwen/Qwen3.6-35B-A3B-UD-IQ4_NL.gguf"
    ALIAS="qwen-3.6-35b"
    CHAT_TEMPLATE_KWARGS='{"preserve_thinking": true}'
    ;;
  "nemotron-4b")
    MODEL_PATH="/home/llm/downloads/nemotron/NVIDIA-Nemotron-3-Nano-4B-IQ4_NL.gguf"
    ALIAS="nemotron-3-nano-4b"
    CONTEXT_SIZE=32768
    KV_FLAGS="-ctk q8_0 -ctv q8_0"
    ;;
  *)
    echo "Unknown model type: $MODEL_TYPE. Supported: gemma-26b-q5, gemma-26b-q4xl, gemma-31b-iq4, gemma-31b-q4s, qwen-27b, qwen-35b, nemotron-4b."
    exit 1
    ;;

  esac

  # Launch the server
  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  LOG_FILE="$LOG_DIR/${MODEL_TYPE}_${TIMESTAMP}.log"

  echo "Starting $MODEL_TYPE server (Context: $CONTEXT_SIZE, Layers: $GPU_LAYERS)..."
  echo "Logging to: $LOG_FILE"

  # Run in background and redirect output
  if [ -n "$CHAT_TEMPLATE_KWARGS" ]; then
    $SERVER_BIN \
      -m "$MODEL_PATH" \
      -ngl $GPU_LAYERS \
      -fa on \
      $KV_FLAGS \
      -c $CONTEXT_SIZE \
      -t 12 \
      --host "$HOST" --port "$PORT" \
      --alias "$ALIAS" \
      --jinja \
      --chat-template-kwargs "$CHAT_TEMPLATE_KWARGS" \
      --metrics \
      --api-key "$KEY" \
      --verbose > "$LOG_FILE" 2>&1 &
  else
    $SERVER_BIN \
      -m "$MODEL_PATH" \
      -ngl $GPU_LAYERS \
      -fa on \
      $KV_FLAGS \
      -c $CONTEXT_SIZE \
      -t 12 \
      --host "$HOST" --port "$PORT" \
      --alias "$ALIAS" \
      --jinja \
      --metrics \
      --api-key "$KEY" \
      --verbose > "$LOG_FILE" 2>&1 &
  fi


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
