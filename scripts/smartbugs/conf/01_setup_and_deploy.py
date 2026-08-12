#!/usr/bin/env python3

import csv
import json
import os
import re
import shutil
import subprocess
import sys

import solcx
from web3 import Web3

# ============================================================
RAW_BASE = os.path.expanduser("~/dataset_40_raw")        # الداتاسيت الخام (input)
OUT_BASE = os.path.expanduser("~/dataset_40_labeled")     # الهيكلة الجاهزة + النشر (output)
PREP_DIR = os.path.dirname(os.path.abspath(__file__))     # مجلد هذا السكربت (فيه compile_old.js)
RPC_URL = "http://127.0.0.1:8545"                          # عنوان Anvil المحلي
# ============================================================

DATASET_CSV = os.path.join(OUT_BASE, "dataset.csv")
LOCAL_TARGETS_PATH = os.path.join(OUT_BASE, "local_targets.json")
DEPLOY_REPORT_PATH = os.path.join(OUT_BASE, "deploy_report.csv")

SOLC_BIN_LIST_URL = "https://raw.githubusercontent.com/ethereum/solc-bin/gh-pages/bin/list.json"
OLD_SOLC_CACHE = os.path.join(PREP_DIR, "old_solc_cache")
COMPILE_OLD_JS = os.path.join(PREP_DIR, "compile_old.js")

PRAGMA_RE = re.compile(r"pragma\s+solidity\s+[^\d]*([0-9]+\.[0-9]+\.[0-9]+)")
CONTRACT_RE = re.compile(r"^\s*contract\s+([A-Za-z_][A-Za-z0-9_]*)", re.MULTILINE)


# ============================================================
# الخطوة 1: بناء هيكلة الداتاسيت + dataset.csv
# ============================================================

def detect_version(src: str) -> str:
    m = PRAGMA_RE.search(src)
    if not m:
        raise ValueError("no 'pragma solidity' line found in file")
    return m.group(1)


def detect_contract_name(src: str) -> str:
    matches = CONTRACT_RE.findall(src)
    if not matches:
        raise ValueError("no 'contract X' declaration found in file")
        return matches[-1]


