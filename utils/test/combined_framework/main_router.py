import json
import os
import datetime
import time
import urllib.request
import sys

# Add the parent directory to sys.path to find env_loader
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from env_loader import get_env
from evaluator import Evaluator

def load_json(filepath):
    with open(filepath, 'r') as f:
        return json.load(f)

def write_markdown_report(report_name, model_info, test_results):
    results_dir = "/home/llm/utils/test/combined_results"
    os.makedirs(results_dir, exist_ok=True)
    
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    filepath = os.path.join(results_dir, f"combined_eval_{report_name}_{timestamp}.md")
    
    with open(filepath, 'w') as f:
        f.write(f"# Test Results: {report_name} ({model_info['alias']})\n")
        f.write(f"**Date:** {datetime.datetime.now().strftime('%c')}\n\n")
        
        for result in test_results:
            test = result['test']
            metrics = result['metrics']
            
            f.write(f"## Test: {test['name']}\n")
            
            if metrics.get('status') == 'Failed':
                f.write(f"**Status:** Failed\n")
                f.write(f"**Error:** {metrics.get('error')}\n\n")
                continue
                
            est_flag = " (Estimated)" if metrics['estimated_tokens'] else ""
            
            f.write(f"- **Duration:** {metrics['duration']:.3f}s\n")
            f.write(f"- **TTFT (Time to First Token):** {metrics['ttft']:.3f}s\n")
            f.write(f"- **Tokens:** {metrics['tokens']}{est_flag}\n")
            f.write(f"- **TPS:** {metrics['tps']:.2f} tokens/sec\n\n")
            
    print(f"[{report_name}] Report saved to {filepath}")

def check_router(host, port, api_key):
    # For llama-swap, we check /health or /ui
    url = f"http://{host}:{port}/health"
    try:
        with urllib.request.urlopen(url, timeout=5) as response:
            return response.status == 200
    except:
        # Fallback to /ui if /health not supported
        try:
            url_ui = f"http://{host}:{port}/ui"
            with urllib.request.urlopen(url_ui, timeout=5) as response:
                return response.status == 200
        except:
            return False

def main():
    base_dir = os.path.dirname(os.path.realpath(__file__))
    coding_tests = load_json(os.path.join(base_dir, 'coding_tests.json'))
    clerk_tests = load_json(os.path.join(base_dir, 'clerk_tests.json'))

    # Force use of IDs defined in llama-swap.yaml
    main_model_alias = "qwen3.6-35b-a3b-coding"
    clerk_model_alias = "nemotron-3-nano"
    
    main_model_info = {"alias": main_model_alias}
    clerk_model_info = {"alias": clerk_model_alias}
        
    host = get_env("SERVER_HOST", "127.0.0.1")
    port = int(get_env("MAIN_PORT", 8085))
    api_key = get_env("API_KEY", None)

    print("\n" + "="*50)
    print(f"Starting Sequential 'Router' Evaluation")
    print(f"Main Model: {main_model_info['alias']}")
    print(f"Clerk Model: {clerk_model_info['alias']}")
    print(f"Target: {host}:{port}")
    print("="*50)

    if not check_router(host, port, api_key):
        print(f"Error: Router server not found on {host}:{port}")
        print("Please run /home/llm/utils/launch/launch-dual.sh first.")
        return

    pre_gen_ids = ["data_clerk_toon", "janitor_sanitization"]
    post_gen_ids = ["persistence_extraction", "epoch_summarization"]

    pre_gen_tests = [t for t in clerk_tests if t["id"] in pre_gen_ids]
    post_gen_tests = [t for t in clerk_tests if t["id"] in post_gen_ids]

    # Both use the same port in router mode
    evaluator = Evaluator(port=port)
    
    clerk_results = []
    coding_results = []

    try:
        print("\n--- PHASE 1: Pre-Generation (Clerk) ---")
        for test in pre_gen_tests:
            metrics = evaluator.run_test(clerk_model_info['alias'], test)
            clerk_results.append({"test": test, "metrics": metrics})
            print(f"[clerk] -> {test['name']} TPS: {metrics.get('tps', 0):.2f}")

        print("\n--- PHASE 2: Generation (Main) ---")
        for test in coding_tests:
            metrics = evaluator.run_test(main_model_info['alias'], test)
            coding_results.append({"test": test, "metrics": metrics})
            print(f"[coding] -> {test['name']} TPS: {metrics.get('tps', 0):.2f}")

        print("\n--- PHASE 3: Post-Generation (Clerk) ---")
        for test in post_gen_tests:
            metrics = evaluator.run_test(clerk_model_info['alias'], test)
            clerk_results.append({"test": test, "metrics": metrics})
            print(f"[clerk] -> {test['name']} TPS: {metrics.get('tps', 0):.2f}")

        print("\nWriting Reports...")
        write_markdown_report("router_coding", main_model_info, coding_results)
        write_markdown_report("router_clerk", clerk_model_info, clerk_results)

        print("\nSequential evaluation completed successfully.")

    except Exception as e:
        print(f"Error during combined evaluation: {e}")

if __name__ == "__main__":
    main()
