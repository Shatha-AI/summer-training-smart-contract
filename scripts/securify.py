#!/usr/bin/env python3
"""
Securify 2.0 runner — Group B (symbolic/dynamic analysis).

Auto-resolves the correct solc version per contract (via py-solc-x) before
calling Securify, so contracts with any pragma version can be analyzed
without manual version wrangling.

Usage:
    # Quick sanity check on one contract
    python3 scripts/securify.py --test contracts/test.sol

    # Full run over the shared dataset
    python3 scripts/securify.py --dataset dataset --out results/securify_results.csv

Output columns (team-agreed shared schema):
    contract, tool, rule, category, severity, status, description
"""
import argparse
import csv
import re
import subprocess
import sys
from pathlib import Path

try:
    import solcx
except ImportError:
    sys.exit("Missing dependency. Run: pip3 install py-solc-x")

TOOL_NAME = "securify2"
PRAGMA_RE = re.compile(r"pragma\s+solidity\s+([^;]+);")

# TODO (unverified): placeholder pattern for parsing Securify's text output
# into individual findings. Needs to be corrected against real output —
# run --test on a contract first and inspect what's printed.
FINDING_RE = re.compile(
    r"(?P<status>VIOLATION|VULNERABLE|WARNING|SAFE)\b.*?"
    r"(?P<severity>CRITICAL|HIGH|MEDIUM|LOW|INFO)?.*?"
    r"(?P<rule>[A-Za-z][A-Za-z0-9_]*Pattern)?",
    re.IGNORECASE,
)

# TODO: fill in once dataset/rule_mapping.csv has securify2 rows.
RULE_TO_CATEGORY = {
    # "TODAmountPattern": "front_running",
}


def extract_pragma(sol_path: Path):
    text = sol_path.read_text(errors="ignore")
    m = PRAGMA_RE.search(text)
    return m.group(1).strip() if m else None


def ensure_version(sol_path: Path):
    source = sol_path.read_text(errors="ignore")
    version = solcx.install_solc_pragma(source)
    solcx.set_solc_version(version, silent=True)
    return str(version), str(solcx.get_executable(version))


def run_securify(contract: Path, solc_bin: str):
    cmd = [
        "python3", "securify/__main__.py",
        str(contract.resolve()),
        "--solidity", solc_bin,
        "--ignore-pragma",
    ]
    return subprocess.run(cmd, cwd="/sec", capture_output=True, text=True, timeout=180)


def parse_findings(contract_name: str, stdout: str):
    rows = []
    for m in FINDING_RE.finditer(stdout):
        if not m.group("status"):
            continue
        rule = m.group("rule") or "UNKNOWN"
        rows.append({
            "contract": contract_name,
            "tool": TOOL_NAME,
            "rule": rule,
            "category": RULE_TO_CATEGORY.get(rule, "UNMAPPED"),
            "severity": (m.group("severity") or "").upper(),
            "status": m.group("status").upper(),
            "description": "",
        })
    return rows


def test_one(contract_path: Path):
    print(f"Testing: {contract_path}")
    pragma = extract_pragma(contract_path)
    print(f"Pragma: {pragma}")
    version, solc_bin = ensure_version(contract_path)
    print(f"Resolved solc version: {version}")
    proc = run_securify(contract_path, solc_bin)
    print("\n--- STDOUT ---")
    print(proc.stdout)
    if proc.stderr:
        print("--- STDERR ---")
        print(proc.stderr)
    print(f"\nExit code: {proc.returncode}")


def run_batch(dataset_dir: Path, out_path: Path):
    contracts = sorted(dataset_dir.rglob("*.sol"))
    print(f"Found {len(contracts)} contracts under {dataset_dir}")

    all_findings = []
    summary_rows = []

    for i, contract in enumerate(contracts, 1):
        pragma = extract_pragma(contract)
        summary = {"contract": contract.name, "pragma": pragma, "solc_version": "", "status": ""}

        if not pragma:
            summary["status"] = "no_pragma_found"
            summary_rows.append(summary)
            continue

        try:
            version, solc_bin = ensure_version(contract)
        except Exception as e:
            summary["status"] = f"solc_resolution_failed: {e}"[:200]
            summary_rows.append(summary)
            continue
        summary["solc_version"] = version

        try:
            proc = run_securify(contract, solc_bin)
        except subprocess.TimeoutExpired:
            summary["status"] = "timeout"
            summary_rows.append(summary)
            continue

        if proc.returncode == 0 and "Traceback" not in proc.stderr:
            summary["status"] = "ok"
            all_findings.extend(parse_findings(contract.name, proc.stdout))
        else:
            summary["status"] = "securify_error"

        summary_rows.append(summary)
        if i % 25 == 0:
            print(f"  ...{i}/{len(contracts)} processed")

    out_path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = ["contract", "tool", "rule", "category", "severity", "status", "description"]
    with out_path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(all_findings)

    summary_path = out_path.with_name(out_path.stem + "_summary.csv")
    with summary_path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(summary_rows[0].keys()))
        writer.writeheader()
        writer.writerows(summary_rows)

    ok = sum(1 for r in summary_rows if r["status"] == "ok")
    print(f"\nDone. {ok}/{len(summary_rows)} contracts analyzed successfully.")
    print(f"Findings (shared schema): {out_path}")
    print(f"Per-contract summary:     {summary_path}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--test", help="Path to a single contract for a quick sanity check")
    ap.add_argument("--dataset", help="Path to dataset folder for a full batch run")
    ap.add_argument("--out", default="results/securify_results.csv")
    args = ap.parse_args()

    if args.test:
        test_one(Path(args.test))
    elif args.dataset:
        run_batch(Path(args.dataset), Path(args.out))
    else:
        ap.error("Provide either --test <contract.sol> or --dataset <folder>")


if __name__ == "__main__":
    main()
