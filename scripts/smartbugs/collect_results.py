"""
validate_normalize.py
----------------------
يطبّع نواتج الأدوات الخمسة (Slither, SmartCheck, Solhint, Mythril,
ConFuzzius) على الداتاست المُعلّم (SmartBugs Curated) ويدمجها بملف
واحد فيه لكل finding: العقد، الفئة الحقيقية (ground_truth_category)،
الأداة، والفئة المكتشفة (detected_category) — جاهز مباشرة لحساب
TP / FP / FN / TN بالخطوة الجاية.

الاستخدام:
    python validate_normalize.py
(حطّ الملفات الخمسة + rule_mapping_updated.csv + swc_to_dasp.csv
 بنفس مجلد السكريبت، أو عدّل BASE)
"""

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

OUT_FILE = BASE.parent / "results/smartBugs_results/findings_validation.csv"
UNMAPPED_LOG_FILE = BASE.parent / "results/smartBugs_results/unmapped_rules_log_validation.csv"

unmapped_log = []


# ------------------------------------------------------------------
# أدوات مساعدة عامة
# ------------------------------------------------------------------
def clean_contract_key(raw: str) -> str:
    """يوحّد أي صيغة اسم عقد (مسار كامل، بادئة مجلد، امتداد .sol) إلى
    مفتاح واحد قابل للمطابقة بين كل الأدوات."""
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


# ------------------------------------------------------------------
# 1) بناء خريطة ground truth من مصدرين موثوقين (Slither + Solhint)
#    ونتحقق من عدم التعارض بينهم
# ------------------------------------------------------------------
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

    print(f"[ground_truth] عدد العقود المعروفة: {len(gt)}")
    if conflicts:
        print(f"[!!!] تعارض بمصدر ground truth بين Slither/Solhint لـ {len(conflicts)} عقد:")
        for c in conflicts[:5]:
            print("   ", c)
    return gt


# ------------------------------------------------------------------
# 2) SLITHER — إزالة تكرار + تصنيف من rule (مو من category الموجود)
# ------------------------------------------------------------------
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

    print(f"[slither] صفوف خام: {len(rows)} | بعد إزالة التكرار: {len(seen)} | "
          f"مستبعدة: {sum(excluded_c.values())} | بدون تصنيف: {sum(unmapped_c.values())} | نهائي: {len(findings)}")
    return findings


# ------------------------------------------------------------------
# 3) SMARTCHECK — تفكيك الـ blob (مثل ما سوينا قبل)
# ------------------------------------------------------------------
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

    print(f"[smartcheck] findings مستخرجة: {raw_total} | مستبعدة: {sum(excluded_c.values())} | "
          f"بدون تصنيف: {sum(unmapped_c.values())} | نهائي: {len(findings)}")
    return findings


# ------------------------------------------------------------------
# 4) SOLHINT — تطبيع المسار وتطبيق mapping
# ------------------------------------------------------------------
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

    print(f"[solhint] صفوف خام: {len(rows)} | صفوف فاضية متجاوزة: {skipped_empty} | مستبعدة: {sum(excluded_c.values())} | "
          f"بدون تصنيف: {sum(unmapped_c.values())} | نهائي: {len(findings)}")
    return findings


# ------------------------------------------------------------------
# 5) MYTHRIL — rule هو رقم SWC
# ------------------------------------------------------------------
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

    print(f"[mythril] صفوف خام: {len(rows)} | متجاوزة (لا rule): {skipped} | "
          f"بدون تصنيف: {sum(unmapped_c.values())} | نهائي: {len(findings)}")
    return findings


# ------------------------------------------------------------------
# 6) CONFUZZIUS — عمود swc جاهز
# ------------------------------------------------------------------
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

    print(f"[confuzzius] صفوف خام: {len(rows)} | متجاوزة (لا swc): {skipped} | "
          f"بدون تصنيف: {sum(unmapped_c.values())} | نهائي: {len(findings)}")
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
    print(f"إجمالي findings المدمجة: {len(all_findings)}")
    print("توزيعها حسب الأداة:", dict(Counter(f['tool'] for f in all_findings)))
    print(f"findings بدون ground truth (عقد غير معروف بالمصدرين): {no_gt}")

    fields = ["contract", "ground_truth_category", "tool", "rule", "detected_category", "severity"]
    with OUT_FILE.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        writer.writerows(all_findings)
    print(f"\n[+] الملف النهائي: {OUT_FILE}")

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
        print(f"[!!!] {len(unique_unmapped)} قاعدة/SWC جديدة غير مصنّفة -> راجع {UNMAPPED_LOG_FILE}")
    else:
        print(f"[+] لا يوجد قواعد جديدة غير مصنّفة.")


if __name__ == "__main__":
    main()