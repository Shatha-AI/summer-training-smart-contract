import subprocess
from pathlib import Path

# Project root
PROJECT_ROOT = Path(__file__).resolve().parent.parent

# Solidity contract to analyze
CONTRACT = PROJECT_ROOT / "dataset" / "smartbugs" / "reentrancy" / "simple_dao.sol"

# Docker command
command = [
    "docker",
    "run",
    "--rm",
    "-v",
    f"{PROJECT_ROOT}:/src",
    "securify:latest",
    f"/src/dataset/smartbugs/reentrancy/simple_dao.sol"
]

print(f"Analyzing: {CONTRACT.name}")

result = subprocess.run(command, capture_output=True, text=True)

print(result.stdout)

if result.stderr:
    print("\nErrors:")
    print(result.stderr)
