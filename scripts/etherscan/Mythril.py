import os
import json
import csv
import subprocess
import time
from pathlib import Path
 
 
OUTPUT_JSON = "results.json"
OUTPUT_CSV = "results.csv"
NUM_CONTRACTS = None
TIMEOUT = None
LOG_FOLDER = "/home/hawra/Mythril-Lab/logs"
DATASET_FOLDER = Path("dataset_1000/contracts")
 
BREAK_EVERY = 300      
BREAK_SECONDS = 60    
 
os.makedirs(LOG_FOLDER, exist_ok=True)
 
 
contracts = []
 
for folder in DATASET_FOLDER.iterdir():
 
    if not folder.is_dir():
        continue
 
    bytecode_file = folder / "bytecode.hex"
 
    if bytecode_file.exists():
 
        contracts.append({
            "name": folder.name,
            "bytecode": bytecode_file
        })
 
if NUM_CONTRACTS is not None:
    contracts = contracts[:NUM_CONTRACTS]
 

if os.path.exists(OUTPUT_JSON):
    with open(OUTPUT_JSON, "r", encoding="utf-8") as f:
        try:
            all_records = json.load(f)
        except json.JSONDecodeError:
            all_records = []
else:
    all_records = []
 
completed = {rec["n"] for rec in all_records if "n" in rec}
 
processed_count = 0 
 
 
def save_all():

    _save_json()
    _save_csv()
 
 
def _save_json():
    tmp_path = OUTPUT_JSON + ".tmp"
 
    with open(tmp_path, "w", encoding="utf-8") as f:
        json.dump(all_records, f, ensure_ascii=False, indent=2)
        f.flush()
        os.fsync(f.fileno())
 
    os.replace(tmp_path, OUTPUT_JSON)
 
 
def _save_csv():

    tmp_path = OUTPUT_CSV + ".tmp"
 
    fieldnames = []
    seen = set()
    for rec in all_records:
        for key in rec.keys():
            if key not in seen:
                seen.add(key)
                fieldnames.append(key)
 
    with open(tmp_path, "w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
 
        for rec in all_records:
            row = {}
            for key, value in rec.items():
                if isinstance(value, (dict, list)):
                    row[key] = json.dumps(value, ensure_ascii=False)
                else:
                    row[key] = value
            writer.writerow(row)
 
        f.flush()
        os.fsync(f.fileno())
 
    os.replace(tmp_path, OUTPUT_CSV)
 
 
def save_record(record):
    all_records.append(record)
    save_all()
 
 
def save_records(records):

    if not records:
        return
    all_records.extend(records)
    save_all()
 
 
def save_log(contract_number, output):
 
    log_path = os.path.join(
        LOG_FOLDER,
        f"{contract_number}.txt"
    )
 
    with open(
        log_path,
        "w",
        encoding="utf-8",
        errors="ignore"
    ) as f:
 
        f.write(output)
 
 
for idx, item in enumerate(contracts, start=1):
 
    dataset_row = idx
 
    if dataset_row in completed:
        print(f"Skipping {dataset_row}")
        continue
 

    if processed_count > 0 and processed_count % BREAK_EVERY == 0:
        print(f"Taking a {BREAK_SECONDS}s break after {processed_count} contracts...")
        time.sleep(BREAK_SECONDS)
 
    processed_count += 1
 
    name = item["name"]
 
    with open(item["bytecode"], "r", encoding="utf-8", errors="ignore") as f:
        bc = f.read().strip()
 
    print(f"Analyzing {name}")
 
    print(f"Analyzing {dataset_row}")
 
    if not bc or bc == "nan":
        rec = {"n": dataset_row, "contract": name, "tool": "Mythril", "status": "Failed", "description": "Empty Bytecode"}
        save_record(rec)
        continue
 
    if not bc.startswith("0x"):
        bc = "0x" + bc
 
    try:
        
        p = subprocess.run(
            ["myth", "analyze", "-c", bc, "-o", "jsonv2"],
            capture_output=True,
            text=True,
            timeout=TIMEOUT
        )
 
        stdout = (p.stdout or "").strip()
        stderr = p.stderr or ""
 
    
        parsed = None
        if stdout:
            try:
                parsed = json.loads(stdout)
            except json.JSONDecodeError:
                parsed = None
 
        if parsed is None:
      
            save_log(dataset_row, stdout + "\n" + stderr)
 
            rec = {
                "n": dataset_row,
                "contract": name,
                "tool": "Mythril",
                "status": "Failed",
                "description": "Mythril Error / Invalid JSON output"
            }
            save_record(rec)
            continue
 
        if isinstance(parsed, list):
            if len(parsed) > 0 and isinstance(parsed[0], dict) and (
                "issues" in parsed[0] or "error" in parsed[0]
            ):

                merged_issues = []
                merged_error = None
                for entry in parsed:
                    if isinstance(entry, dict):
                        merged_issues.extend(entry.get("issues", []) or [])
                        if entry.get("error"):
                            merged_error = entry.get("error")
                parsed = {"issues": merged_issues, "error": merged_error}
            else:
              
                parsed = {"issues": parsed, "error": None}
        elif not isinstance(parsed, dict):

            save_log(dataset_row, stdout + "\n" + stderr)
            rec = {
                "n": dataset_row,
                "contract": name,
                "tool": "Mythril",
                "status": "Failed",
                "description": f"Unexpected jsonv2 output type: {type(parsed).__name__}"
            }
            save_record(rec)
            continue
 
 
        top_error = parsed.get("error")
        if top_error:
            save_log(dataset_row, json.dumps(parsed, ensure_ascii=False, indent=2) + "\n" + stderr)
 
            rec = {
                "n": dataset_row,
                "contract": name,
                "tool": "Mythril",
                "status": "Failed",
                "description": "Mythril Error",
                "error": top_error
            }
            save_record(rec)
            continue
 
        issues = parsed.get("issues", [])
 
        if not issues:
            rec = {
                "n": dataset_row,
                "contract": name,
                "tool": "Mythril",
                "status": "Success",
                "category": "No Issues"
            }
            save_record(rec)
            continue
 

        contract_records = []
        for issue in issues:
            rec = {
                "n": dataset_row,
                "contract": name,
                "tool": "Mythril",
                "status": "Success",
                **issue 
            }
            contract_records.append(rec)
 
        save_records(contract_records)
 
    except subprocess.TimeoutExpired as e:
 
        save_log(dataset_row, str(e))
 
        rec = {
            "n": dataset_row,
            "contract": name,
            "tool": "Mythril",
            "status": "Failed",
            "description": "Timeout"
        }
 
        save_record(rec)
 
    except Exception as e:
 
        save_log(dataset_row, str(e))
 
        rec = {
            "n": dataset_row,
            "contract": name,
            "tool": "Mythril",
            "status": "Failed",
            "description": str(e)
        }
 
        save_record(rec)
 
print("Done.")