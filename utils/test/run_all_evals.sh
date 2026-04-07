#!/bin/bash
RESULTS_DIR="/home/llm/utils/test/results"

for MODEL in gemma-26b-q5 gemma-31b-iq4 gemma-31b-q4s qwen-27b; do
  echo "=== Evaluating $MODEL ==="
  
  case $MODEL in
    "gemma-26b-q5") ALIAS="gemma-4-26b-q5" ;;
    "gemma-31b-iq4") ALIAS="gemma-4-31b-iq4" ;;
    "gemma-31b-q4s") ALIAS="gemma-4-31b-q4s" ;;
    "qwen-27b") ALIAS="qwen-3.5-27b" ;;
  esac

  # Ensure completely clean state
  killall -9 llama-server 2>/dev/null
  sleep 3
  
  /home/llm/utils/launch/launch-server.sh $MODEL > /dev/null 2>&1 &
  
  READY=false
  echo "Waiting for API to become responsive with $ALIAS..."
  for i in {1..90}; do
    if curl -s http://localhost:8085/v1/models | grep -q "$ALIAS"; then
      echo "Server API is up."
      READY=true
      break
    fi
    sleep 2
  done
  
  if [ "$READY" = "true" ]; then
    echo "Giving the model 15 seconds to settle in VRAM/RAM before evaluation..."
    sleep 15
    echo "Running test..."
    timeout 600s /home/llm/utils/test/test-coding-endpoint.sh $MODEL
  else
    echo "Error: Server failed to initialize $MODEL in time."
  fi
  echo "----------------------------------------"
done
