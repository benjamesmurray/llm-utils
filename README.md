# LLM Performance & Evaluation Suite

This repository contains tools and scripts for launching, managing, and evaluating LLM performance on local hardware, specifically optimized for high-context MoE models like **Qwen-3.6-35B-A3B**.

## 🚀 Unified Dual-Model Architecture

The environment uses a **transparent proxy (`llama-swap`)** to manage multiple models through a single API endpoint. This provides an automatic "hot-swap" capability while maximizing VRAM utilization.

*   **API Endpoint:** `http://localhost:8085/v1`
*   **Proxy Dashboard:** `http://localhost:8085/ui`
*   **Architecture:** Single Port, Multi-Model (SWAP Approach)

### Available Models
| Model ID | Base Model | Context | Key Features |
| :--- | :--- | :--- | :--- |
| **`qwen3.6-35b-a3b-coding`** | Qwen-3.6-35B-A3B | 64k | Thinking/Reasoning, Optimized for Coding |
| **`nemotron-3-nano`** | Nemotron-3-Nano-4B | 32k | Fast Data Processing & Summarization |

---

## 🛠️ Management Tools

### Launching the Stack
To start or restart the dual-model infrastructure:
```bash
/home/llm/utils/launch/launch-dual.sh
```
This script stops existing instances, starts the `llama-swap` proxy, and configures the optimized model parameters (KV cache `q8_0`, `mlock`, and memory-fitting).

### Model Configuration
The single source of truth for model parameters is:
*   **Proxy Config:** `/home/llm/utils/launch/llama-swap.yaml`
*   **Test Framework Config:** `/home/llm/utils/test/framework/models.json`

---

## 📊 Evaluation Frameworks

### 1. Sequential 'Baton Pass' Test
Evaluates a complex workflow involving pre-generation (clerk), main generation (coding), and post-generation (clerk) phases.
```bash
python3 /home/llm/utils/test/combined_framework/main_router.py
```
*   **Result Location:** `/home/llm/utils/test/combined_results/`

### 2. General Model Evals
Runs a suite of linting and coding challenges across one or more models.
```bash
# Example: Run all models defined in run_all_evals.sh
/home/llm/utils/test/run_all_evals.sh
```

---

## 📖 Documentation
For detailed information on integrating your own applications (like a coding CLI) with this unified API, please refer to:
*   **[Developer Guide: Dual-Model Integration](./docs/dual_guide.md)**

---

## ⚙️ Recent Infrastructure Updates
- **`llama.cpp` Core:** Updated to latest master with Jinja template and Reasoning support.
- **Custom Metrics:** Re-integrated surgical patches for `/metrics` endpoints.
- **Performance:** Optimized Qwen-35B to reach ~185 TPS at 64k context in Swap mode.
- **Stability:** Implemented `llama-swap` to prevent VRAM overflow in dual-model scenarios.
