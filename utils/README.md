# LLM Utilities: Launchers & Evaluation Frameworks

This directory contains a suite of tools for managing `llama.cpp` server instances and running automated performance/quality evaluations.

## 📂 Directory Structure

```
utils/
├── launch/             # Server startup scripts
│   ├── launch-server.sh    # Standalone model launcher
│   ├── launch-dual.sh      # Dual-model (Main + Clerk) launcher
│   └── logs/               # Server stdout/stderr logs
└── test/               # Evaluation frameworks
    ├── framework/          # Standard evaluation (Single model)
    ├── combined_framework/ # "Baton Pass" evaluation (Dual model)
    ├── data_clerk_framework/# Specialized data processing tests
    ├── results/            # Markdown reports from test runs
    └── env_loader.py       # Shared utility for .env configuration
```

## ⚙️ Configuration

The system uses a centralized `.env` file in the project root for privacy and flexibility.

**Required `.env` variables:**
- `API_KEY`: The bearer token for API authentication (default: `2250`).
- `SERVER_HOST`: The host address (default: `0.0.0.0`).
- `MAIN_PORT`: Port for the primary model (default: `8085`).
- `SIDE_PORT`: Port for the secondary/clerk model (default: `8086`).

## 🚀 Launchers (`utils/launch/`)

### 1. Standalone Launcher
Starts a single `llama-server` instance.
```bash
# Usage: ./launch-server.sh [model_type] [port]
./utils/launch/launch-server.sh qwen-35b 8085
```
Supported models: `gemma-26b-q5`, `gemma-26b-q4xl`, `qwen-35b` (Qwen 3.6), `nemotron-4b`, etc.

### 2. Dual-Model Launcher
Starts two servers simultaneously (Main model on `MAIN_PORT`, Nemotron-4B on `SIDE_PORT`).
```bash
# Usage: ./launch-dual.sh [main_model_type]
./utils/launch/launch-dual.sh qwen-35b
```

## 🧪 Evaluation Frameworks (`utils/test/`)

### 1. The "Baton Pass" Workflow (`combined_framework`)
This is the most advanced evaluation suite. It simulates a production pipeline where a small, fast model (Clerk) handles pre/post-processing, and a large model (Main) handles core logic.

**Phases:**
1.  **Pre-Generation (Clerk)**: JSON compression and payload sanitization.
2.  **Generation (Main)**: Complex coding tasks (e.g., Token Bucket implementation).
3.  **Post-Generation (Clerk)**: Persistence extraction and summarization.

**Run it:**
```bash
python3 utils/test/combined_framework/main.py
```

### 2. Standard Evaluation (`framework`)
Evaluates a single model against a variety of coding and linting prompts.
```bash
python3 utils/test/framework/main.py [model_key]
```

## 📊 Metrics Captured

Every evaluation generates a Markdown report in `utils/test/results/` or `utils/test/combined_results/` including:
- **TPS (Tokens Per Second)**: Raw generation speed.
- **TTFT (Time to First Token)**: Responsiveness latency.
- **Token Count**: Total tokens generated.
- **Status**: Completion or failure (with error logs).
- **Thinking Process**: For models like Qwen 3.6, the internal Chain-of-Thought is preserved and logged.

## 🛠️ Adding New Models
1.  Add the GGUF path and alias to `utils/launch/launch-server.sh`.
2.  Add the model metadata (context size, threads, flags) to the `models.json` in the relevant framework directory.

---
*Note: All launchers automatically handle cleanup of existing `llama-server` instances before starting.*
