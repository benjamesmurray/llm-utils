import json
import os
import sys
import datetime
from server_manager import ServerManager
from evaluator import Evaluator

def load_json(filepath):
    with open(filepath, 'r') as f:
        return json.load(f)

def write_markdown_report(model_key, model_info, test_results):
    results_dir = "/home/llm/utils/test/data_clerk_results"
    os.makedirs(results_dir, exist_ok=True)
    
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    filepath = os.path.join(results_dir, f"data_clerk_eval_{model_key}_{timestamp}.md")
    
    with open(filepath, 'w') as f:
        f.write(f"# Test Results: {model_key} ({model_info['alias']})\n")
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
            f.write(f"- **TPS:** {metrics['tps']:.2f} tokens/sec\n")
            f.write(f"- **Status:** {metrics['status']}\n\n")
            
            f.write("### System Prompt\n")
            f.write(f"{test['system_prompt']}\n\n")
            
            f.write("### User Prompt\n")
            f.write(f"{test['user_prompt']}\n\n")
            
            f.write("### Model Output\n")
            f.write(f"{metrics['content']}\n\n")
            f.write("---\n")
            
    print(f"Report saved to {filepath}")

def main():
    # Resolve the real path to handle symlinks correctly
    base_dir = os.path.dirname(os.path.realpath(__file__))
    models = load_json(os.path.join(base_dir, 'models.json'))
    tests = load_json(os.path.join(base_dir, 'tests.json'))
    
    manager = ServerManager()
    evaluator = Evaluator()
    
    # Optional filtering via command line args
    target_models = sys.argv[1:] if len(sys.argv) > 1 else list(models.keys())
    
    for model_key in target_models:
        if model_key not in models:
            print(f"Skipping unknown model: {model_key}")
            continue
            
        model_info = models[model_key]
        print(f"\n{'='*50}\nEvaluating Model: {model_key}\n{'='*50}")
        
        try:
            manager.start(model_info)
            
            test_results = []
            for test in tests:
                metrics = evaluator.run_test(model_info['alias'], test)
                test_results.append({
                    "test": test,
                    "metrics": metrics
                })
                print(f"  -> TPS: {metrics.get('tps', 0):.2f}")
                
            write_markdown_report(model_key, model_info, test_results)
            
        except Exception as e:
            print(f"Error during evaluation of {model_key}: {e}")
        finally:
            print(f"Stopping server for {model_key}...")
            manager.stop()

if __name__ == "__main__":
    main()
