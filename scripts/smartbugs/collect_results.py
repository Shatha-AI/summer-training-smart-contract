
import csv
import re
import json
from pathlib import Path
from collections import Counter, defaultdict

BASE = Path(__file__).resolve().parent

SLITHER_FILE = BASE.parent / "results/smartBugs_results/Slither_results.csv"
SMARTCHECK_FILE = BASE.parent / "results/smartBugs_results/smartcheck_results.csv"
SOLHINT_FILE = BASE.parent / "results/smartBugs_results/solhint_results.csv"
MYTHRIL_FILE = BASE.parent / "results/smartBugs_results/mythril_results.csv"
CONFUZZIUS_FILE = BASE.parent / "results/smartBugs_results/confuzzius_results.csv"

RULE_MAPPING_FILE = BASE.parent / "dataset/rule_mapping_updated.csv"
SWC_MAPPING_FILE = BASE.parent / "dataset/swc_to_dasp.csv"

OUT_FILE = BASE.parent / "results/smartBugs_results/validation.csv"
UNMAPPED_LOG_FILE = BASE.parent / "results/smartBugs_results/unmapped_rules_log_validation.csv"

unmapped_log = []

def clean_contract_key(raw: str) -> str:
    if not raw:
        return ""
    name = raw.replace("\\", "/").rsplit("/", 1)[-1]
    if name.lower().endswith(".sol"):
        name = name[:-4]
    return name.strip().lower()
 
 
def normalize_swc(raw) -> str:
    if raw is None:
        return ""
    s = str(raw).strip()
    if not s:
        return ""
    return s if s.upper().startswith("SWC-") else f"SWC-{s}"
 
 
