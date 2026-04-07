import json
import os
import datetime
import time
from server_manager import ServerManager
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


def main():
    base_dir = os.path.dirname(os.path.realpath(__file__))
    models = load_json(os.path.join(base_dir, 'models.json'))
    
    coding_tests = load_json(os.path.join(base_dir, 'coding_tests.json'))
    clerk_tests = load_json(os.path.join(base_dir, 'clerk_tests.json'))
    
    main_model_info = models.get('gemma-26b-q4')
    clerk_model_info = models.get('nemotron-4b')
    
    if not main_model_info or not clerk_model_info:
        print("Required models missing in models.json")
        return
        
    print("\n" + "="*50)
    print("Starting Sequential 'Baton Pass' Evaluation")
    print("="*50)

    pre_gen_ids = ["data_clerk_toon", "janitor_sanitization"]
    post_gen_ids = ["persistence_extraction", "epoch_summarization"]
    
    pre_gen_tests = [t for t in clerk_tests if t["id"] in pre_gen_ids]
    post_gen_tests = [t for t in clerk_tests if t["id"] in post_gen_ids]

    main_manager = ServerManager(port=8085)
    clerk_manager = ServerManager(port=8086)
    
    clerk_results = []
    coding_results = []

    try:
        main_manager.start(main_model_info)
        time.sleep(5)
        clerk_manager.start(clerk_model_info)
        
        main_evaluator = Evaluator(port=8085)
        clerk_evaluator = Evaluator(port=8086)
        
        print("\n--- PHASE 1: Pre-Generation (Clerk 4B) ---")
        for test in pre_gen_tests:
            metrics = clerk_evaluator.run_test(clerk_model_info['alias'], test)
            clerk_results.append({"test": test, "metrics": metrics})
            print(f"[clerk] -> {test['name']} TPS: {metrics.get('tps', 0):.2f}")

        print("\n--- PHASE 2: Generation (Main 26B) ---")
        for test in coding_tests:
            metrics = main_evaluator.run_test(main_model_info['alias'], test)
            coding_results.append({"test": test, "metrics": metrics})
            print(f"[coding] -> {test['name']} TPS: {metrics.get('tps', 0):.2f}")

        print("\n--- PHASE 3: Post-Generation (Clerk 4B) ---")
        for test in post_gen_tests:
            metrics = clerk_evaluator.run_test(clerk_model_info['alias'], test)
            clerk_results.append({"test": test, "metrics": metrics})
            print(f"[clerk] -> {test['name']} TPS: {metrics.get('tps', 0):.2f}")
            
        print("\nWriting Reports...")
        write_markdown_report("sequential_coding", main_model_info, coding_results)
        write_markdown_report("sequential_clerk", clerk_model_info, clerk_results)
        
        print("\nSequential baton-pass evaluation completed successfully.")
            
    except Exception as e:
        print(f"Error during combined evaluation: {e}")
    finally:
        print("Stopping servers...")
        main_manager.stop()
        clerk_manager.stop()

if __name__ == "__main__":
    os.system("killall -9 llama-server 2>/dev/null")
    main()