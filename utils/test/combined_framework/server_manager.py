import subprocess
import time
import urllib.request
import os
import signal
import sys

# Add the parent directory to sys.path to find env_loader
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from env_loader import get_env

class ServerManager:
    def __init__(self, bin_path="/home/llm/llama.cpp/build/bin/llama-server", port=None):
        self.bin_path = bin_path
        self.port = port or int(get_env("MAIN_PORT", 8085))
        self.host = get_env("SERVER_HOST", "0.0.0.0")
        self.api_key = get_env("API_KEY", "2250")
        self.process = None

    def start(self, model_info):
        self.stop() # Ensure clean state
        
        print(f"Starting server for model {model_info['alias']} on {self.host}:{self.port}...")
        
        cmd = [
            self.bin_path,
            "-m", model_info['path'],
            "-ngl", str(model_info['gpu_layers']),
            "-fa", "on",
            "-c", str(model_info['context_size']),
            "-t", str(model_info['threads']),
            "--host", self.host,
            "--port", str(self.port),
            "--alias", model_info['alias'],
            "--jinja",
            "--metrics",
            "--api-key", self.api_key
        ]

        if 'kv_flags' in model_info and model_info['kv_flags']:
            cmd.extend(model_info['kv_flags'].split())

        if 'chat_template_kwargs' in model_info and model_info['chat_template_kwargs']:
            cmd.extend(["--chat-template-kwargs", model_info['chat_template_kwargs']])
        
        log_dir = "/home/llm/utils/launch/logs"
        os.makedirs(log_dir, exist_ok=True)
        log_file = open(f"{log_dir}/server_{model_info['alias']}.log", "w")
        self.process = subprocess.Popen(cmd, stdout=log_file, stderr=subprocess.STDOUT, preexec_fn=os.setsid)
        
        if not self._wait_for_ready(model_info['alias']):
            raise RuntimeError(f"Server failed to start for {model_info['alias']}")
        
        print("Server ready, giving it 10 seconds to settle...")
        time.sleep(10)
        
    def _wait_for_ready(self, expected_alias, timeout=120):
        print(f"Waiting for API on {self.host}:{self.port} (timeout {timeout}s)...")
        start_time = time.time()
        url = f"http://{self.host}:{self.port}/v1/models"
        
        req = urllib.request.Request(url, headers={'Authorization': f'Bearer {self.api_key}'})
        
        while time.time() - start_time < timeout:
            try:
                with urllib.request.urlopen(req) as response:
                    if response.status == 200:
                        data = response.read().decode('utf-8')
                        if expected_alias in data:
                            return True
            except Exception:
                pass
            
            if self.process.poll() is not None:
                print("Server process died unexpectedly.")
                return False
                
            time.sleep(2)
            
        print("Timeout reached waiting for server.")
        return False

    def stop(self):
        if self.process:
            try:
                os.killpg(os.getpgid(self.process.pid), signal.SIGKILL)
            except Exception:
                pass
            self.process.wait()
            self.process = None
        time.sleep(2)