def load_rule_mapping(path: Path):
    mapping, excluded = {}, set()
    with path.open(newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            key = (row["tool"], row["rule"])
            if row["category"] == "NON_SECURITY":
                excluded.add(key)
            else:
                mapping[key] = row["category"]
    return mapping, excluded
 
 
def load_swc_mapping(path: Path):
    with path.open(newline="", encoding="utf-8") as f:
        return {row["swc_id"]: row["category"] for row in csv.DictReader(f)}
 
 
def log_unmapped(tool, rule_or_swc, contract, description=""):
    unmapped_log.append({
        "tool": tool, "rule_or_swc": rule_or_swc,
        "example_contract": contract, "example_description": (description or "")[:150],
    })
 
def build_ground_truth():
    gt = {}
    conflicts = []
 
    with SLITHER_FILE.open(newline="", encoding="utf-8-sig") as f:
        for row in csv.DictReader(f):
            key = clean_contract_key(row["Contract"])
            cat = row["Category"]
            if key in gt and gt[key] != cat:
                conflicts.append((key, gt[key], cat, "slither"))
            gt[key] = cat
 
    with SOLHINT_FILE.open(newline="", encoding="utf-8-sig") as f:
        for row in csv.DictReader(f):
            raw_path = row["contract"]
            parts = raw_path.replace("\\", "/").split("/")
            if len(parts) >= 2:
                key = clean_contract_key(parts[-1])
                cat = parts[-2]
                if key in gt and gt[key] != cat:
                    conflicts.append((key, gt[key], cat, "solhint"))
                gt.setdefault(key, cat)
 
    print(f"[ground_truth] known contracts: {len(gt)}")
    if conflicts:
        print(f"[!!!] ground truth conflict between Slither/Solhint for {len(conflicts)} contract(s):")
        for c in conflicts[:5]:
            print("   ", c)
    return gt
 
 
def process_slither(mapping, excluded, gt):
    with SLITHER_FILE.open(newline="", encoding="utf-8-sig") as f:
        rows = list(csv.DictReader(f))
 
    seen = set()
    findings = []
    unmapped_c, excluded_c = Counter(), Counter()
 
    for r in rows:
        sig = tuple(r.values())
        if sig in seen:
            continue
        seen.add(sig)
 
        contract_key = clean_contract_key(r["Contract"])
        rule = r["Vulnerability Type"]
        map_key = ("slither", rule)
 
        if map_key in excluded:
            excluded_c[rule] += 1
            continue
        if map_key not in mapping:
            unmapped_c[rule] += 1
            log_unmapped("slither", rule, contract_key)
            detected_category = "UNMAPPED"
        else:
            detected_category = mapping[map_key]
 
        findings.append({
            "contract": contract_key, "ground_truth_category": gt.get(contract_key, ""),
            "tool": "slither", "rule": rule,
            "detected_category": detected_category, "severity": r["Severity"],
        })
 
    print(f"[slither] raw rows: {len(rows)} | after dedup: {len(seen)} | "
          f"excluded: {sum(excluded_c.values())} | unmapped: {sum(unmapped_c.values())} | final: {len(findings)}")
    return findings
 
 
def process_smartcheck(mapping, excluded, gt):
    with SMARTCHECK_FILE.open(newline="", encoding="utf-8-sig") as f:
        rows = list(csv.DictReader(f))
 
    block_re = re.compile(
        r"ruleId:\s*(?P<rule>\S+)\s*(?:patternId:\s*\S+\s*)?severity:\s*(?P<severity>\S+)\s*line:\s*(?P<line>\d+)?",
        re.MULTILINE,
    )
 
    findings = []
    unmapped_c, excluded_c = Counter(), Counter()
    raw_total = 0
 
    for r in rows:
        contract_key = clean_contract_key(r["contract"])
        blob = r["output"]
        matches = list(block_re.finditer(blob))
        raw_total += len(matches)
 
        for m in matches:
            rule = m.group("rule")
            map_key = ("smartcheck", rule)
 
            if map_key in excluded:
                excluded_c[rule] += 1
                continue
            if map_key not in mapping:
                unmapped_c[rule] += 1
                log_unmapped("smartcheck", rule, contract_key)
                detected_category = "UNMAPPED"
            else:
                detected_category = mapping[map_key]
 
            findings.append({
                "contract": contract_key, "ground_truth_category": gt.get(contract_key, ""),
                "tool": "smartcheck", "rule": rule,
                "detected_category": detected_category, "severity": m.group("severity"),
            })
 
    print(f"[smartcheck] findings extracted: {raw_total} | excluded: {sum(excluded_c.values())} | "
          f"unmapped: {sum(unmapped_c.values())} | final: {len(findings)}")
    return findings
 
 

def process_solhint(mapping, excluded, gt):
    with SOLHINT_FILE.open(newline="", encoding="utf-8-sig") as f:
        rows = list(csv.DictReader(f))
 
    findings = []
    unmapped_c, excluded_c = Counter(), Counter()
    skipped_empty = 0
 
    for r in rows:
        rule = r["rule"]
        if not rule:
            skipped_empty += 1  # صف ملخّص فاضي (مثل conclusion) — مو finding حقيقية
            continue
 
        contract_key = clean_contract_key(r["contract"])
        map_key = ("solhint", rule)
 
        if map_key in excluded:
            excluded_c[rule] += 1
            continue
        if map_key not in mapping:
            unmapped_c[rule] += 1
            log_unmapped("solhint", rule, contract_key, r.get("message", ""))
            detected_category = "UNMAPPED"
        else:
            detected_category = mapping[map_key]
 
        findings.append({
            "contract": contract_key, "ground_truth_category": gt.get(contract_key, ""),
            "tool": "solhint", "rule": rule,
            "detected_category": detected_category, "severity": r.get("severity", ""),
        })
 
    print(f"[solhint] raw rows: {len(rows)} | empty rows skipped: {skipped_empty} | excluded: {sum(excluded_c.values())} | "
          f"unmapped: {sum(unmapped_c.values())} | final: {len(findings)}")
    return findings
 
def process_mythril(swc_map, gt):
    with MYTHRIL_FILE.open(newline="", encoding="utf-8-sig") as f:
        rows = list(csv.DictReader(f))
 
    findings = []
    unmapped_c = Counter()
    skipped = 0
 
    for r in rows:
        if r.get("status") not in ("Detected", "Success", None) and r.get("category") in ("No Issues", ""):
            skipped += 1
            continue
        if not r.get("rule"):
            skipped += 1
            continue
 
        contract_key = clean_contract_key(r["contract"])
        swc = normalize_swc(r["rule"])
        detected_category = swc_map.get(swc, "UNMAPPED")
        if detected_category == "UNMAPPED":
            unmapped_c[swc] += 1
            log_unmapped("mythril", swc, contract_key, r.get("description", ""))
 
        findings.append({
            "contract": contract_key, "ground_truth_category": gt.get(contract_key, ""),
            "tool": "mythril", "rule": swc,
            "detected_category": detected_category, "severity": r.get("severity", ""),
        })
 
    print(f"[mythril] raw rows: {len(rows)} | skipped (no rule): {skipped} | "
          f"unmapped: {sum(unmapped_c.values())} | final: {len(findings)}")
    return findings
 

def process_confuzzius(swc_map, gt):
    with CONFUZZIUS_FILE.open(newline="", encoding="utf-8-sig") as f:
        rows = list(csv.DictReader(f))
 
    findings = []
    unmapped_c = Counter()
    skipped = 0
 
    for r in rows:
        if not r.get("swc"):
            skipped += 1
            continue
 
        contract_key = clean_contract_key(r["contract"])
        swc = normalize_swc(r["swc"])
        detected_category = swc_map.get(swc, "UNMAPPED")
        if detected_category == "UNMAPPED":
            unmapped_c[swc] += 1
            log_unmapped("confuzzius", swc, contract_key, r.get("category", ""))
 
        findings.append({
            "contract": contract_key, "ground_truth_category": gt.get(contract_key, ""),
            "tool": "confuzzius", "rule": swc,
            "detected_category": detected_category, "severity": r.get("severity", ""),
        })
 
    print(f"[confuzzius] raw rows: {len(rows)} | skipped (no swc): {skipped} | "
          f"unmapped: {sum(unmapped_c.values())} | final: {len(findings)}")
    return findings
 
 
def main():
    mapping, excluded = load_rule_mapping(RULE_MAPPING_FILE)
    swc_map = load_swc_mapping(SWC_MAPPING_FILE)
    gt = build_ground_truth()
 
    all_findings = []
    all_findings += process_slither(mapping, excluded, gt)
    all_findings += process_smartcheck(mapping, excluded, gt)
    all_findings += process_solhint(mapping, excluded, gt)
    all_findings += process_mythril(swc_map, gt)
    all_findings += process_confuzzius(swc_map, gt)
 
    no_gt = sum(1 for f in all_findings if not f["ground_truth_category"])
    print(f"\n{'='*55}")
    print(f"Total merged findings: {len(all_findings)}")
    print("Breakdown by tool:", dict(Counter(f['tool'] for f in all_findings)))
    print(f"Findings without ground truth (unknown contract): {no_gt}")
 
    fields = ["contract", "ground_truth_category", "tool", "rule", "detected_category", "severity"]
    with OUT_FILE.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        writer.writerows(all_findings)
    print(f"\n[+] Output file: {OUT_FILE}")
 
    seen_keys = set()
    unique_unmapped = []
    for u in unmapped_log:
        k = (u["tool"], u["rule_or_swc"])
        if k not in seen_keys:
            seen_keys.add(k)
            unique_unmapped.append(u)
    with UNMAPPED_LOG_FILE.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=["tool", "rule_or_swc", "example_contract", "example_description"])
        w.writeheader()
        w.writerows(unique_unmapped)
    if unique_unmapped:
        print(f"[!!!] {len(unique_unmapped)} new unmapped rule(s)/SWC(s) -> review {UNMAPPED_LOG_FILE}")
    else:
        print(f"[+] No new unmapped rules.")
 
 
if __name__ == "__main__":
    main()