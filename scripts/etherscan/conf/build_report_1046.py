#!/usr/bin/env python3
"""
ConFuzzius Report Builder
==========================

Aggregates raw per-contract JSON results (produced by run_hybrid_1046.py)
into two final deliverables:

    1. A flat CSV summary  - one row per finding, easy to open in Excel.
    2. A flat JSON dataset - one independent record per finding (NOT nested
       inside a per-contract object), so every finding can be filtered,
       sorted and manually reviewed without navigating nested structures.

Every record (CSV row / JSON object) carries the following mandatory
fields, even when the underlying tool does not provide a value for them
(in which case the field is present but set to null / empty):

    contract, tool, category (SWC/DASP), severity, code_location, confidence

No field emitted by ConFuzzius is discarded - all raw data (transaction
details, coverage statistics, timing, raw error logs) is preserved in the
JSON output for later manual verification and consensus labeling.

Author: [project team]
"""

import csv
import json
import os
import datetime

# --------------------------------------------------------------------------
# Configuration
# --------------------------------------------------------------------------
BASE = os.path.expanduser("~/dataset_1046/dataset_merged_all_clean_v9")
OFFLINE_DIR = os.path.join(BASE, "results")
ONCHAIN_DIR = os.path.join(BASE, "results_onchain")

OUT_CSV = os.path.join(BASE, "confuzzius_results_1046.csv")
OUT_JSON = os.path.join(BASE, "confuzzius_results_1046.json")

TOOL_NAME = "ConFuzzius"

# Official SWC Registry titles (extend this dict as new SWC IDs are observed)
SWC_TITLES = {
    101: "Integer Overflow and Underflow",
    104: "Unchecked Call Return Value",
    110: "Assertion Violation",
    112: "Delegatecall to Untrusted Callee",
    113: "DoS with Failed Call",
    114: "Transaction Order Dependence",
    120: "Weak Sources of Randomness from Chain Attributes",
    123: "Requirement Violation",
}

# Known failure-signature -> human readable explanation
FAILURE_REASONS = {
    "tuple": "Tool limitation: ConFuzzius's encoder does not support "
             "generating random values for tuple/struct parameters "
             "(nested or array-of-struct types).",
    "no compiler output": "Compilation failure: solc could not produce "
             "output for this source file (likely missing imports or "
             "unresolved dependencies).",
}


def load_dataset_index():
    """Load dataset.csv into a list of dict rows, preserving file order."""
    with open(os.path.join(BASE, "dataset.csv"), encoding="utf-8-sig") as f:
        return list(csv.DictReader(f))


def load_result(address, contract_name):
    """Return (result_dict, method) for a contract, checking offline first,
    then on-chain. Returns (None, None) if no result file exists."""
    offline_path = os.path.join(OFFLINE_DIR, f"{address}.json")
    onchain_path = os.path.join(ONCHAIN_DIR, f"{address}.json")

    if os.path.exists(offline_path):
        with open(offline_path) as f:
            data = json.load(f)
        return data.get(contract_name, next(iter(data.values()))), "offline"

    if os.path.exists(onchain_path):
        with open(onchain_path) as f:
            data = json.load(f)
        return data.get(address, next(iter(data.values()))), "on-chain"

    return None, None


def load_failure_reason(address):
    """Return (human_readable_reason, raw_error_text) for a failed contract,
    or (None, None) if no error log exists."""
    err_path = os.path.join(OFFLINE_DIR, f"{address}_ERROR.txt")
    if not os.path.exists(err_path):
        return None, None

    with open(err_path) as f:
        content = f.read()

    reason = "Unknown failure - see raw_error_log field for details."
    lowered = content.lower()
    for signature, explanation in FAILURE_REASONS.items():
        if signature in lowered:
            reason = explanation
            break

    return reason, content


def extract_contract_stats(result):
    """Extract contract-level scan statistics (coverage, timing, memory)."""
    generations = result.get("generations", [])
    return {
        "generations_count": len(generations),
        "total_transactions": result.get("transactions", {}).get("total"),
        "unique_transactions": (
            generations[-1].get("unique_transactions") if generations else None
        ),
        "transactions_per_second": result.get("transactions", {}).get("per_second"),
        "code_coverage_percent": result.get("code_coverage", {}).get("percentage"),
        "code_coverage_covered": result.get("code_coverage", {}).get("covered"),
        "code_coverage_total": result.get("code_coverage", {}).get("total"),
        "branch_coverage_percent": result.get("branch_coverage", {}).get("percentage"),
        "branch_coverage_covered": result.get("branch_coverage", {}).get("covered"),
        "branch_coverage_total": result.get("branch_coverage", {}).get("total"),
        "execution_time_seconds": result.get("execution_time"),
        "memory_consumption_mb": result.get("memory_consumption"),
        "address_under_test": result.get("address_under_test"),
        "fuzzer_seed": result.get("seed"),
    }


