import json
import os
import subprocess
import time
import urllib.request

def load_json(filepath):
    with open(filepath, 'r') as f:
        return json.load(f)

def save_json(filepath, data):
    with open(filepath, 'w') as f:
        json.dump(data, f, indent=2)

def run_eval(model_key):
    # Run the main.py script for a specific model and return the TPS of the first test
    # We use a smaller timeout and only the coding test to speed up the sweep
    cmd = ["python3", "/home/llm/utils/test/framework/main.py", model_key]
    try:
        subprocess.run(cmd, capture_output=True, text=True, timeout=600)
    except subprocess.TimeoutExpired:
        print(f"  !! Timeout for {model_key}")
        return 0
    
    # Find the latest report
    results_dir = "/home/llm/utils/test/results"
    reports = [f for f in os.listdir(results_dir) if f.startswith(f"framework_eval_{model_key}")]
    if not reports:
        return 0
    
    latest_report = sorted(reports)[-1]
    with open(os.path.join(results_dir, latest_report), 'r') as f:
        for line in f:
            if "- **TPS:**" in line:
                # Line format: "- **TPS:** 135.83 tokens/sec"
                parts = line.split("**TPS:**")
                if len(parts) > 1:
                    val = parts[1].strip().split()[0]
                    try:
                        return float(val)
                    except ValueError:
                        continue
    return 0

def main():
    models_path = "/home/llm/utils/test/framework/models.json"
    models = load_json(models_path)
    
    # We will sweep these context sizes
    contexts = [32768, 49152, 65536, 73728, 81920]
    results = []

    print(f"{'Context':<10} | {'TPS':<10} | {'Status':<10}")
    print("-" * 35)

    for ctx in contexts:
        # Update config
        models["gemma-26b-q5"]["context_size"] = ctx
        models["gemma-26b-q5"]["gpu_layers"] = 99 # Ensure full offload
        save_json(models_path, models)
        
        # Run eval
        tps = run_eval("gemma-26b-q5")
        
        status = "Success" if tps > 0 else "Failed/OOM"
        print(f"{ctx:<10} | {tps:<10.2f} | {status:<10}")
        results.append({"context": ctx, "tps": tps})
        
        # Kill server just in case
        subprocess.run(["killall", "-9", "llama-server"], stderr=subprocess.DEVNULL)
        time.sleep(2)

    print("\nSweep Complete.")

if __name__ == "__main__":
    main()
