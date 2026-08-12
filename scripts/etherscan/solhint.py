#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
solhint_scan.py
================
Scans a set of Solidity contracts with the Solhint CLI tool.

Two outputs are produced, and they serve two different purposes:

  1) JSON file  -> 100% RAW. Every finding is stored exactly as Solhint's
     own JSON formatter emitted it (same keys, same values, nothing added,
     nothing renamed, nothing converted, no heuristics, no scoring). Only
     factual bookkeeping (which contract/file it came from, tool version,
     timestamps, counts) wraps the raw findings so results stay traceable.
     No SWC/DASP mapping and no confidence value are added anywhere in
     this file.

  2) CSV file   -> normalized / flattened for analysis. One row per
     finding, containing the common record the team agreed on:
         {contract, tool, SWC/DASP category, severity, code_location}
     plus every other raw field Solhint produced (rule id, message, line,
     column, endLine, endColumn, fix availability, rule type/category...)
     so that no feature the tool can output is left out. The SWC/DASP
     mapping is a manually-built lookup table (see RULE_MAP below) applied
     only when building this CSV -- it is documented, deterministic, and
     never touches the JSON file.

Example usage (Windows / Command Prompt):
    python solhint_scan.py ^
        --contracts-dir "C:\\Users\\alrna\\summer-training-smart-contract\\dataset\\selected_contracts\\the_1000\\dataset_merged_all_clean_v9\\contracts" ^
        --out-json "results_solhint.json" ^
        --out-csv  "results_solhint.csv"

Requirements:
    - Node.js + solhint installed and available on PATH
      (or pass its path explicitly via --solhint-bin)
      npm install -g solhint
    - Python 3.8+  (no external libraries needed; standard library only)
