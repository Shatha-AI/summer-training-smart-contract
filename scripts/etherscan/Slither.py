import csv
import json
import re
import subprocess
import tempfile
import time
from pathlib import Path



PROJECT_DIR = Path(__file__).resolve().parent


CONTRACTS_MODE = "nested"

CONTRACTS_DIR = PROJECT_DIR / "contracts"

RESULTS_DIR = PROJECT_DIR / "results_analysis"
SUMMARY_FILE = RESULTS_DIR / "all_summary.csv"
UNIFIED_REPORT_FILE = PROJECT_DIR / "unified_report_final.json"


PREFERRED_SOLC_08 = "0.8.24"


ENABLE_COMPATIBILITY_PATCH = True


RETRY_FAILED_STATUSES = {"slither_error", "solc_error"}

TOOL_NAME = "Slither"



CATEGORY_RULES = [
    (r"reentran", "Reentrancy"),
    (r"suicidal|selfdestruct", "Access Control"),
    (r"access-control|owner|onlyowner|arbitrary-send", "Access Control"),
    (r"overflow|underflow|divide-before-multiply", "Arithmetic"),
    (r"unchecked-(transfer|lowlevel|send)", "Unchecked Calls"),
    (r"low-level-calls", "Unchecked Calls"),
    (r"timestamp|block-other-parameters|weak-prng", "Bad Randomness / Time Manipulation"),
    (r"reused-constructor|shadowing", "Code Quality"),
    (r"naming-convention|solc-version|pragma|assembly", "Best Practices"),
    (r"uninitialized|unused|dead-code", "Code Quality"),
    (r"tx-origin", "Access Control"),
    (r"delegatecall", "Proxy / Delegatecall"),
    (r"erc20|erc721", "Token Standard Compliance"),
    (r"external-function|constable-states|state-visibility", "Best Practices"),
]


def categorize(rule: str) -> str:
    rule_lower = (rule or "").lower()
    for pattern, category in CATEGORY_RULES:
        if re.search(pattern, rule_lower):
            return category
    return "Other"




SWC_MAPPING = {
    "reentrancy-eth": "SWC-107",
    "reentrancy-no-eth": "SWC-107",
    "reentrancy-benign": "SWC-107",
    "reentrancy-events": "SWC-107",
    "reentrancy-unlimited-gas": "SWC-107",
    "suicidal": "SWC-106",
    "arbitrary-send": "SWC-105",
    "arbitrary-send-eth": "SWC-105",
    "controlled-delegatecall": "SWC-112",
    "delegatecall-loop": "SWC-112",
    "tx-origin": "SWC-115",
    "timestamp": "SWC-116",
    "weak-prng": "SWC-120",
    "block-other-parameters": "SWC-116",
    "unchecked-transfer": "SWC-104",
    "unchecked-lowlevel": "SWC-104",
    "unchecked-send": "SWC-104",
    "low-level-calls": "SWC-104",
    "integer-overflow": "SWC-101",
    "divide-before-multiply": "SWC-101",
    "uninitialized-state": "SWC-109",
    "uninitialized-storage": "SWC-109",
    "uninitialized-local": "SWC-109",
    "locked-ether": "SWC-132",
    "shadowing-state": "SWC-119",
    "shadowing-local": "SWC-119",
    "shadowing-abstract": "SWC-119",
    "shadowing-builtin": "SWC-119",
    "erc20-interface": "N/A",
    "erc721-interface": "N/A",
    "constant-function-asm": "N/A",
    "constant-function-state": "N/A",
    "solc-version": "SWC-102",
    "pragma": "SWC-103",
    "naming-convention": "N/A",
    "external-function": "N/A",
    "unused-return": "SWC-104",
    "unused-state": "N/A",
    "dead-code": "N/A",
    "constable-states": "N/A",
    "state-visibility": "N/A",
    "assembly": "N/A",
    "boolean-cst": "N/A",
    "controlled-array-length": "N/A",
    "tautology": "N/A",
    "incorrect-equality": "SWC-132",
}


