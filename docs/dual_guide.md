# Developer Guide: Dual-Model Integration with llama-swap

This guide describes how to configure and use the unified API endpoint to switch between the **Qwen-35B (Coding)** and **Nemotron-4B (Clerk)** models dynamically.

## 1. Unified Architecture
Instead of managing two separate URLs and ports, all models are now served through a transparent proxy (**llama-swap**) on a single port.

*   **API Endpoint:** `http://<host>:8085/v1`
*   **Protocol:** OpenAI / Anthropic Compatible
*   **Authentication:** Requires your standard API Key (e.g., `Bearer 2250`)

## 2. How Model Switching Works
Model switching is handled **lazily** and **automatically** by the proxy. You do not need to restart any services; simply change the `model` field in your API request payload.

### Available Model IDs
Use these exact strings in your `model` parameter:
1.  **`qwen3.6-35b-a3b-coding`**: Optimized for high-precision coding (64k context, thinking enabled).
2.  **`nemotron-3-nano`**: Optimized for data tasks, sanitization, and summarization (32k context).

## 3. Client Implementation

### Example: OpenAI Python Client
```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8085/v1",
    api_key="2250"
)

# Call the Coding Model
coding_response = client.chat.completions.create(
    model="qwen3.6-35b-a3b-coding",
    messages=[{"role": "user", "content": "Write a FastAPI rate limiter."}]
)

# Call the Clerk Model (Proxy handles the swap automatically)
clerk_response = client.chat.completions.create(
    model="nemotron-3-nano",
    messages=[{"role": "user", "content": "Sanitize this log output..."}]
)
```

### Example: cURL
```bash
# To get the Coding model:
curl http://localhost:8085/v1/chat/completions \
  -H "Authorization: Bearer 2250" \
  -d '{
    "model": "qwen3.6-35b-a3b-coding",
    "messages": [...]
  }'

# To get the Clerk model:
curl http://localhost:8085/v1/chat/completions \
  -H "Authorization: Bearer 2250" \
  -d '{
    "model": "nemotron-3-nano",
    "messages": [...]
  }'
```

## 4. Key Performance Considerations

### The "Cold Start" (Swap Delay)
Because this environment uses the **SWAP approach** to maximize VRAM for high-context models, only one model is active at a time.
*   If you request a model that is already running, the response is **instant**.
*   If you request a model that is *not* running, the proxy will stop the current model and load the new one. This adds a **15–20 second delay** (cold start) to the first request.

### Context Persistence
The proxy maintains a long TTL (Time-to-Live). A model will stay in VRAM for **60 minutes** of inactivity before being automatically unloaded to free up resources.

## 5. Management & Monitoring
You can monitor the status of the proxy and see which model is currently "hot" via the built-in dashboard:
*   **URL:** `http://localhost:8085/ui`

To start or restart the entire dual-model stack:
```bash
/home/llm/utils/launch/launch-dual.sh
```