def step1_prepare_dataset():
    
    csv_path = os.path.join(RAW_BASE, "selected_contracts.csv")
    if not os.path.exists(csv_path):
        sys.exit(f"ERROR: {csv_path} not found — check RAW_BASE")

    contracts_out = os.path.join(OUT_BASE, "contracts")
    os.makedirs(contracts_out, exist_ok=True)

    rows_out, skipped = [], []

    with open(csv_path, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            rel_unix = row["contract"].replace("\\", "/")
            category = row["category"]
            filename = rel_unix.split("/")[-1]
            src_path = os.path.join(RAW_BASE, "selected_contracts", category, filename)
            if not os.path.exists(src_path):
                skipped.append((filename, f"source file not found: {src_path}"))
                continue

            contract_id = os.path.splitext(filename)[0]
            with open(src_path, encoding="utf-8", errors="ignore") as sf:
                src = sf.read()

            try:
                version = detect_version(src)
                cname = detect_contract_name(src)
            except ValueError as e:
                skipped.append((filename, str(e)))
                continue

            dest_dir = os.path.join(contracts_out, contract_id, "sources")
            os.makedirs(dest_dir, exist_ok=True)
            shutil.copyfile(src_path, os.path.join(dest_dir, filename))

            rows_out.append({
                "address": contract_id, "contract_name": cname,
                "compiler_version": version,
                "source_files": f"contracts/{contract_id}/sources/{filename}",
                "category": category,
            })

    with open(DATASET_CSV, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["address", "contract_name", "compiler_version", "source_files", "category"])
        writer.writeheader()
        writer.writerows(rows_out)

    print(f"Built {len(rows_out)} contracts -> {DATASET_CSV}")
    if skipped:
        print(f"WARNING: skipped {len(skipped)} contract(s):")
        for name, reason in skipped:
            print(f"  - {name}: {reason}")
    return rows_out


# ============================================================
# الخطوة 2: تثبيت نسخ solc المطلوبة على الهوست
# ============================================================

def step2_install_solc(rows):
    
    versions = sorted({r["compiler_version"] for r in rows})
    installed = {str(v) for v in solcx.get_installed_solc_versions()}
    for v in versions:
        if v in installed:
            print(f"  {v}: already installed, skip")
            continue
        try:
            major_minor_patch = tuple(int(x) for x in v.split("."))
        except ValueError:
            major_minor_patch = (0, 0, 0)
        if major_minor_patch < (0, 4, 11):
            # هذي النسخ ما يقدر solcx يثبتها أصلاً (ما فيها native binary لينكس
            # مستقل) — بترجم لاحقًا عبر compile_old.js بدل solcx، فما نحتاجها مثبتة هنا.
            print(f"  {v}: too old for solcx, will use compile_old.js (Node.js) instead")
            continue
        try:
            solcx.install_solc(v)
            print(f"  {v}: installed")
        except Exception as e:
            print(f"  {v}: FAILED ({e})")


# ============================================================
# الخطوة 3: النشر على Anvil (compile + deploy)
# ============================================================

def default_value_for_type(t: str):
    if t.startswith("uint") or t.startswith("int"):
        return 0
    if t == "bool":
        return False
    if t == "address":
        return "0x0000000000000000000000000000000000000000"
    if t.startswith("bytes") and t != "bytes":
        n = int(t[5:]) if t[5:].isdigit() else 32
        return b"\x00" * n
    if t == "bytes":
        return b""
    if t == "string":
        return ""
    if t.endswith("[]"):
        return []
    return 0


def compile_modern(src_path, version, contract_name):
    """solcx لأي نسخة >= 0.4.11 (فيها native binary لينكس)."""
    with open(src_path, encoding="utf-8", errors="ignore") as f:
        source = f.read()
    if version not in {str(v) for v in solcx.get_installed_solc_versions()}:
        solcx.install_solc(version)
    compiled = solcx.compile_source(source, solc_version=version, output_values=["abi", "bin"])
    key = next((k for k in compiled if k.endswith(":" + contract_name)), None)
    if key is None:
        raise ValueError(f"contract {contract_name} not found in solcx output: {list(compiled.keys())}")
    return compiled[key]["abi"], "0x" + compiled[key]["bin"]


def get_old_solc_build_filename(version):
    list_path = os.path.join(OLD_SOLC_CACHE, "list.json")
    os.makedirs(OLD_SOLC_CACHE, exist_ok=True)
    if not os.path.exists(list_path):
        subprocess.run(["curl", "-s", "-o", list_path, SOLC_BIN_LIST_URL], check=True)
    with open(list_path, encoding="utf-8") as f:
        data = json.load(f)
    filename = data["releases"].get(version)
    if not filename:
        raise ValueError(f"no solc build found for version {version} in solc-bin")
    return filename


def compile_old(src_path, version, contract_name):
    """يستخدم compile_old.js (Node.js) لنسخ solc < 0.4.11 اللي ما فيها native
    binary — يحمّل بناء solc-js القديم من مرآة GitHub ويترجم فيه."""
    filename = get_old_solc_build_filename(version)
    local_path = os.path.join(OLD_SOLC_CACHE, filename)
    if not os.path.exists(local_path):
        url = f"https://raw.githubusercontent.com/ethereum/solc-bin/gh-pages/bin/{filename}"
        subprocess.run(["curl", "-s", "-o", local_path, url], check=True)

    if not os.path.exists(COMPILE_OLD_JS):
        raise FileNotFoundError(
            f"{COMPILE_OLD_JS} not found — make sure compile_old.js is next to this script "
            f"and you ran 'npm install solc' in this directory"
        )
    result = subprocess.run(
        ["node", COMPILE_OLD_JS, local_path, src_path, contract_name],
        capture_output=True, text=True, cwd=PREP_DIR,
    )
    if result.returncode != 0:
        raise RuntimeError(f"compile_old.js failed: {result.stderr.strip()[:400]}")
    data = json.loads(result.stdout)
    return data["abi"], "0x" + data["bin"]


def compile_contract(src_path, version, contract_name):
    try:
        mmp = tuple(int(x) for x in version.split("."))
    except ValueError:
        mmp = (99, 99, 99)
    if mmp < (0, 4, 11):
        return compile_old(src_path, version, contract_name)
    return compile_modern(src_path, version, contract_name)


def deploy(w3, deployer, abi, bytecode):
    """ينشر العقد، ويرسل 1 ETH تلقائيًا لو الـ constructor نوعه payable (نمط
    شائع بعقود CTF/تحدي تعليمية تشترط قيمة إرسال محددة)."""
    contract = w3.eth.contract(abi=abi, bytecode=bytecode)
    ctor = next((item for item in abi if item.get("type") == "constructor"), None)
    args, value = [], 0
    if ctor:
        for inp in ctor.get("inputs", []):
            args.append(default_value_for_type(inp["type"]))
        if ctor.get("stateMutability") == "payable" or ctor.get("payable") is True:
            value = w3.to_wei(1, "ether")
    tx_hash = contract.constructor(*args).transact({"from": deployer, "value": value})
    receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=60)
    if receipt.status != 1:
        raise RuntimeError(f"deployment transaction failed (status=0), value sent={value}")
    return receipt.contractAddress