def get_swc_id(rule: str) -> str:
    return SWC_MAPPING.get((rule or "").strip(), "N/A")




def extract_solidity_version(content: str):
    
    
    pragma_bodies = re.findall(r"pragma\s+solidity\s+([^;]+);", content)
    if not pragma_bodies:
        return None

    candidates = []
    for body in pragma_bodies:
        for op_match in re.finditer(r"(<=|>=|\^|>|<|=)?\s*(\d+\.\d+\.\d+)", body):
            operator, version = op_match.groups()
            if operator in ("<", "<="):
                continue  # exclusive/inclusive upper bound, not a target
            candidates.append(version)

    if not candidates:
        return None

    selected = max(candidates, key=lambda v: tuple(int(part) for part in v.split(".")))


    preferred_tuple = tuple(int(part) for part in PREFERRED_SOLC_08.split("."))
    selected_tuple = tuple(int(part) for part in selected.split("."))

    if selected_tuple[:2] == (0, 8) and selected_tuple < preferred_tuple:
        permits_preferred = True
        has_flexible_08_constraint = False

        for body in pragma_bodies:
            for match in re.finditer(r"(<=|>=|\^|>|<|=)?\s*(\d+\.\d+\.\d+)", body):
                operator, version = match.groups()
                version_tuple = tuple(int(part) for part in version.split("."))

                if operator in ("^", ">=", ">") and version_tuple[:2] == (0, 8):
                    has_flexible_08_constraint = True
                elif operator == "<" and not (preferred_tuple < version_tuple):
                    permits_preferred = False
                elif operator == "<=" and not (preferred_tuple <= version_tuple):
                    permits_preferred = False
                elif operator in (None, "=") and version_tuple != preferred_tuple:
                    permits_preferred = False
                elif operator == "^":
                    # ^0.8.x permits versions below 0.9.0; other caret
                    # ranges should not be silently overridden.
                    if version_tuple[:2] != (0, 8) or preferred_tuple < version_tuple:
                        permits_preferred = False
                elif operator == ">=" and preferred_tuple < version_tuple:
                    permits_preferred = False
                elif operator == ">" and preferred_tuple <= version_tuple:
                    permits_preferred = False

        if has_flexible_08_constraint and permits_preferred:
            return PREFERRED_SOLC_08

    return selected


def has_known_fixable_evm_feature_error(stderr: str) -> bool:
    """True if the compile error is caused by EVM-Cancun-only opcodes
    (transient storage `tstore`/`tload`, or `mcopy`) not being enabled
    on the current solc invocation's default EVM target."""
    return any(token in stderr for token in ("tstore", "tload", "mcopy"))


def has_stack_too_deep_error(stderr: str) -> bool:
    return "Stack too deep" in stderr


def run_command(command, cwd=None):
    """Runs a command without stopping the whole script on failure.
    No timeout - the command runs until it finishes on its own."""
    return subprocess.run(command, text=True, capture_output=True, cwd=cwd)


def count_findings(json_path: Path) -> int:
    try:
        with json_path.open("r", encoding="utf-8") as f:
            data = json.load(f)
        return len(data.get("results", {}).get("detectors", []))
    except (OSError, json.JSONDecodeError):
        return 0


def json_is_valid_success(json_path: Path) -> bool:
    if not json_path.exists():
        return False
    try:
        with json_path.open("r", encoding="utf-8") as f:
            data = json.load(f)
        return bool(data.get("success", False))
    except (OSError, json.JSONDecodeError, AttributeError):
        return False


def create_compatibility_copy(contract_path: Path):
    """Patches the old `(bool x, ) = addr.call.value(y)("")` tuple pattern
    into `bool x = addr.call.value(y)("")` on a TEMPORARY copy only.
    The original file is never modified. Returns (tempdir, temp_path,
    replacements) or (None, None, 0) if no pattern was found."""
    content = contract_path.read_text(encoding="utf-8", errors="ignore")

    patched, replacements = re.subn(
        r"\(\s*bool\s+([A-Za-z_]\w*)\s*,\s*\)\s*=",
        r"bool \1 =",
        content
    )

    if replacements == 0:
        return None, None, 0

    tmp_dir = tempfile.TemporaryDirectory()
    tmp_path = Path(tmp_dir.name) / contract_path.name
    tmp_path.write_text(patched, encoding="utf-8")
    return tmp_dir, tmp_path, replacements





