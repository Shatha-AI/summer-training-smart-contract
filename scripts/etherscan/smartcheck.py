import pandas as pd
import subprocess
import os
import json
import re
from datetime import datetime

# ============================== CONFIG ==============================
base_dir = r"C:\Users\Mayas\dataset_merged_all_clean_v9"
smartcheck_cmd = r"C:\Users\Mayas\AppData\Roaming\npm\smartcheck.cmd"
results_dir = r"C:\Users\Mayas\run_smartcheck_full"
# ====================================================================

SEVERITY_LABELS = {1: "low", 2: "medium", 3: "high"}

df = pd.read_csv(os.path.join(base_dir, "dataset.csv"))
print(f"Loaded {len(df)} contracts")
print(f"Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
print("=" * 60)

csv_summary = []
json_flat = []
flat_findings = []

for idx, row in df.iterrows():
    source_file = os.path.join(base_dir, row["source_files"])
    contract_name = row["contract_name"]
    address = row["address"]
    compiler = row["compiler_version"]
    category = row["category"]
    contract_number = idx + 1

    print(f"[{contract_number}/{len(df)}] {contract_name} ({compiler})")

    try:
        process = subprocess.run(
            [smartcheck_cmd, "-p", source_file],
            capture_output=True,
            text=True,
            timeout=60
        )
        clean = "\n".join(l for l in process.stdout.split("\n") if "Warning:" not in l)
        status = "success"
        error_msg = None
    except subprocess.TimeoutExpired:
        clean = ""
        status = "timeout"
        error_msg = "Analysis exceeded 60s timeout"
    except Exception as e:
        clean = ""
        status = "error"
        error_msg = str(e)[:200]

    findings = []
    for block in re.split(r"(?=ruleId:)", clean):
        r = re.search(r"ruleId:\s*(SOLIDITY_\w+)", block)
        if not r:
            continue

        rule_id = r.group(1)
        pattern = re.search(r"patternId:\s*(\w+)", block)
        sev = re.search(r"severity:\s*(\d+)", block)
        ln = re.search(r"line:\s*(\d+)", block)
        co = re.search(r"column:\s*(\d+)", block)
        ct = re.search(r"content:\s*(.+?)(?:\n|$)", block)

        sev_num = int(sev.group(1)) if sev else None
        line_num = int(ln.group(1)) if ln else None
        col_num = int(co.group(1)) if co else None
        content = ct.group(1).strip() if ct else None

        record = {
            "contract_number": contract_number,
            "contract_address": address,
            "contract_name": contract_name,
            "compiler_version": compiler,
            "contract_category": category,
            "tool": "SmartCheck",
            "ruleId": rule_id,
            "patternId": pattern.group(1) if pattern else None,
            "severity": sev_num,
            "severity_label": SEVERITY_LABELS.get(sev_num, "unknown"),
            "line": line_num,
            "column": col_num,
            "code_location": f"line {line_num}, col {col_num}" if line_num else None,
            "content": content,
            "confidence": "pattern-based"
        }

        findings.append(record)
        json_flat.append(record)
        flat_findings.append(record)

    if len(findings) == 0:
        json_flat.append({
            "contract_number": contract_number,
            "contract_address": address,
            "contract_name": contract_name,
            "compiler_version": compiler,
            "contract_category": category,
            "tool": "SmartCheck",
            "ruleId": None,
            "patternId": None,
            "severity": None,
            "severity_label": None,
            "line": None,
            "column": None,
            "code_location": None,
            "content": None,
            "confidence": None,
            "status": status,
            "error": error_msg
        })

    unique_rules = list(set(f["ruleId"] for f in findings))

    csv_summary.append({
        "contract_number": contract_number,
        "contract_address": address,
        "contract_name": contract_name,
        "compiler_version": compiler,
        "category": category,
        "status": status,
        "total_findings": len(findings),
        "unique_rules": "; ".join(unique_rules),
        "error": error_msg
    })

# ============================== SAVE ==============================
os.makedirs(results_dir, exist_ok=True)

pd.DataFrame(csv_summary).to_csv(
    os.path.join(results_dir, "smartcheck_summary.csv"), index=False
)

if flat_findings:
    pd.DataFrame(flat_findings).to_csv(
        os.path.join(results_dir, "smartcheck_detailed.csv"), index=False
    )

with open(os.path.join(results_dir, "smartcheck_results.json"), "w", encoding="utf-8") as f:
    json.dump(json_flat, f, indent=2, ensure_ascii=False)

# ============================== REPORT ==============================
total_findings = len(flat_findings)
success_count = len([r for r in csv_summary if r["status"] == "success"])
with_findings = len([r for r in csv_summary if r["total_findings"] > 0])

rule_freq = {}
for f in flat_findings:
    rule_freq[f["ruleId"]] = rule_freq.get(f["ruleId"], 0) + 1

sev_freq = {}
for f in flat_findings:
    sev_freq[f["severity_label"]] = sev_freq.get(f["severity_label"], 0) + 1

print("\n" + "=" * 60)
print("SCAN COMPLETE")
print("=" * 60)
print(f"Total contracts:        {len(df)}")
print(f"Scanned successfully:   {success_count}")
print(f"With findings:          {with_findings}")
print(f"No findings:            {success_count - with_findings}")
print(f"Errors/Timeouts:        {len(df) - success_count}")
print(f"Total findings:         {total_findings}")
print(f"\nTop rules:")
for rule, count in sorted(rule_freq.items(), key=lambda x: -x[1])[:10]:
    print(f"  {rule}: {count}")
print(f"\nSeverity distribution:")
for sev, count in sev_freq.items():
    print(f"  {sev}: {count}")
print(f"\nFiles saved to: {results_dir}")
print(f"  smartcheck_summary.csv     (one row per contract)")
print(f"  smartcheck_detailed.csv    (one row per finding)")
print(f"  smartcheck_results.json    (one record per finding)")
