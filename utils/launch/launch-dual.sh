#!/bin/bash

# Default main model
MAIN_MODEL_TYPE=${1:-"gemma-26b"}
LOG_DIR="/home/llm/utils/launch/logs"
mkdir -p "$LOG_DIR"

SERVER_BIN="/home/llm/llama.cpp/build/bin/llama-server"

# Stop any running llama-server
echo "Stopping existing llama-server instances..."
killall -9 llama-server 2>/dev/null
sleep 1

TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Main Model Configuration
case $MAIN_MODEL_TYPE in
  "gemma-26b")
    MAIN_MODEL_PATH="/home/llm/downloads/gemma/gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf"
    MAIN_ALIAS="gemma-4-26b-q4-xl"
    MAIN_CONTEXT=32768
    MAIN_EXTRA_ARGS=""
    ;;
  "qwen-35b")
    MAIN_MODEL_PATH="/home/llm/downloads/qwen/Qwen3.6-35B-A3B-UD-IQ4_NL.gguf"
    MAIN_ALIAS="qwen-3.6-35b"
    MAIN_CONTEXT=32768
    MAIN_CHAT_TEMPLATE_KWARGS='{"preserve_thinking": true}'
    ;;
  *)
    echo "Unknown main model type: $MAIN_MODEL_TYPE. Supported: gemma-26b, qwen-35b."
    exit 1
    ;;
esac

MAIN_PORT_VAR=$PORT_MAIN
MAIN_LOG="$LOG_DIR/dual_main_${TIMESTAMP}.log"

echo "Starting Main Model ($MAIN_ALIAS) on Port $MAIN_PORT_VAR..."
if [ -n "$MAIN_CHAT_TEMPLATE_KWARGS" ]; then
  $SERVER_BIN \
    -m "$MAIN_MODEL_PATH" \
    -ngl 99 \
    -fa on \
    -ctk q8_0 -ctv q8_0 \
    -c $MAIN_CONTEXT \
    -t 12 \
    --host "$HOST" --port "$MAIN_PORT_VAR" \
    --alias "$MAIN_ALIAS" \
    --jinja \
    --chat-template-kwargs "$MAIN_CHAT_TEMPLATE_KWARGS" \
    --metrics \
    --api-key "$KEY" \
    --verbose > "$MAIN_LOG" 2>&1 &
else
  $SERVER_BIN \
    -m "$MAIN_MODEL_PATH" \
    -ngl 99 \
    -fa on \
    -ctk q8_0 -ctv q8_0 \
    -c $MAIN_CONTEXT \
    -t 12 \
    --host "$HOST" --port "$MAIN_PORT_VAR" \
    --alias "$MAIN_ALIAS" \
    --jinja \
    --metrics \
    --api-key "$KEY" \
    --verbose > "$MAIN_LOG" 2>&1 &
fi

# 2. Side Model: Nemotron-3-Nano-4B (IQ4_NL)
SIDE_MODEL_PATH="/home/llm/downloads/nemotron/NVIDIA-Nemotron-3-Nano-4B-IQ4_NL.gguf"
SIDE_ALIAS="nemotron-3-nano-4b"
SIDE_PORT_VAR=$PORT_SIDE
SIDE_CONTEXT=32768
SIDE_LOG="$LOG_DIR/dual_side_${TIMESTAMP}.log"

echo "Starting Side Model ($SIDE_ALIAS) on Port $SIDE_PORT_VAR..."
$SERVER_BIN \
  -m "$SIDE_MODEL_PATH" \
  -ngl 99 \
  -fa on \
  -ctk q8_0 -ctv q8_0 \
  -c $SIDE_CONTEXT \
  -t 4 \
  --host "$HOST" --port "$SIDE_PORT_VAR" \
  --alias "$SIDE_ALIAS" \
  --jinja \
  --metrics \
  --api-key "$KEY" \
  --verbose > "$SIDE_LOG" 2>&1 &

# Wait for both servers to initialize
echo "Waiting for servers to initialize on $HOST..."
MAIN_READY=0
SIDE_READY=0

for i in {1..120}; do
  if [ $MAIN_READY -eq 0 ] && curl -s http://$HOST:$MAIN_PORT_VAR/v1/models | grep -q "$MAIN_ALIAS"; then
    echo "Main Model (Port $MAIN_PORT_VAR) is UP and ready."
    MAIN_READY=1
  fi
  
  if [ $SIDE_READY -eq 0 ] && curl -s http://$HOST:$SIDE_PORT_VAR/v1/models | grep -q "$SIDE_ALIAS"; then
    echo "Side Model (Port $SIDE_PORT_VAR) is UP and ready."
    SIDE_READY=1
  fi

  if [ $MAIN_READY -eq 1 ] && [ $SIDE_READY -eq 1 ]; then
    echo "Both servers are UP and ready."
    exit 0
  fi
  
  sleep 2
done

echo "Error: One or both servers failed to start within 120 seconds."
echo "Check logs at: $MAIN_LOG and $SIDE_LOG"
exit 1
 fi
  
  sleep 2
done

echo "Error: One or both servers failed to start within 120 seconds."
echo "Check logs at: $MAIN_LOG and $SIDE_LOG"
exit 1