def guess_contract_name_from_folder(folder_name: str) -> str:
    match = re.match(r"^(.*?)_0x[0-9a-fA-F]+$", folder_name)
    return match.group(1) if match else folder_name


def pick_main_file(sol_files, contract_name: str):
    if contract_name:
        pattern = re.compile(
            rf"\b(?:abstract\s+)?(?:contract|interface|library)\s+{re.escape(contract_name)}\b"
        )
        for f in sol_files:
            content = f.read_text(encoding="utf-8", errors="ignore")
            if pattern.search(content):
                return f

    local_candidates = [
        f for f in sol_files
        if not any(part.startswith("@") or part == "node_modules" for part in f.parts)
    ]
    pool = local_candidates if local_candidates else sol_files
    return max(pool, key=lambda f: f.stat().st_size)


def discover_targets():
    """Returns a list of dicts: name, category, compile_cwd, main_path, main_arg."""
    targets = []

    if CONTRACTS_MODE == "flat":
        for contract_path in sorted(CONTRACTS_DIR.rglob("*.sol")):
            relative = contract_path.relative_to(CONTRACTS_DIR)
            category = relative.parts[0] if len(relative.parts) > 1 else "uncategorized"
            targets.append({
                "name": contract_path.stem,
                "category": category,
                "compile_cwd": CONTRACTS_DIR,
                "main_path": contract_path,
                "main_arg": str(contract_path),
            })

    elif CONTRACTS_MODE == "nested":
        for folder in sorted(CONTRACTS_DIR.iterdir()):
            if not folder.is_dir():
                continue

            marker = folder / "_main_entry.txt"
            if not marker.exists():
                sol_files = list(folder.rglob("*.sol"))
                if not sol_files:
                    continue
                contract_name = guess_contract_name_from_folder(folder.name)
                main_file = pick_main_file(sol_files, contract_name)
                marker.write_text(str(main_file.relative_to(folder)), encoding="utf-8")

            main_rel = marker.read_text(encoding="utf-8").strip()
            main_path = folder / main_rel
            if not main_path.exists():
                continue

            targets.append({
                "name": folder.name,
                "category": "uncategorized",
                "compile_cwd": folder,
                "main_path": main_path,
                "main_arg": main_rel,
            })

    else:
        raise ValueError(f"Unknown CONTRACTS_MODE: {CONTRACTS_MODE!r} (use 'flat' or 'nested')")

    return targets




def load_existing_progress():
    attempted = set()
    if RESULTS_DIR.exists():
        for json_file in RESULTS_DIR.glob("*.json"):
            attempted.add(json_file.stem)
        for error_file in RESULTS_DIR.glob("*_error.txt"):
            attempted.add(error_file.stem.replace("_error", ""))

    rows = []
    if SUMMARY_FILE.exists():
        try:
            with SUMMARY_FILE.open("r", encoding="utf-8") as f:
                rows = list(csv.DictReader(f))
            for row in rows:
                attempted.add(row["contract"])
        except (OSError, csv.Error):
            rows = []

    return attempted, rows


