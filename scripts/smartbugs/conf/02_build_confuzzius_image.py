#!/usr/bin/env python3

import json
import os
import subprocess
import sys

BASE_IMAGE = "confuzzius-custom:latest"   # الصورة الأساسية اللي نبني فوقها
OUTPUT_IMAGE = "confuzzius-full:latest"   # اسم/تاق الصورة النهائية
BUILD_DIR = os.path.expanduser("~/confuzzius_run/build")

SOLC_VERSIONS = [
    "0.4.11", "0.4.15", "0.4.16", "0.4.18", "0.4.19", "0.4.21",
    "0.4.22", "0.4.24", "0.4.25", "0.5.0",
    "0.6.6", "0.6.12",
    "0.8.18", "0.8.19", "0.8.20", "0.8.21", "0.8.23", "0.8.24",
    "0.8.26", "0.8.30", "0.8.33", "0.8.34", "0.8.35", "0.8.36",
]
# ============================================================

EVM_DUMP_PATH = os.path.join(BUILD_DIR, "evm_init_dump.txt")
EVM_PATCHED_PATH = os.path.join(BUILD_DIR, "evm_init_patched.py")
INSTALL_SOLC_PATH = os.path.join(BUILD_DIR, "install_solc.py")
DOCKERFILE_PATH = os.path.join(BUILD_DIR, "Dockerfile")


def run(cmd, **kwargs):
    print(f"$ {' '.join(cmd)}")
    return subprocess.run(cmd, check=True, **kwargs)


def step1_dump_evm_file():
    
    os.makedirs(BUILD_DIR, exist_ok=True)
    result = subprocess.run(
        ["docker", "run", "--rm", BASE_IMAGE, "cat", "fuzzer/evm/__init__.py"],
        capture_output=True, text=True, check=True,
    )
    with open(EVM_DUMP_PATH, "w", encoding="utf-8") as f:
        f.write(result.stdout)
    print(f"Saved -> {EVM_DUMP_PATH} ({len(result.stdout.splitlines())} lines)")


def step2_patch_evm_file():
    
    with open(EVM_DUMP_PATH, encoding="utf-8") as f:
        lines = f.readlines()

    start_idx = next((i for i, l in enumerate(lines) if "def set_vm(self, block_identifier=" in l), None)
    if start_idx is None:
        sys.exit("ERROR: 'def set_vm' not found — check EVM_DUMP_PATH content manually")

    end_idx = next((i for i in range(start_idx, len(lines)) if "block_header = BlockHeader(" in lines[i]), None)
    if end_idx is None:
        sys.exit("ERROR: 'block_header = BlockHeader(' not found — check file manually")

    else_idx = next((i for i in range(end_idx - 1, start_idx, -1) if lines[i].strip() == "else:"), None)
    if else_idx is None:
        sys.exit("ERROR: 'else:' not found inside set_vm — check file manually")

    indent = "        "
    new_else_block = (
        f"{indent}else:\n"
        f"{indent}    # PATCHED: use the latest available block on the connected chain,\n"
        f"{indent}    # instead of insisting on the hardcoded historical mainnet block number\n"
        f"{indent}    # (which does not exist on a fresh local chain like Anvil).\n"
        f"{indent}    block_identifier = self.w3.eth.blockNumber\n"
        f"{indent}    validate_uint256(block_identifier)\n"
        f"{indent}    _block = self.w3.eth.getBlock(block_identifier)\n"
    )
    patched_lines = lines[:else_idx] + [new_else_block] + lines[end_idx:]

    with open(EVM_PATCHED_PATH, "w", encoding="utf-8") as f:
        f.writelines(patched_lines)

    import ast
    ast.parse("".join(patched_lines))  # يوقف فورًا لو الناتج مو صحيح نحويًا
    print(f"Patched -> {EVM_PATCHED_PATH} (syntax OK)")


def step3_write_install_solc():
    
    content = (
        "import solcx\n"
        f"versions = {SOLC_VERSIONS!r}\n"
        "for v in versions:\n"
        "    try:\n"
        "        solcx.install_solc(v)\n"
        "        print('installed', v)\n"
        "    except Exception as e:\n"
        "        print('FAILED', v, e)\n"
    )
    with open(INSTALL_SOLC_PATH, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"Saved -> {INSTALL_SOLC_PATH} ({len(SOLC_VERSIONS)} versions)")


def step4_build_image():
    
    dockerfile = (
        f"FROM {BASE_IMAGE}\n"
        "COPY install_solc.py /tmp/install_solc.py\n"
        "RUN python3 /tmp/install_solc.py\n"
        "COPY evm_init_patched.py /root/fuzzer/evm/__init__.py\n"
    )
    with open(DOCKERFILE_PATH, "w", encoding="utf-8") as f:
        f.write(dockerfile)
    print(f"Dockerfile -> {DOCKERFILE_PATH}")

    run(["docker", "build", "-t", OUTPUT_IMAGE, "."], cwd=BUILD_DIR)
    print(f"\nImage built and tagged as: {OUTPUT_IMAGE}")


def main():
    step1_dump_evm_file()
    step2_patch_evm_file()
    step3_write_install_solc()
    step4_build_image()
    print("\nDone. Next: run 03_scan_and_report.py")


if __name__ == "__main__":
    main()