def step3_deploy_all(rows):
    
    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    if not w3.is_connected():
        sys.exit(
            f"ERROR: cannot connect to {RPC_URL}. Start anvil first:\n"
            f"  nohup anvil --port 8545 --silent > anvil.log 2>&1 &"
        )
    deployer = w3.eth.accounts[0]
    print(f"Connected to Anvil. Deployer: {deployer} | balance: {w3.from_wei(w3.eth.get_balance(deployer), 'ether')} ETH\n")

    local_targets = {}
    if os.path.exists(LOCAL_TARGETS_PATH):
        with open(LOCAL_TARGETS_PATH, encoding="utf-8") as f:
            local_targets = json.load(f)

    report_rows = []
    ok_count = 0

    for i, row in enumerate(rows, 1):
        cid = row["address"]
        addr_path = os.path.join(OUT_BASE, "contracts", cid, "local_address.txt")

        if cid in local_targets and os.path.exists(addr_path):
            print(f"[{i}/{len(rows)}] {cid} -> already deployed, skip")
            report_rows.append({"id": cid, "status": "OK", "address": local_targets[cid]["address"], "error": ""})
            ok_count += 1
            continue

        cname, version = row["contract_name"], row["compiler_version"]
        src_path = os.path.join(OUT_BASE, row["source_files"])
        print(f"[{i}/{len(rows)}] {cid} ({cname}, solc {version}) ...", end=" ", flush=True)
        try:
            abi, bytecode = compile_contract(src_path, version, cname)
            if not bytecode or bytecode == "0x":
                raise ValueError("empty bytecode (contract may be abstract/interface)")

            address = deploy(w3, deployer, abi, bytecode)

            abi_path = os.path.join(OUT_BASE, "contracts", cid, "abi.json")
            os.makedirs(os.path.dirname(abi_path), exist_ok=True)
            with open(abi_path, "w", encoding="utf-8") as af:
                json.dump(abi, af, indent=2)
            with open(addr_path, "w") as lf:
                lf.write(address)

            local_targets[cid] = {"address": address, "abi_path": f"contracts/{cid}/abi.json"}
            report_rows.append({"id": cid, "status": "OK", "address": address, "error": ""})
            ok_count += 1
            print(f"OK -> {address}")
        except Exception as e:
            report_rows.append({"id": cid, "status": "FAILED", "address": "", "error": str(e)})
            print(f"FAILED: {e}")

    with open(LOCAL_TARGETS_PATH, "w", encoding="utf-8") as f:
        json.dump(local_targets, f, ensure_ascii=False, indent=2)
    with open(DEPLOY_REPORT_PATH, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["id", "status", "address", "error"])
        writer.writeheader()
        writer.writerows(report_rows)

    print(f"\nDeployment summary: {ok_count}/{len(rows)} succeeded")
    failed = [r for r in report_rows if r["status"] == "FAILED"]
    if failed:
        print(f"Still failing ({len(failed)}):")
        for r in failed:
            print(f"  - {r['id']}: {r['error']}")


def main():
    rows = step1_prepare_dataset()
    step2_install_solc(rows)
    step3_deploy_all(rows)
    print("\nDone. Next: run 02_build_confuzzius_image.py, then 03_scan_and_report.py")


if __name__ == "__main__":
    main()