def write_summary(rows, max_retries=5, retry_delay_seconds=1.0):
    """Writes the summary CSV atomically (tmp file + replace).

    On some filesystems - notably VirtualBox Shared Folders (vboxsf) -
    os.replace()/Path.replace() can intermittently fail with
    'OSError: [Errno 26] Text file busy' even when nothing is actually
    holding the file open in a conflicting way (a known vboxsf quirk,
    often triggered by another process just reading the file, e.g.
    `wc -l`, `tail -f`, an open editor tab, or Windows-side AV
    scanning through the share).

    To keep a long unattended run (1000+ contracts) from crashing on
    this, we retry the replace a few times with a short delay. If it
    still fails after all retries, we fall back to a plain (non-atomic)
    write directly to SUMMARY_FILE so progress is never lost - the
    tiny window of non-atomicity is a much smaller risk than losing an
    entire multi-hour run.
    """
    tmp_file = SUMMARY_FILE.with_suffix(".csv.tmp")
    with tmp_file.open("w", newline="", encoding="utf-8") as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=[
            "category", "contract", "solidity_version", "status",
            "detectors_count", "compatibility_patch_used", "fix_applied",
            "output_file", "error_file"
        ])
        writer.writeheader()
        writer.writerows(rows)

    last_error = None
    for attempt in range(1, max_retries + 1):
        try:
            tmp_file.replace(SUMMARY_FILE)
            return
        except OSError as exc:
            last_error = exc
            print(f"  [write_summary] replace() failed (attempt {attempt}/{max_retries}): {exc}")
            time.sleep(retry_delay_seconds)

  
    print(f"  [write_summary] Falling back to direct write after {max_retries} failed replace() attempts "
          f"(last error: {last_error})")
    try:
        with SUMMARY_FILE.open("w", newline="", encoding="utf-8") as csv_file:
            writer = csv.DictWriter(csv_file, fieldnames=[
                "category", "contract", "solidity_version", "status",
                "detectors_count", "compatibility_patch_used", "fix_applied",
                "output_file", "error_file"
            ])
            writer.writeheader()
            writer.writerows(rows)
    finally:
        if tmp_file.exists():
            try:
                tmp_file.unlink()
            except OSError:
                pass



def clear_retryable_failures():
    """Removes previously-failed rows whose status is in
    RETRY_FAILED_STATUSES from the summary CSV, and deletes their
    error files. This makes the resume logic in analyze() treat them
    as 'not yet attempted', so they get retried automatically on the
    next run - picking up any fixes made to version detection or the
    retry strategies (--via-ir, --evm-version cancun, compatibility
    patch). Rows for successful contracts are never touched, so
    already-succeeded contracts are still skipped and never re-run.
    """
    if not SUMMARY_FILE.exists():
        return 0

    with SUMMARY_FILE.open("r", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))

    keep_rows = []
    cleared = 0
    for row in rows:
        if row.get("status") in RETRY_FAILED_STATUSES:
            cleared += 1
            error_file = row.get("error_file") or ""
            if error_file:
                ef = Path(error_file)
                if ef.exists():
                    try:
                        ef.unlink()
                    except OSError:
                        pass
            
            stray_json = RESULTS_DIR / f"{row.get('contract')}.json"
            if stray_json.exists():
                try:
                    stray_json.unlink()
                except OSError:
                    pass
        else:
            keep_rows.append(row)

    if cleared:
        write_summary(keep_rows)
        print(f"Cleared {cleared} previously-failed contract(s) with status in "
              f"{sorted(RETRY_FAILED_STATUSES)} - they will be retried this run.")

    return cleared


