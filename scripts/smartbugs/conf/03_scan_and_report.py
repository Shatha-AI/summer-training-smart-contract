#!/usr/bin/env python3

import csv
import json
import os
import subprocess
from datetime import datetime, timezone


OUT_BASE = os.path.expanduser("~/dataset_40_labeled")
DOCKER_IMAGE = "confuzzius-full:latest"
RPC_HOST, RPC_PORT = "127.0.0.1", "8545"
GENERATIONS_OFFLINE = 50
GENERATIONS_ONCHAIN = 20
SAFETY_TIMEOUT = 1800  # ثانية، لكل عقد كحد أقصى
# ============================================================

OFFLINE_DIR = os.path.join(OUT_BASE, "results")
ONCHAIN_DIR = os.path.join(OUT_BASE, "results_onchain")
DATASET_CSV = os.path.join(OUT_BASE, "dataset.csv")
LOCAL_TARGETS_PATH = os.path.join(OUT_BASE, "local_targets.json")
CSV_OUT = os.path.join(OUT_BASE, "final_results.csv")
JSON_OUT = os.path.join(OUT_BASE, "final_results.json")
CSV_FIELDS = ["n", "contract", "tool", "rule", "category", "severity", "status"]


def run_docker(cmd):
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=SAFETY_TIMEOUT)
        return proc.returncode, proc.stderr
    except subprocess.TimeoutExpired:
        return -1, "TIMEOUT"


def is_success(json_path):
    if not os.path.exists(json_path):
        return False
    try:
        with open(json_path) as f:
            return len(json.load(f)) > 0
    except Exception:
        return False


def step1_scan(contracts, local_targets):
    
    os.makedirs(OFFLINE_DIR, exist_ok=True)
    os.makedirs(ONCHAIN_DIR, exist_ok=True)

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
            print("  -> already done, skipping")
            summary["skipped"] += 1
            continue

        cmd_offline = [
            "docker", "run", "--rm",
            "-e", "LANG=C.UTF-8", "-e", "LC_ALL=C.UTF-8", "-e", "PYTHONIOENCODING=utf-8",
            "-v", f"{OUT_BASE}:/data",
            DOCKER_IMAGE,
            "python3", "fuzzer/main.py",
            "-s", f"/data/{source_file}",
            "-c", contract_name,
            "--solc", solc_version,
            "--evm", "petersburg",
            "-g", str(GENERATIONS_OFFLINE),
            "-r", f"/data/results/{address}.json",
        ]
        rc, err = run_docker(cmd_offline)

        if is_success(offline_path):
            print("  -> OK (offline)")
            summary["offline"] += 1
            continue

        target = local_targets.get(address)
        if target is None:
            print("  -> offline failed, no locally-deployed address available -> skip on-chain")
            with open(os.path.join(OFFLINE_DIR, f"{address}_ERROR.txt"), "w") as ef:
                ef.write(f"OFFLINE ERROR:\n{err}\n\nONCHAIN: skipped - no deployment found in local_targets.json")
            summary["failed"] += 1
            continue

        print(f"  -> offline failed, retrying on-chain (local anvil @ {target['address']}) ...")
        cmd_onchain = [
            "docker", "run", "--rm", "--network", "host",
            "-e", "LANG=C.UTF-8", "-e", "LC_ALL=C.UTF-8", "-e", "PYTHONIOENCODING=utf-8",
            "-v", f"{OUT_BASE}:/data",
            DOCKER_IMAGE,
            "python3", "fuzzer/main.py",
            "-a", f"/data/{target['abi_path']}",
            "-c", target["address"],
            "--evm", "petersburg",
            "-g", str(GENERATIONS_ONCHAIN),
            "--rpc-host", RPC_HOST,
            "--rpc-port", RPC_PORT,
            "-r", f"/data/results_onchain/{address}.json",
        ]
        rc2, err2 = run_docker(cmd_onchain)

        if is_success(onchain_path):
            print("  -> OK (on-chain / local anvil)")
            summary["onchain"] += 1
        else:
            print(f"  -> FAILED both ways. offline_err={err[-150:]!r} onchain_err={err2[-150:]!r}")
            with open(os.path.join(OFFLINE_DIR, f"{address}_ERROR.txt"), "w") as ef:
                ef.write(f"OFFLINE ERROR:\n{err}\n\nONCHAIN ERROR:\n{err2}")
            summary["failed"] += 1

    print("\n--- Scan summary ---")
    for k, v in summary.items():
        print(f"{k}: {v}")


