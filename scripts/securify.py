import subprocess
from pathlib import Path

# Project root
PROJECT_ROOT = Path(__file__).resolve().parent.parent

# Docker command
command = [
    "docker",
    "run",
    "--rm",
    "-v",
    f"{PROJECT_ROOT}:/src",
    "securify:latest",
    "/src/dataset/smartbugs/reentrancy/simple_dao.sol"
]

print("Running Securify...")

result = subprocess.run(command, capture_output=True, text=True)

print(result.stdout)

if result.stderr:
    print(result.stderr)
