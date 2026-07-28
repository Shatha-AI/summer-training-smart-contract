import os
import re
import subprocess
from pathlib import Path

import pandas as pd
from tqdm import tqdm


# ======================================================
# SETTINGS
# ======================================================


DATASET_FOLDER = Path("dataset/selected_contracts")


LOG_FOLDER = Path("logs")


OUTPUT_CSV = "results.csv"

NUM_CONTRACTS = None


MYTH_TIMEOUT = 1000

LOG_FOLDER.mkdir(exist_ok=True)


installed_versions = set()

# ======================================================
# FIND ALL CONTRACTS
# ======================================================

contracts = []

for category in DATASET_FOLDER.iterdir():

    if not category.is_dir():
        continue

    for contract in category.glob("*.sol"):

        contracts.append({
            "path": contract,
            "category": category.name
        })

contracts = sorted(
    contracts,
    key=lambda x: str(x["path"])
)

if NUM_CONTRACTS is not None:
    contracts = contracts[:NUM_CONTRACTS]

print("=" * 60)
print(f"Found {len(contracts)} Solidity contracts")
print("=" * 60)


# ======================================================
# READ PRAGMA VERSION
# ======================================================

pragma_pattern = re.compile(
    r"pragma\s+solidity\s+([^;]+);"
)


def get_solidity_version(file_path):
    """

    """

    with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
        source = f.read()

    match = pragma_pattern.search(source)

    if not match:
        return None

    pragma = match.group(1).strip()

    versions = re.findall(
        r"\d+\.\d+\.\d+",
        pragma
    )

    if versions:
        return versions[0]

    return None
    
# ======================================================
# SOLC-SELECT
# ======================================================

def install_and_use_solc(version):

    if version is None:
        return False

    try:

        if version not in installed_versions:

            print(f"\nInstalling solc {version} ...")

            subprocess.run(
                ["solc-select", "install", version],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=False
            )

            installed_versions.add(version)

        subprocess.run(
            ["solc-select", "use", version],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=True
        )

        print(f"\nUsing solc {version}")

        result = subprocess.run(
            ["solc", "--version"],
            capture_output=True,
            text=True
        )

        print(result.stdout)

        return True

    except Exception as e:
        print(e)
        return False


# ======================================================
# RUN MYTHRIL
# ======================================================

def run_mythril(contract_path, version):

    cmd = [
        "sudo",
        "docker",
        "run",
        "--rm",
        "-v",
        f"{Path.cwd()}:/home/project",
        "-w",
        "/home/project",
        "mythril-fixed",
        "analyze",
        "--solv",
        version,
        str(contract_path)
    ]

    process = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        timeout=MYTH_TIMEOUT
    )

    print("Return Code:", process.returncode)

    if process.stderr:
        print(process.stderr)

    return process.stdout + process.stderr


# ======================================================
# SAVE LOG
# ======================================================

def save_log(contract_name, output):

    log_file = LOG_FOLDER / f"{contract_name}.txt"

    with open(
        log_file,
        "w",
        encoding="utf-8",
        errors="ignore"
    ) as f:

        f.write(output)

    return log_file


# ======================================================
# START ANALYSIS
# ======================================================

print("\nStarting analysis...\n")

results = []

for contract in tqdm(contracts):

    contract_path = contract["path"]
    category = contract["category"]

    contract_name = contract_path.name

    solidity_version = get_solidity_version(contract_path)

    if not install_and_use_solc(solidity_version):

        results.append({

            "contract": contract_name,
            "tool": "Mythril",
            "rule": "",
            "category": "",
            "severity": "",
            "status": "Failed",
            "description": f"Unable to use solc {solidity_version}"

        })

        continue


    try:

        output = run_mythril(
            contract_path,
            solidity_version
        )

    except subprocess.TimeoutExpired:

            results.append({

                "contract": contract_name,
                "tool": "Mythril",
                "rule": "",
                "category": "",
                "severity": "",
                "status": "Failed",
                "description": "Analysis Timeout"

            })

            continue

    save_log(contract_name, output)
    
# ======================================================
# PARSE MYTHRIL OUTPUT
# ======================================================

    if "====" not in output:

        results.append({

            "contract": contract_name,
            "tool": "Mythril",
            "rule": "",
            "category": "No Issues",
            "severity": "",
            "status": "Clean",
            "description": ""

        })

        continue

    pattern = re.compile(
        r"====\s*(.*?)\s*====(.*?)(?=\n====|\Z)",
        re.DOTALL
    )

    blocks = pattern.findall(output)

    found_bug = False

    for bug_name, block in blocks:

        found_bug = True

        bug_name = bug_name.strip()

        swc = ""
        severity = ""
        description = ""
        execution_trace = ""

        lines = [line.strip() for line in block.splitlines() if line.strip()]

        # -------------------------
        # SWC ID
        # -------------------------

        for line in lines:

            if line.startswith("SWC ID"):

                swc = line.split(":", 1)[1].strip()

                break

        # -------------------------
        # Severity
        # -------------------------

        for line in lines:

            if line.startswith("Severity"):

                severity = line.split(":", 1)[1].strip()

                break

        # -------------------------
        # Description
        # -------------------------

        start = False
        desc_lines = []

        for line in lines:

            if line.startswith("Estimated Gas Usage"):
                start = True
                continue

            if start:

                if "--------------------" in line:
                    break

                desc_lines.append(line)

        description = " ".join(desc_lines)

        # -------------------------
        # Execution Trace
        # -------------------------

        if "Transaction Sequence:" in block:

            execution_trace = ""

            if "Transaction Sequence:" in block:
                execution_trace = block.split(
                    "Transaction Sequence:",
                    1
                )[1].strip()

            results.append({

                "contract": contract_name,
                "tool": "Mythril",
                "rule": swc,
                "category": bug_name,
                "severity": severity,
                "status": "Detected",
                "description": description

            })

    if not found_bug:

            results.append({

                "contract": contract_name,
                "tool": "Mythril",
                "rule": "",
                "category": "No Issues",
                "severity": "",
                "status": "Clean",
                "description": ""

            })

# ======================================================
# SAVE CSV
# ======================================================

columns = [
    "contract",
    "tool",
    "rule",
    "category",
    "severity",
    "status",
    "description"
]

df = pd.DataFrame(results, columns=columns)

df.to_csv(
    OUTPUT_CSV,
    index=False,
    encoding="utf-8-sig"
)

print("\nDone.")
print(df.head())