def analyze():
    if not CONTRACTS_DIR.exists():
        print(f"Contracts folder not found: {CONTRACTS_DIR}")
        return

    targets = discover_targets()
    if not targets:
        print("No contracts found to analyze.")
        return

    RESULTS_DIR.mkdir(parents=True, exist_ok=True)

    clear_retryable_failures()

    already_attempted, summary_rows = load_existing_progress()

    print("=" * 70)
    print(f"Total contracts: {len(targets)}")
    print(f"Previously attempted (will be skipped): {len(already_attempted)}")
    print("=" * 70)

    success_count = sum(1 for r in summary_rows if r.get("status") in ("success", "success_with_compatibility_patch"))
    failed_count = sum(1 for r in summary_rows if r.get("status") not in ("success", "success_with_compatibility_patch"))

    for index, target in enumerate(targets, start=1):
        name = target["name"]
        if name in already_attempted:
            continue

        output_file = RESULTS_DIR / f"{name}.json"
        error_file = RESULTS_DIR / f"{name}_error.txt"

        print(f"[{index}/{len(targets)}] {name}")

        content = target["main_path"].read_text(encoding="utf-8", errors="ignore")
        solidity_version = extract_solidity_version(content)

        if not solidity_version:
            error_file.write_text("Could not detect Solidity version from pragma.", encoding="utf-8")
            failed_count += 1
            summary_rows.append({
                "category": target["category"], "contract": name, "solidity_version": "",
                "status": "version_not_found", "detectors_count": 0,
                "compatibility_patch_used": "no",
                "output_file": "", "error_file": str(error_file),
            })
            write_summary(summary_rows)
            print("  Failed: Solidity version not found.")
            continue

        solc_result = run_command(["solc-select", "use", solidity_version, "--always-install"])
        if solc_result.returncode != 0:
            error_file.write_text(
                f"STDOUT:\n{solc_result.stdout}\n\nSTDERR:\n{solc_result.stderr}",
                encoding="utf-8",
            )
            failed_count += 1
            summary_rows.append({
                "category": target["category"], "contract": name, "solidity_version": solidity_version,
                "status": "solc_error", "detectors_count": 0,
                "compatibility_patch_used": "no",
                "output_file": "", "error_file": str(error_file),
            })
            write_summary(summary_rows)
            print("  Failed: could not install/activate solc.")
            continue

        if output_file.exists():
            output_file.unlink()

        slither_result = run_command(
            ["slither", target["main_arg"], "--json", str(output_file)],
            cwd=target["compile_cwd"],
        )

        used_patch = False
        fix_applied = ""
        error_text = f"STDOUT:\n{slither_result.stdout}\n\nSTDERR:\n{slither_result.stderr}"

        
        if (
            ENABLE_COMPATIBILITY_PATCH
            and not json_is_valid_success(output_file)
            and ("Failed to generate IR" in slither_result.stderr or "AssertionError" in slither_result.stderr)
        ):
            if output_file.exists():
                output_file.unlink()

            tmp_dir, tmp_path, replacements = create_compatibility_copy(target["main_path"])
            if tmp_path is not None:
                print("  Retrying with compatibility patch...")
                retry = run_command(["slither", str(tmp_path), "--json", str(output_file)])
                if json_is_valid_success(output_file):
                    used_patch = True
                    fix_applied = "compatibility_patch"
                else:
                    error_text += f"\n\n===== RETRY =====\nSTDOUT:\n{retry.stdout}\n\nSTDERR:\n{retry.stderr}"
                tmp_dir.cleanup()

       
        elif not json_is_valid_success(output_file) and has_stack_too_deep_error(slither_result.stderr):
            if output_file.exists():
                output_file.unlink()
            print("  Retrying with --via-ir (Stack too deep)...")
            retry = run_command(
                ["slither", target["main_arg"], "--json", str(output_file), "--solc-args=--via-ir"],
                cwd=target["compile_cwd"],
            )
            if json_is_valid_success(output_file):
                fix_applied = "via_ir"
            else:
                error_text += f"\n\n===== RETRY (--via-ir) =====\nSTDOUT:\n{retry.stdout}\n\nSTDERR:\n{retry.stderr}"

       
        elif not json_is_valid_success(output_file) and has_known_fixable_evm_feature_error(slither_result.stderr):
            if output_file.exists():
                output_file.unlink()
            print("  Retrying with --evm-version cancun (transient storage/mcopy)...")
            retry = run_command(
                [
                    "slither",
                    target["main_arg"],
                    "--json",
                    str(output_file),
                    "--solc-args=--evm-version cancun",
                ],
                cwd=target["compile_cwd"],
            )
            if json_is_valid_success(output_file):
                fix_applied = "evm_version_cancun"
            else:
                error_text += f"\n\n===== RETRY (--evm-version cancun) =====\nSTDOUT:\n{retry.stdout}\n\nSTDERR:\n{retry.stderr}"

        findings_count = count_findings(output_file)

        if json_is_valid_success(output_file):
            status = "success_with_compatibility_patch" if used_patch else "success"
            success_count += 1
            if error_file.exists():
                error_file.unlink()
            error_path_value = ""
            suffix = f" ({fix_applied})" if fix_applied else ""
            print(f"  Success: {findings_count} findings{suffix}")
        else:
            status = "slither_error"
            failed_count += 1
            if output_file.exists():
                output_file.unlink()
            error_file.write_text(error_text, encoding="utf-8")
            error_path_value = str(error_file)
            print("  Failed: Slither did not produce a JSON file.")

        summary_rows.append({
            "category": target["category"], "contract": name, "solidity_version": solidity_version,
            "status": status, "detectors_count": findings_count,
            "compatibility_patch_used": "yes" if used_patch else "no",
            "fix_applied": fix_applied,
            "output_file": str(output_file) if output_file.exists() else "",
            "error_file": error_path_value,
        })
        write_summary(summary_rows)

    print()
    print("=" * 70)
    print("Analysis finished")
    print(f"Total contracts : {len(targets)}")
    print(f"Succeeded       : {success_count}")
    print(f"Failed          : {failed_count}")
    print(f"Summary file    : {SUMMARY_FILE}")
    print("=" * 70)