def make_base_record(n, address, contract_name, compiler_version, source_file,
                      timestamp):
    """Fields shared by every record, regardless of outcome."""
    return {
        "n": n,
        "contract": address,
        "contract_name": contract_name,
        "compiler_version": compiler_version,
        "source_file": source_file,
        "tool": TOOL_NAME,
        "scan_timestamp": timestamp,
    }


def build_failed_record(base, reason, raw_error):
    record = dict(base)
    record.update({
        "method": None,
        "rule": "",
        "category": "",
        "swc": None,
        "swc_title": None,
        "severity": None,
        "code_location": None,
        "confidence": None,   # not provided by ConFuzzius
        "status": "Failed",
        "description": reason,
        "raw_error_log": raw_error,
        "contract_stats": None,
    })
    return record


def build_clean_record(base, method, result, stats):
    record = dict(base)
    record.update({
        "method": method,
        "rule": "",
        "category": "No Issues",
        "swc": None,
        "swc_title": None,
        "severity": None,
        "code_location": None,
        "confidence": None,
        "status": "Success",
        "description": "No vulnerabilities detected.",
        "contract_stats": stats,
    })
    # Preserve any additional raw fields from the tool without overwriting
    # keys we already defined above.
    for key, value in result.items():
        if key not in record:
            record[key] = value
    return record


def build_finding_records(base, method, errors, stats):
    """Yield one flat record per individual finding (never nested)."""
    for bytecode_pc, findings_list in errors.items():
        for finding in findings_list:
            swc_id = finding.get("swc_id")
            swc_title = SWC_TITLES.get(swc_id, "Unknown / not yet mapped")
            vuln_type = finding.get("type", "")
            severity = finding.get("severity")
            individual = finding.get("individual", [])
            transaction = individual[0].get("transaction") if individual else None

            description = (
                f"{vuln_type} (SWC-{swc_id}: {swc_title}) detected at "
                f"bytecode location {bytecode_pc}."
            )

            record = dict(base)
            record.update({
                "method": method,
                "rule": f"SWC-{swc_id}" if swc_id is not None else "",
                "category": vuln_type,
                "swc": swc_id,
                "swc_title": swc_title,
                "severity": severity,
                "code_location": bytecode_pc,
                "confidence": None,  # not provided by ConFuzzius
                "status": "Success",
                "description": description,
                "detection_time_seconds": finding.get("time"),
                "transaction": transaction,
                "full_individual_data": individual,
                "contract_stats": stats,
            })
            yield record


def main():
    contracts = load_dataset_index()
    timestamp = datetime.datetime.now().isoformat()

    all_records = []

    for n, row in enumerate(contracts, 1):
        address = row["address"]
        contract_name = row["contract_name"]
        compiler_version = row["compiler_version"]
        source_file = row.get("source_files", "")

        base = make_base_record(
            n, address, contract_name, compiler_version, source_file, timestamp
        )

        result, method = load_result(address, contract_name)

        if result is None:
            reason, raw_error = load_failure_reason(address)
            all_records.append(build_failed_record(base, reason, raw_error))
            continue

        errors = result.get("errors", {})
        stats = extract_contract_stats(result)

        if not errors:
            all_records.append(build_clean_record(base, method, result, stats))
            continue

        all_records.extend(build_finding_records(base, method, errors, stats))

    # ----------------------------------------------------------------
    # Write CSV (flat summary)
    # ----------------------------------------------------------------
    csv_fieldnames = [
        "n", "contract", "tool", "rule", "category", "severity",
        "code_location", "confidence", "status", "description",
    ]
    with open(OUT_CSV, "w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=csv_fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(all_records)

    # ----------------------------------------------------------------
    # Write JSON (flat, fully detailed)
    # ----------------------------------------------------------------
    with open(OUT_JSON, "w", encoding="utf-8") as f:
        json.dump(all_records, f, indent=2, ensure_ascii=False)

    print(f"[INFO] Total records written: {len(all_records)}")
    print(f"[INFO] CSV  -> {OUT_CSV}")
    print(f"[INFO] JSON -> {OUT_JSON}")


if __name__ == "__main__":
    main()