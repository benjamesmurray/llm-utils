#!/bin/bash

# Default model type
MODEL_TYPE=${1:-"gemma-26b-q5"}
RESULTS_DIR="/home/llm/utils/test/results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULT_FILE="$RESULTS_DIR/test_${MODEL_TYPE}_${TIMESTAMP}.md"

# Map MODEL_TYPE to ALIAS (matching launch-server.sh)
case $MODEL_TYPE in
  "gemma-26b-q5")
    ALIAS="gemma-4-26b-q5"
    ;;
  "gemma-26b-q4xl")
    ALIAS="gemma-4-26b-q4xl"
    ;;
  "gemma-31b-iq4")
    ALIAS="gemma-4-31b-iq4"
    ;;
  "gemma-31b-q4s")
    ALIAS="gemma-4-31b-q4s"
    ;;
  "qwen-27b")
    ALIAS="qwen-3.5-27b"
    ;;
  "qwen-35b")
    ALIAS="qwen-3.6-35b"
    ;;
  *)
    echo "Unknown model type: $MODEL_TYPE. Supported: gemma-26b-q5, gemma-31b-iq4, gemma-31b-q4s, qwen-27b, qwen-35b."
    exit 1
    ;;
esac

# Load environment variables
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

HOST=${SERVER_HOST:-"0.0.0.0"}
PORT=${MAIN_PORT:-"8085"}
KEY=${API_KEY:-"2250"}

# Create results directory if it doesn't exist
mkdir -p "$RESULTS_DIR"

echo "Running test for model: $MODEL_TYPE (alias: $ALIAS) on $HOST:$PORT..."

# Capture start time in nanoseconds
START_TIME=$(date +%s%N)

# Perform the curl request, capturing the raw stream
# We include "stream_options": {"include_usage": true} to get token counts if supported
MAX_TOKENS=4096
if [ "$MODEL_TYPE" == "qwen-35b" ]; then
    MAX_TOKENS=8192
fi

RAW_RESPONSE=$(curl -s http://$HOST:$PORT/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $KEY" \
  -d '{
    "model": "'"$ALIAS"'",
    "messages": [
      {"role": "system", "content": "You are a distinguished Principal Staff Software Engineer, an expert in distributed systems, high-performance computing, and polyglot programming."},
      {"role": "user", "content": "Implement a highly concurrent, thread-safe Token Bucket rate limiter algorithm. You MUST provide the full implementation in three distinct languages: 1) Kotlin (using Coroutines and Mutex/Atomic primitives), 2) Python (using asyncio), and 3) Rust (using Tokio and appropriate concurrency primitives). Pay extremely close attention to code quality, idiomatic naming conventions, precise indentation, absence of typos, and handling of edge cases, as these implementations will be rigorously evaluated for production readiness. Explain the concurrency trade-offs and primitives chosen in each language."}
    ],
    "stream": true,
    "max_tokens": '$MAX_TOKENS',
    "stream_options": {"include_usage": true}
  }')

# Capture end time in nanoseconds
END_TIME=$(date +%s%N)

# Calculate duration in seconds (with decimal)
DURATION_NS=$((END_TIME - START_TIME))
DURATION_SEC=$(echo "scale=3; $DURATION_NS / 1000000000" | bc)

# Extract content from the stream
# We filter out the [DONE] message and use jq to extract content deltas
# We capture both 'reasoning_content' and 'content' since some models output thinking phases
CONTENT=$(echo "$RAW_RESPONSE" | grep "^data: " | grep -v "data: \[DONE\]" | sed 's/^data: //' | jq -j '.choices[0].delta | (.reasoning_content // "") + (.content // "")' 2>/dev/null)

# Try to extract usage statistics (tokens)
# llama-server often sends usage in the last chunk when stream_options.include_usage is true
COMPLETION_TOKENS=$(echo "$RAW_RESPONSE" | grep "^data: " | grep -v "data: \[DONE\]" | sed 's/^data: //' | jq -r '.usage.completion_tokens // empty' | tail -n 1)

# If completion tokens not found, estimate (approx 4 chars per token)
if [ -z "$COMPLETION_TOKENS" ]; then
    CHAR_COUNT=$(echo -n "$CONTENT" | wc -c)
    COMPLETION_TOKENS=$((CHAR_COUNT / 4))
    ESTIMATED=" (Estimated)"
else
    ESTIMATED=""
fi

# Calculate TPS
if (( $(echo "$DURATION_SEC > 0" | bc -l) )); then
    TPS=$(echo "scale=2; $COMPLETION_TOKENS / $DURATION_SEC" | bc)
else
    TPS="N/A"
fi

# Save to Markdown file
cat <<EOF > "$RESULT_FILE"
# Test Results: $MODEL_TYPE ($ALIAS)
**Date:** $(date)
**Duration:** ${DURATION_SEC}s
**Tokens:** ${COMPLETION_TOKENS}${ESTIMATED}
**TPS:** ${TPS} tokens/sec

## System Prompt
You are a distinguished Principal Staff Software Engineer, an expert in distributed systems, high-performance computing, and polyglot programming.

## User Prompt
Implement a highly concurrent, thread-safe Token Bucket rate limiter algorithm. You MUST provide the full implementation in three distinct languages: 1) Kotlin (using Coroutines and Mutex/Atomic primitives), 2) Python (using asyncio), and 3) Rust (using Tokio and appropriate concurrency primitives). Pay extremely close attention to code quality, idiomatic naming conventions, precise indentation, absence of typos, and handling of edge cases, as these implementations will be rigorously evaluated for production readiness. Explain the concurrency trade-offs and primitives chosen in each language.

## Model Output
$CONTENT

## Quality Assessment
- **Performance:** $TPS TPS
- **Response Length:** $(echo -n "$CONTENT" | wc -w) words
- **Status:** Complete

---
*Raw output saved for verification.*
EOF

echo "Test complete. Results saved to: $RESULT_FILE"
echo "Performance: $TPS TPS"