"""

import argparse
import concurrent.futures
import csv
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timezone

# --------------------------------------------------------------------------
# Rule map -> rule type / SWC classification / DASP classification.
# USED ONLY WHEN BUILDING THE CSV. Never applied to / stored in the JSON
# output, which stays 100% raw.
# --------------------------------------------------------------------------
# Built from the actual Solhint 6.x source code (68 rules across every
# category: security, best-practices, gas-consumption, naming, order,
# miscellaneous, deprecations). Genuinely security-relevant rules are
# mapped to the closest known SWC ID / DASP Top 10 category. Non-security
# rules (style/naming/gas) are explicitly tagged "N/A" so they are never
# misleadingly folded into the security classification.
#
# rule_id: (rule_type, human_category, swc_id, swc_title, dasp_category)
RULE_MAP = {
    # ---------------- Security rules ----------------
    "reentrancy": ("security", "Security Rules", "SWC-107",
                   "Reentrancy", "Reentrancy"),
    "avoid-call-value": ("security", "Security Rules", "SWC-107",
                          "Reentrancy (low-level .call.value)", "Reentrancy"),
    "multiple-sends": ("security", "Security Rules", "SWC-107",
                        "Reentrancy (multiple external calls)", "Reentrancy"),
    "avoid-low-level-calls": ("security", "Security Rules", "SWC-104",
                               "Unchecked Call Return Value", "Unchecked Low Level Calls"),
    "check-send-result": ("security", "Security Rules", "SWC-104",
                           "Unchecked Call Return Value", "Unchecked Low Level Calls"),
    "no-unchecked-calls": ("security", "Security Rules", "SWC-104",
                            "Unchecked Call Return Value", "Unchecked Low Level Calls"),
    "avoid-tx-origin": ("security", "Security Rules", "SWC-115",
                         "Authorization through tx.origin", "Access Control"),
    "func-visibility": ("security", "Security Rules", "SWC-100",
                         "Function Default Visibility", "Access Control"),
    "state-visibility": ("security", "Security Rules", "SWC-108",
                          "State Variable Default Visibility", "Access Control"),
    "compiler-version": ("security", "Security Rules", "SWC-102",
                          "Outdated Compiler Version", "N/A"),
    "avoid-sha3": ("security", "Security Rules", "SWC-111",
                   "Use of Deprecated Solidity Functions", "N/A"),
    "avoid-suicide": ("security", "Security Rules", "SWC-111",
                       "Use of Deprecated Solidity Functions (selfdestruct/suicide)", "N/A"),
    "avoid-throw": ("security", "Security Rules", "SWC-111",
                     "Use of Deprecated Solidity Functions (throw)", "N/A"),
    "not-rely-on-block-hash": ("security", "Security Rules", "SWC-120",
                                "Weak Sources of Randomness from Chain Attributes", "Bad Randomness"),
    "not-rely-on-time": ("security", "Security Rules", "SWC-116",
                          "Block values as a proxy for time", "Time Manipulation"),
    "no-inline-assembly": ("security", "Security Rules", "SWC-127",
                            "Arbitrary Jump / unsafe low-level assembly", "Unknown Unknowns"),
    "no-complex-fallback": ("security", "Security Rules", "N/A",
                             "Complex fallback function (DoS / gas risk)", "Denial of Service"),
    "no-immutable-before-declaration": ("security", "Security Rules", "N/A",
                                         "Immutable variable used before declaration", "N/A"),

    # ---------------- Deprecations ----------------
    "constructor-syntax": ("deprecations", "Best Practices Rules", "SWC-118",
                            "Incorrect Constructor Name (legacy syntax)", "N/A"),

    # ---------------- Best practices (not security per se) ----------------
    "code-complexity": ("best-practices", "Best Practices Rules", "N/A", "N/A", "N/A"),
    "explicit-types": ("best-practices", "Best Practices Rules", "N/A", "N/A", "N/A"),
    "function-max-lines": ("best-practices", "Best Practices Rules", "N/A", "N/A", "N/A"),
    "max-line-length": ("best-practices", "Best Practices Rules", "N/A", "N/A", "N/A"),
    "max-states-count": ("best-practices", "Best Practices Rules", "N/A", "N/A", "N/A"),
    "no-console": ("best-practices", "Best Practices Rules", "N/A", "N/A", "N/A"),
    "no-empty-blocks": ("best-practices", "Best Practices Rules", "N/A", "N/A", "N/A"),
    "no-global-import": ("best-practices", "Best Practices Rules", "N/A", "N/A", "N/A"),
    "no-unused-import": ("best-practices", "Best Practices Rules", "N/A", "N/A", "N/A"),
    "no-unused-private-funcs": ("best-practices", "Best Practices Rules", "N/A", "N/A", "N/A"),
    "no-unused-vars": ("best-practices", "Best Practices Rules", "N/A", "N/A", "N/A"),
    "one-contract-per-file": ("best-practices", "Best Practices Rules", "N/A", "N/A", "N/A"),
    "payable-fallback": ("best-practices", "Best Practices Rules", "N/A", "N/A", "N/A"),
    "reason-string": ("best-practices", "Best Practices Rules", "N/A", "N/A", "N/A"),
    "use-natspec": ("best-practices", "Best Practices Rules", "N/A", "N/A", "N/A"),

    # ---------------- Gas consumption ----------------
    "gas-calldata-parameters": ("gas-consumption", "Gas Consumption Rules", "N/A", "N/A", "N/A"),
    "gas-custom-errors": ("gas-consumption", "Gas Consumption Rules", "N/A", "N/A", "N/A"),
    "gas-increment-by-one": ("gas-consumption", "Gas Consumption Rules", "N/A", "N/A", "N/A"),
    "gas-indexed-events": ("gas-consumption", "Gas Consumption Rules", "N/A", "N/A", "N/A"),
    "gas-length-in-loops": ("gas-consumption", "Gas Consumption Rules", "SWC-128",
                             "DoS With Block Gas Limit (unbounded loop)", "Denial of Service"),
    "gas-multitoken1155": ("gas-consumption", "Gas Consumption Rules", "N/A", "N/A", "N/A"),
    "gas-named-return-values": ("gas-consumption", "Gas Consumption Rules", "N/A", "N/A", "N/A"),
    "gas-small-strings": ("gas-consumption", "Gas Consumption Rules", "N/A", "N/A", "N/A"),
    "gas-strict-inequalities": ("gas-consumption", "Gas Consumption Rules", "N/A", "N/A", "N/A"),
    "gas-struct-packing": ("gas-consumption", "Gas Consumption Rules", "N/A", "N/A", "N/A"),

    # ---------------- Naming / style ----------------
    "const-name-snakecase": ("naming", "Style Guide Rules", "N/A", "N/A", "N/A"),
    "contract-name-capwords": ("naming", "Style Guide Rules", "N/A", "N/A", "N/A"),
    "event-name-capwords": ("naming", "Style Guide Rules", "N/A", "N/A", "N/A"),
    "foundry-test-function-naming": ("naming", "Style Guide Rules", "N/A", "N/A", "N/A"),
    "foundry-test-functions": ("naming", "Style Guide Rules", "N/A", "N/A", "N/A"),
    "func-name-mixedcase": ("naming", "Style Guide Rules", "N/A", "N/A", "N/A"),
    "func-named-parameters": ("naming", "Style Guide Rules", "N/A", "N/A", "N/A"),
    "func-param-name-mixedcase": ("naming", "Style Guide Rules", "N/A", "N/A", "N/A"),
    "immutable-vars-naming": ("naming", "Style Guide Rules", "N/A", "N/A", "N/A"),
    "interface-starts-with-i": ("naming", "Style Guide Rules", "N/A", "N/A", "N/A"),
    "modifier-name-mixedcase": ("naming", "Style Guide Rules", "N/A", "N/A", "N/A"),
    "named-parameters-mapping": ("naming", "Style Guide Rules", "N/A", "N/A", "N/A"),
    "private-vars-leading-underscore": ("naming", "Style Guide Rules", "N/A", "N/A", "N/A"),
    "use-forbidden-name": ("naming", "Style Guide Rules", "N/A", "N/A", "N/A"),
    "var-name-mixedcase": ("naming", "Style Guide Rules", "N/A", "N/A", "N/A"),

    # ---------------- Order / style ----------------
    "imports-on-top": ("order", "Style Guide Rules", "N/A", "N/A", "N/A"),
    "imports-order": ("order", "Style Guide Rules", "N/A", "N/A", "N/A"),
    "ordering": ("order", "Style Guide Rules", "N/A", "N/A", "N/A"),
    "visibility-modifier-order": ("order", "Style Guide Rules", "N/A", "N/A", "N/A"),

    # ---------------- Miscellaneous ----------------
    "comprehensive-interface": ("miscellaneous", "Miscellaneous", "N/A", "N/A", "N/A"),
    "duplicated-imports": ("miscellaneous", "Style Guide Rules", "N/A", "N/A", "N/A"),
    "foundry-no-block-time-number": ("miscellaneous", "Miscellaneous", "N/A", "N/A", "N/A"),
    "import-path-check": ("miscellaneous", "Miscellaneous", "N/A", "N/A", "N/A"),
    "quotes": ("miscellaneous", "Miscellaneous", "N/A", "N/A", "N/A"),
}

UNKNOWN_RULE_DEFAULT = ("unknown", "Unknown", "N/A", "N/A", "N/A")

CONCLUSION_RE = re.compile(
    r"(\d+)\s*problem/s\s*\((\d+)\s*error/s,\s*(\d+)\s*warning/s\)"
)


def find_solhint_bin(explicit):
    if explicit:
        return explicit
    for candidate in ("solhint", "solhint.cmd", "solhint.exe"):
        path = shutil.which(candidate)
        if path:
            return path
    return "solhint"  # hope it's on PATH; will error out later if not


def discover_contracts(contracts_dir):
    """
    Flexibly discovers the folder layout:
      <contracts_dir>/<contract_address_or_name>/sources/*.sol
      or
      <contracts_dir>/<contract_address_or_name>/*.sol
      or even .sol files directly inside contracts_dir itself.
    Returns a list of tuples: (contract_id, sol_file_path)
    """
    items = []
    if not os.path.isdir(contracts_dir):
        raise FileNotFoundError(f"contracts dir not found: {contracts_dir}")

    entries = sorted(os.listdir(contracts_dir))
    any_subdir = any(os.path.isdir(os.path.join(contracts_dir, e)) for e in entries)

    if not any_subdir:
        # .sol files directly in this folder
        for e in entries:
            if e.lower().endswith(".sol"):
                items.append((os.path.splitext(e)[0], os.path.join(contracts_dir, e)))
        return items

    for entry in entries:
        full = os.path.join(contracts_dir, entry)
        if not os.path.isdir(full):
            continue
        sources_dir = os.path.join(full, "sources")
        search_dir = sources_dir if os.path.isdir(sources_dir) else full
        sol_files = []
        for root, _dirs, files in os.walk(search_dir):
            for f in files:
                if f.lower().endswith(".sol"):
                    sol_files.append(os.path.join(root, f))
        if not sol_files:
            items.append((entry, None))  # contract without source -> recorded as a failure
            continue
        for sf in sorted(sol_files):
            items.append((entry, sf))
    return items


def get_solhint_version(solhint_bin):
    try:
        out = subprocess.run(
            [solhint_bin, "--version"],
            capture_output=True, text=True, timeout=30
        )
        return out.stdout.strip() or out.stderr.strip()
    except Exception as e:
        return f"unknown ({e})"


def run_solhint_on_file(solhint_bin, config_path, sol_path, timeout):
    """Runs solhint on a single file and returns
    (findings_raw_list, conclusion_str, stderr, returncode, duration).
    findings_raw_list is exactly the list of finding objects Solhint's
    JSON formatter produced -- untouched, same keys/values."""
    start = time.time()
    sol_dir = os.path.dirname(os.path.abspath(sol_path))
    sol_name = os.path.basename(sol_path)
    cmd = [solhint_bin, "-c", os.path.abspath(config_path), "-f", "json", "--noPrompt", sol_name]

    # We write stdout to a temp file instead of reading it directly through a
    # PIPE: some contracts produce very large JSON output (thousands of
    # lines for big/merged contracts), and reading through a PIPE can get
    # truncated in some runtime environments once a certain buffer size is
    # hit. Writing to a file avoids that entirely.
    with tempfile.NamedTemporaryFile(mode="w", suffix=".stdout.json", delete=False) as tmp_out:
        tmp_out_path = tmp_out.name
    try:
        with open(tmp_out_path, "w", encoding="utf-8") as out_fh:
            try:
                proc = subprocess.run(
                    cmd, stdout=out_fh, stderr=subprocess.PIPE, text=True,
                    timeout=timeout, cwd=sol_dir
                )
            except subprocess.TimeoutExpired:
                return [], None, f"TIMEOUT after {timeout}s", -1, time.time() - start
        duration = time.time() - start
        with open(tmp_out_path, "r", encoding="utf-8") as in_fh:
            stdout = in_fh.read().strip()
    finally:
        try:
            os.remove(tmp_out_path)
        except OSError:
            pass

    stderr = (proc.stderr or "").strip()

    if not stdout:
        return [], None, stderr, proc.returncode, duration

    try:
        parsed = json.loads(stdout)
    except json.JSONDecodeError:
        return [], None, f"JSON_PARSE_ERROR raw_stdout={stdout[:500]} stderr={stderr[:500]}", proc.returncode, duration

    conclusion = None
    findings = []
    for item in parsed:
        if "ruleId" not in item and "conclusion" in item:
            conclusion = item["conclusion"]
        else:
            findings.append(item)  # kept exactly as returned by Solhint

    return findings, conclusion, stderr, proc.returncode, duration


def process_one(args_tuple):
    (contract_id, sol_path, solhint_bin, config_path, timeout,
     tool_version, dataset_root) = args_tuple

    scan_ts = datetime.now(timezone.utc).isoformat()

    if sol_path is None:
        return {
            "contract_id": contract_id,
            "source_file": None,
            "source_path": None,
            "status": "no_source_file",
            "duration_seconds": 0,
            "raw_conclusion": None,
            "error_count": 0,
            "warning_count": 0,
            "total_problems": 0,
            "stderr": "No .sol file found for this contract",
            "returncode": None,
            "raw_findings": [],  # exactly what Solhint returned (nothing here)
            "scan_timestamp": scan_ts,
        }

    findings_raw, conclusion, stderr, returncode, duration = run_solhint_on_file(
        solhint_bin, config_path, sol_path, timeout
    )

    m = CONCLUSION_RE.search(conclusion) if conclusion else None
    total_problems = int(m.group(1)) if m else len(findings_raw)
    error_count = int(m.group(2)) if m else sum(
        1 for f in findings_raw if str(f.get("severity", "")).lower() == "error"
    )
    warning_count = int(m.group(3)) if m else sum(
        1 for f in findings_raw if str(f.get("severity", "")).lower() == "warning"
    )

    status = "success"
    if returncode not in (0, 1):  # solhint returns 1 when it finds issues -- that is normal
        status = "tool_error"
    if stderr and not findings_raw and total_problems == 0:
        if "JSON_PARSE_ERROR" in (stderr or "") or "TIMEOUT" in (stderr or ""):
            status = "parse_or_timeout_error"

    rel_source = os.path.relpath(sol_path, dataset_root)

    return {
        "contract_id": contract_id,
        "source_file": os.path.basename(sol_path),
        "source_path": rel_source,
        "status": status,
        "duration_seconds": round(duration, 4),
        "raw_conclusion": conclusion,       # verbatim conclusion string from Solhint
        "error_count": error_count,
        "warning_count": warning_count,
        "total_problems": total_problems,
        "stderr": stderr or None,
        "returncode": returncode,
        "raw_findings": findings_raw,       # verbatim list of finding objects from Solhint
        "scan_timestamp": scan_ts,
        "tool_version": tool_version,
    }


def build_arg_parser():
    p = argparse.ArgumentParser(
        description="Scan Solidity contracts with Solhint. JSON output is 100%% raw; "
                    "CSV output is normalized with SWC/DASP mapping."
    )
    p.add_argument("--contracts-dir", required=True,
                    help="Root folder containing one subfolder per contract (each with sources/*.sol)")
    p.add_argument("--out-json", default="solhint_results_raw.json",
                    help="Output JSON file path (100%% raw Solhint output)")
    p.add_argument("--out-csv", default="solhint_results_normalized.csv",
                    help="Output CSV file path (normalized, includes SWC/DASP category)")
    p.add_argument("--solhint-bin", default=None,
                    help="Path to the solhint executable (defaults to searching PATH)")
    p.add_argument("--ruleset", default="solhint:all", choices=["solhint:all", "solhint:recommended"],
                    help="Ruleset to use: solhint:all (every rule -- default, maximum coverage) or solhint:recommended")
    p.add_argument("--workers", type=int, default=max(1, os.cpu_count() or 4),
                    help="Number of parallel workers to speed up scanning")
    p.add_argument("--timeout", type=int, default=60,
                    help="Max time in seconds to scan a single contract before it is marked as failed (timeout)")
    p.add_argument("--limit", type=int, default=None,
                    help="Only scan the first N contracts (useful for quick testing)")
    return p


def main():
    args = build_arg_parser().parse_args()

    contracts_dir = os.path.abspath(args.contracts_dir)
    solhint_bin = find_solhint_bin(args.solhint_bin)

    print(f"[*] Looking for the solhint executable: {solhint_bin}")
    tool_version = get_solhint_version(solhint_bin)
    print(f"[*] Solhint version: {tool_version}")

    print(f"[*] Discovering contracts under: {contracts_dir}")
    contracts = discover_contracts(contracts_dir)
    if args.limit:
        contracts = contracts[: args.limit]
    print(f"[*] Found {len(contracts)} file(s)/contract(s) to scan.")

    if not contracts:
        print("[!] No .sol files were found. Please check the path.")
        sys.exit(1)

    # Create a temporary solhint config file that enables all rules (or recommended)
    tmp_cfg_dir = tempfile.mkdtemp(prefix="solhint_cfg_")
    config_path = os.path.join(tmp_cfg_dir, ".solhint.json")
    with open(config_path, "w", encoding="utf-8") as fh:
        json.dump({"extends": args.ruleset}, fh)
    print(f"[*] Using ruleset: {args.ruleset} -> {config_path}")

    tasks = [
        (cid, sol, solhint_bin, config_path, args.timeout, tool_version, contracts_dir)
        for cid, sol in contracts
    ]

    results = []
    start_all = time.time()
    done = 0
    total = len(tasks)

    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as executor:
        futures = [executor.submit(process_one, t) for t in tasks]
        for fut in concurrent.futures.as_completed(futures):
            res = fut.result()
            results.append(res)
            done += 1
            if done % 10 == 0 or done == total:
                elapsed = time.time() - start_all
                print(f"    ... {done}/{total} scanned ({elapsed:.1f}s)", flush=True)

    # Sort results by contract name for stable output
    results.sort(key=lambda r: (r["contract_id"] or "", r["source_file"] or ""))

    total_findings = sum(len(r["raw_findings"]) for r in results)
    total_errors = sum(r["error_count"] for r in results)
    total_warnings = sum(r["warning_count"] for r in results)
    failed = [r for r in results if r["status"] != "success"]

    # ======================================================================
    # 1) RAW JSON OUTPUT -- exactly what Solhint produced, per contract.
    #    Only factual bookkeeping wraps it (which file, counts, timestamps).
    #    No SWC/DASP, no confidence, no derived/renamed fields anywhere here.
    # ======================================================================
    scan_info = {
        "tool": "Solhint",
        "tool_version": tool_version,
        "ruleset_used": args.ruleset,
        "dataset_dir": contracts_dir,
        "scan_date_utc": datetime.now(timezone.utc).isoformat(),
        "total_contracts_scanned": len(results),
        "total_raw_findings": total_findings,
        "total_errors": total_errors,
        "total_warnings": total_warnings,
        "contracts_failed_or_no_source": len(failed),
        "workers_used": args.workers,
        "timeout_per_contract_seconds": args.timeout,
        "total_duration_seconds": round(time.time() - start_all, 2),
    }

    raw_output_obj = {
        "scan_info": scan_info,
        "contracts": [
            {
                "contract_id": r["contract_id"],
                "source_file": r["source_file"],
                "source_path_relative": r["source_path"],
                "status": r["status"],
                "duration_seconds": r["duration_seconds"],
                "returncode": r["returncode"],
                "stderr": r["stderr"],
                "raw_conclusion": r["raw_conclusion"],     # verbatim string from Solhint
                "raw_findings": r["raw_findings"],         # verbatim list of finding objects from Solhint
                "scan_timestamp": r["scan_timestamp"],
            }
            for r in results
        ],
    }

    with open(args.out_json, "w", encoding="utf-8") as fh:
        json.dump(raw_output_obj, fh, ensure_ascii=False, indent=2)
    print(f"[+] Raw JSON file saved to: {args.out_json}")

    # ======================================================================
    # 2) NORMALIZED CSV OUTPUT -- one row per finding, with the common
    #    record {contract, tool, SWC/DASP category, severity, code_location}
    #    plus every other raw field, so nothing the tool can output is lost.
    # ======================================================================
    csv_columns = [
        "contract", "tool", "swc_id", "swc_title", "dasp_category",
        "severity", "code_location",
        "rule_id", "rule_type", "rule_category_label",
        "message", "line", "column", "end_line", "end_column", "fix_available",
        "source_file", "source_path_relative", "tool_version",
        "scan_status", "scan_timestamp",
    ]

    with open(args.out_csv, "w", newline="", encoding="utf-8-sig") as fh:
        writer = csv.DictWriter(fh, fieldnames=csv_columns)
        writer.writeheader()
        for r in results:
            if r["raw_findings"]:
                for f in r["raw_findings"]:
                    rule_id = f.get("ruleId", "unknown-rule")
                    rule_type, rule_category, swc_id, swc_title, dasp_category = RULE_MAP.get(
                        rule_id, UNKNOWN_RULE_DEFAULT
                    )
                    code_location = f"{r['source_path']}:{f.get('line')}:{f.get('column')}"
                    writer.writerow({
                        "contract": r["contract_id"],
                        "tool": "Solhint",
                        "swc_id": swc_id,
                        "swc_title": swc_title,
                        "dasp_category": dasp_category,
                        "severity": f.get("severity"),
                        "code_location": code_location,
                        "rule_id": rule_id,
                        "rule_type": rule_type,
                        "rule_category_label": rule_category,
                        "message": f.get("message"),
                        "line": f.get("line"),
                        "column": f.get("column"),
                        "end_line": f.get("endLine"),
                        "end_column": f.get("endColumn"),
                        "fix_available": bool(f.get("fix")),
                        "source_file": r["source_file"],
                        "source_path_relative": r["source_path"],
                        "tool_version": r["tool_version"],
                        "scan_status": r["status"],
                        "scan_timestamp": r["scan_timestamp"],
                    })
            else:
                # A contract with no findings at all (or a failed scan) still gets one
                # row, so it is never silently dropped from the statistics.
                writer.writerow({
                    "contract": r["contract_id"],
                    "tool": "Solhint",
                    "swc_id": "N/A",
                    "swc_title": "N/A",
                    "dasp_category": "N/A",
                    "severity": "None",
                    "code_location": "N/A",
                    "rule_id": "NO_FINDINGS" if r["status"] == "success" else "SCAN_FAILED",
                    "rule_type": "N/A",
                    "rule_category_label": "N/A",
                    "message": r["stderr"] if r["status"] != "success" else "No issues found by Solhint",
                    "line": None, "column": None, "end_line": None, "end_column": None,
                    "fix_available": False,
                    "source_file": r["source_file"],
                    "source_path_relative": r["source_path"],
                    "tool_version": r["tool_version"],
                    "scan_status": r["status"],
                    "scan_timestamp": r["scan_timestamp"],
                })

    print(f"[+] Normalized CSV file saved to: {args.out_csv}")

    print("\n===== Scan Summary =====")
    for k, v in scan_info.items():
        print(f"  {k}: {v}")
    if failed:
        print(f"\n[!] Warning: {len(failed)} contract(s) did not scan successfully (check 'status' in the CSV/JSON).")

    shutil.rmtree(tmp_cfg_dir, ignore_errors=True)


if __name__ == "__main__":
    main()
