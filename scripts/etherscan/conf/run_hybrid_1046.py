
#!/usr/bin/env python3
"""
ConFuzzius Hybrid Vulnerability Scanner
=========================================

Runs the ConFuzzius fuzzer against a dataset of verified Ethereum smart
contracts using a two-tier strategy:

    1. OFFLINE mode  - deploys the contract from source code in a local
                        simulated blockchain (fast, but fails on contracts
                        requiring real constructor parameters, e.g. proxies).
    2. ON-CHAIN mode - fallback that forks live chain state via a JSON-RPC
                        endpoint, so proxy/factory contracts that need real
                        constructor state can still be analyzed.

The script is fully resumable: contracts that already have a result file
are skipped automatically, so interrupting and re-running is always safe.

Author: [project team]
"""

import csv
import json
import os
import subprocess

# --------------------------------------------------------------------------
# Configuration
# --------------------------------------------------------------------------
BASE = os.path.expanduser("~/dataset_1046/dataset_merged_all_clean_v9")
DOCKER_IMAGE = "confuzzius-1046:latest"

OFFLINE_DIR = os.path.join(BASE, "results")
ONCHAIN_DIR = os.path.join(BASE, "results_onchain")

GENERATIONS_OFFLINE = 50
GENERATIONS_ONCHAIN = 20
SAFETY_TIMEOUT_SECONDS = 1800  # hard cap per contract per attempt

RPC_HOST = "127.0.0.1"
RPC_PORT = "8545"  # local proxy forwarding to a public RPC endpoint


def run_docker(cmd):
    """Execute a docker command and return (returncode, stderr)."""
    try:
        proc = subprocess.run(
            cmd, capture_output=True, text=True, timeout=SAFETY_TIMEOUT_SECONDS
        )
        return proc.returncode, proc.stderr
    except subprocess.TimeoutExpired:
        return -1, "TIMEOUT"


def is_success(json_path):
    """A run is considered successful if the result file exists and is
    valid, non-empty JSON - regardless of the process exit code (ConFuzzius
    sometimes exits non-zero due to harmless internal warnings after a
    successful scan)."""
    if not os.path.exists(json_path):
        return False
    try:
        with open(json_path) as f:
            data = json.load(f)
        return len(data) > 0
    except Exception:
        return False


def build_offline_command(address, contract_name, solc_version, source_file):
    return [
        "docker", "run", "--rm",
        "-e", "LANG=C.UTF-8", "-e", "LC_ALL=C.UTF-8", "-e", "PYTHONIOENCODING=utf-8",
        "-v", f"{BASE}:/data",
        DOCKER_IMAGE,
        "python3", "fuzzer/main.py",
        "-s", f"/data/{source_file}",
        "-c", contract_name,
        "--solc", solc_version,
        "--evm", "petersburg",
        "-g", str(GENERATIONS_OFFLINE),
        "-r", f"/data/results/{address}.json",
    ]


def build_onchain_command(address):
    return [
        "docker", "run", "--rm", "--network", "host",
        "-e", "LANG=C.UTF-8", "-e", "LC_ALL=C.UTF-8", "-e", "PYTHONIOENCODING=utf-8",
        "-v", f"{BASE}:/data",
        DOCKER_IMAGE,
        "python3", "fuzzer/main.py",
        "-a", f"/data/contracts/{address}/abi.json",
        "-c", address,
        "--evm", "petersburg",
        "-g", str(GENERATIONS_ONCHAIN),
        "--rpc-host", RPC_HOST,
        "--rpc-port", RPC_PORT,
        "-r", f"/data/results_onchain/{address}.json",
    ]


def main():
    os.makedirs(OFFLINE_DIR, exist_ok=True)
    os.makedirs(ONCHAIN_DIR, exist_ok=True)

    with open(os.path.join(BASE, "dataset.csv"), encoding="utf-8-sig") as f:
        contracts = list(csv.DictReader(f))

    print(f"[INFO] Total contracts to process: {len(contracts)}")

    summary = {"offline": 0, "onchain": 0, "failed": 0, "skipped": 0}

    for i, row in enumerate(contracts, 1):
        address = row["address"]
        contract_name = row["contract_name"]
        solc_version = row["compiler_version"].split("+")[0]
        source_file = row["source_files"]

        offline_path = os.path.join(OFFLINE_DIR, f"{address}.json")
        onchain_path = os.path.join(ONCHAIN_DIR, f"{address}.json")

        print(f"[{i}/{len(contracts)}] {address} ({contract_name}, {solc_version}) ...", flush=True)

        if os.path.exists(offline_path) or os.path.exists(onchain_path):
            print("  -> SKIPPED (already processed)")
            summary["skipped"] += 1
            continue

        # --- Attempt 1: OFFLINE ---
        cmd_offline = build_offline_command(address, contract_name, solc_version, source_file)
        _, err_offline = run_docker(cmd_offline)

        if is_success(offline_path):
            print("  -> SUCCESS (offline)")
            summary["offline"] += 1
            continue

        # --- Attempt 2: ON-CHAIN (fallback) ---
        print("  -> offline failed, retrying on-chain ...")
        cmd_onchain = build_onchain_command(address)
        _, err_onchain = run_docker(cmd_onchain)

        if is_success(onchain_path):
            print("  -> SUCCESS (on-chain)")
            summary["onchain"] += 1
        else:
            print(f"  -> FAILED (both modes)")
            with open(os.path.join(OFFLINE_DIR, f"{address}_ERROR.txt"), "w") as ef:
                ef.write(f"OFFLINE ERROR:\n{err_offline}\n\nONCHAIN ERROR:\n{err_onchain}")
            summary["failed"] += 1

    print("\n===== SCAN SUMMARY =====")
    print(f"Offline success:       {summary['offline']}")
    print(f"On-chain fallback:     {summary['onchain']}")
    print(f"Failed (both modes):   {summary['failed']}")
    print(f"Skipped (pre-existing):{summary['skipped']}")
    print(f"Total contracts:       {len(contracts)}")


if __name__ == "__main__":
    main()
PYEOF