import json
import os
from evaluator import Evaluator
from server_manager import ServerManager

def main():
    base_dir = os.path.dirname(os.path.realpath(__file__))
    with open(os.path.join(base_dir, 'models.json'), 'r') as f:
        models = json.load(f)
    with open(os.path.join(base_dir, 'coding_tests.json'), 'r') as f:
        coding_tests = json.load(f)

    model_info = models.get('gemma-26b-q4')
    test = next(t for t in coding_tests if t['id'] == 'coding_token_bucket')

    manager = ServerManager(port=8087)
    try:
        manager.start(model_info)
        evaluator = Evaluator(port=8087)
        print(f"\n--- RE-RUNNING TEST: {test['name']} ---")
        result = evaluator.run_test(model_info['alias'], test)
        
        if result['status'] == 'Complete':
            print("\n" + "="*80)
            print("GENERATED CONTENT:")
            print("="*80)
            print(result['content'])
            print("="*80)
        else:
            print(f"Test failed: {result.get('error')}")
            
    finally:
        manager.stop()

if __name__ == "__main__":
    main()