# (CSV + JSON)


def load_result(cid):
    for base, mode in [(OFFLINE_DIR, "offline"), (ONCHAIN_DIR, "onchain")]:
        path = os.path.join(base, f"{cid}.json")
        if os.path.exists(path):
            try:
                with open(path, encoding="utf-8") as f:
                    data = json.load(f)
                if data:
                    return mode, data
            except Exception:
                pass
    return None, None


def load_failure_reason(cid):
    err_path = os.path.join(OFFLINE_DIR, f"{cid}_ERROR.txt")
    if os.path.exists(err_path):
        with open(err_path, encoding="utf-8", errors="ignore") as f:
            return f.read().strip()
    return "Failure reason unknown (no _ERROR.txt file found)"


def step2_build_report(contracts):
    csv_rows, json_results, findings = [], [], []
    counts = {"vulnerable_contracts": 0, "clean_contracts": 0, "failed_contracts": 0, "total_findings": 0}

    for n, row in enumerate(contracts, 1):
        cid = row["address"]
        contract_name = row["contract_name"]
        mode, data = load_result(cid)

        if data is None:
            reason = load_failure_reason(cid)
            counts["failed_contracts"] += 1
            csv_rows.append({"n": n, "contract": cid, "tool": "ConFuzzius", "rule": "",
                              "category": "Scan Failed", "severity": "", "status": "Failed"})
            json_results.append({"n": n, "id": cid, "contract_name": contract_name, "mode": None,
                                  "status": "Failed", "raw": None, "error": reason})
            continue

        top_key = contract_name if contract_name in data else next(iter(data.keys()))
        contract_data = data[top_key]
        errors = contract_data.get("errors", {})

        json_results.append({"n": n, "id": cid, "contract_name": contract_name, "mode": mode,
                              "status": "Vulnerable" if errors else "Clean", "raw": data})

        if not errors:
            counts["clean_contracts"] += 1
            csv_rows.append({"n": n, "contract": cid, "tool": "ConFuzzius", "rule": "",
                              "category": "No Issues", "severity": "", "status": "Clean"})
            continue

        counts["vulnerable_contracts"] += 1
        for line_key, error_list in errors.items():
            for err in error_list:
                counts["total_findings"] += 1
                swc = err.get("swc_id", "")
                etype = err.get("type", "")
                severity = err.get("severity", "")
                line = err.get("line")
                col = err.get("column")
                code = err.get("source_code")
                rule = f"SWC-{swc}" if swc != "" else ""

                if line is not None and code:
                    location_type = "source_line"       # offline: خريطة مصدر حقيقية
                else:
                    location_type = "bytecode_offset"    # on-chain: بدون خريطة مصدر
                    line = line_key
                    code = ""

                csv_rows.append({"n": n, "contract": cid, "tool": "ConFuzzius", "rule": rule,
                                  "category": etype, "severity": severity, "status": "Vulnerable"})
                findings.append({"n": n, "contract": cid, "contract_name": contract_name,
                                  "tool": "ConFuzzius", "category": etype, "swc": swc, "rule": rule,
                                  "severity": severity, "line": line, "column": col, "code": code,
                                  "location_type": location_type, "mode": mode})

    with open(CSV_OUT, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=CSV_FIELDS)
        writer.writeheader()
        writer.writerows(csv_rows)

    meta = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "total_contracts": len(contracts),
        **counts,
    }
    with open(JSON_OUT, "w", encoding="utf-8") as f:
        json.dump({"meta": meta, "results": json_results, "findings": findings}, f, ensure_ascii=False, indent=2)

    print("Report summary:")
    for k, v in meta.items():
        print(f"  {k}: {v}")
    print(f"\nCSV  -> {CSV_OUT}")
    print(f"JSON -> {JSON_OUT}")


def main():
    with open(DATASET_CSV, encoding="utf-8-sig") as f:
        contracts = list(csv.DictReader(f))
    with open(LOCAL_TARGETS_PATH, encoding="utf-8") as f:
        local_targets = json.load(f)

    step1_scan(contracts, local_targets)
    step2_build_report(contracts)
    print("\nDone. Pipeline complete.")


if __name__ == "__main__":
    main()
