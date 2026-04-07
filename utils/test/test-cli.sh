#!/bin/bash
../../llama.cpp/build/bin/llama-cli -hf unsloth/gemma-4-26B-A4B-it-GGUF:UD-Q4_K_M \
  -p "Describe the most interesting thing about the history of computers in one sentence." \
  -ngl 99 \
  -fa on \
  -c 4096 \
  -t 12 \
  -n -1