def format_code_location(det: dict) -> str:
    """Builds a human-readable 'file:line-line, file:line-line, ...'
    string from Slither's `elements[].source_mapping`. Slither can
    attach a finding to several elements (e.g. a variable AND the
    function that uses it), so we collect all of them and dedupe."""
    locations = []
    for element in det.get("elements", []) or []:
        mapping = element.get("source_mapping") or {}
        filename = (
            mapping.get("filename_relative")
            or mapping.get("filename_short")
            or mapping.get("filename_absolute")
            or ""
        )
        lines = mapping.get("lines") or []
        if not filename:
            continue
        if lines:
            if len(lines) == 1:
                line_str = str(lines[0])
            else:
                line_str = f"{lines[0]}-{lines[-1]}"
            entry = f"{filename}:{line_str}"
        else:
            entry = filename
        if entry not in locations:
            locations.append(entry)
    return "; ".join(locations)


def extract_findings(json_path_str: str):
    if not json_path_str:
        return []
    json_path = Path(json_path_str)
    if not json_path.exists():
        return []
    try:
        with json_path.open("r", encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, json.JSONDecodeError):
        return []

    findings = []
    for det in data.get("results", {}).get("detectors", []):
        findings.append({
            "rule": det.get("check", ""),
            "severity": det.get("impact", ""),
            "confidence": det.get("confidence", ""),
            "code_location": format_code_location(det),
            "description": (det.get("description", "") or "").strip().replace("\n", " "),
        })
    return findings


def build_unified_json_report():
    if not SUMMARY_FILE.exists():
        print(f"Summary file not found: {SUMMARY_FILE}")
        return

    with SUMMARY_FILE.open("r", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))

    output_rows = []
    n = 1

    for row in rows:
        status = row.get("status", "")
        if status not in ("success", "success_with_compatibility_patch"):
            continue

        findings = extract_findings(row.get("output_file", ""))
        for finding in findings:
            output_rows.append({
                "n": n,
                "contract": row.get("contract", ""),
                "tool": TOOL_NAME,
                "rule": finding["rule"],
                "category": categorize(finding["rule"]),
                "swc_id": get_swc_id(finding["rule"]),
                "severity": finding["severity"],
                "confidence": finding["confidence"],
                "status": status,
                "code_location": finding["code_location"],
                "description": finding["description"],
            })
            n += 1

    with UNIFIED_REPORT_FILE.open("w", encoding="utf-8") as f:
        json.dump(output_rows, f, ensure_ascii=False, indent=2)

    print("=" * 60)
    print(f"Unified JSON report created: {UNIFIED_REPORT_FILE}")
    print(f"Total findings: {len(output_rows)}")
    print("=" * 60)


def main():
    analyze()
    build_unified_json_report()


if __name__ == "__main__":
    main()
