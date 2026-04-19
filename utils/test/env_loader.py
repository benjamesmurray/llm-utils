import os

def get_env(key, default=None):
    # Try to find .env in root or search upwards
    # We check common locations relative to where the script might be
    search_paths = [
        ".env",
        "../.env",
        "../../.env",
        "../../../.env",
        "/home/llm/.env"
    ]
    
    for path in search_paths:
        if os.path.exists(path):
            with open(path, "r") as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith("#") and "=" in line:
                        k, v = line.split("=", 1)
                        if k.strip() == key:
                            return v.strip().strip('"').strip("'")
    
    return os.environ.get(key, default)
