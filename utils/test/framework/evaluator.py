import json
import time
import urllib.request
import urllib.error
import os
import sys

# Add the parent directory to sys.path to find env_loader
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from env_loader import get_env

class Evaluator:
    def __init__(self, port=None):
        self.port = port or int(get_env("MAIN_PORT", 8085))
        self.host = get_env("SERVER_HOST", "0.0.0.0")
        self.api_key = get_env("API_KEY", "2250")
        
    def run_test(self, model_alias, test_case):
        url = f"http://{self.host}:{self.port}/v1/chat/completions"
        
        payload = {
            "model": model_alias,
            "messages": [
                {"role": "system", "content": test_case['system_prompt']},
                {"role": "user", "content": test_case['user_prompt']}
            ],
            "stream": True,
            "max_tokens": 4096,
            "stream_options": {"include_usage": True}
        }
        
        data = json.dumps(payload).encode('utf-8')
        req = urllib.request.Request(url, data=data, headers={
            'Content-Type': 'application/json',
            'Authorization': f'Bearer {self.api_key}'
        })
        
        print(f"Running test: {test_case['name']}...")
        
        start_time = time.time()
        time_to_first_token = None
        content = ""
        completion_tokens = 0
        completion_tokens_received = False
        
        try:
            with urllib.request.urlopen(req, timeout=300) as response:
                for line in response:
                    line = line.decode('utf-8').strip()
                    if line.startswith("data: "):
                        if time_to_first_token is None:
                            time_to_first_token = time.time() - start_time
                            
                        data_str = line[6:]
                        if data_str == "[DONE]":
                            break
                            
                        try:
                            chunk = json.loads(data_str)
                            
                            # Extract usage if present
                            if "usage" in chunk and chunk["usage"]:
                                completion_tokens = chunk["usage"].get("completion_tokens", completion_tokens)
                                completion_tokens_received = True
                                
                            # Extract content
                            if "choices" in chunk and len(chunk["choices"]) > 0:
                                delta = chunk["choices"][0].get("delta", {})
                                r_content = delta.get("reasoning_content") or ""
                                n_content = delta.get("content") or ""
                                if r_content or n_content:
                                    content += r_content
                                    content += n_content
                                    if not completion_tokens_received:
                                        completion_tokens += 1
                                    # Visual progress for long tests
                                    if completion_tokens % 100 == 0:
                                        print(".", end="", flush=True)
                        except json.JSONDecodeError:
                            pass
        except Exception as e:
            print(f"\nError during streaming: {e}")
            return {
                "error": str(e),
                "status": "Failed",
                "content": content # Return partial content
            }
            
        end_time = time.time()
        print("") # Newline after dots
        duration = end_time - start_time
        
        # Fallback estimation if stream_options doesn't return usage
        estimated = False
        if completion_tokens == 0:
            completion_tokens = len(content) // 4
            estimated = True
            
        tps = completion_tokens / duration if duration > 0 else 0
        
        return {
            "duration": duration,
            "ttft": time_to_first_token,
            "tokens": completion_tokens,
            "estimated_tokens": estimated,
            "tps": tps,
            "content": content,
            "status": "Complete"
        }
