#!/usr/bin/env python3
"""Collect a clean, deduplicated Etherscan smart-contract dataset.

Outputs:
  output/contracts/<address>/sources/**/*.sol  (verified Solidity source files)
  output/contracts/<address>/bytecode.hex      (deployed runtime bytecode)
  output/dataset.csv                           (UTF-8 metadata table)
  output/dataset.json                          (same records as JSON)
  output/quality_report.json                   (final validation evidence)
  output/cache/*.json                          (local API cache; safe resume)
  output/state.json                            (resume position and accepted records)

The script deliberately does NOT put source code inside Excel/CSV cells. This avoids
Excel's 32,767-character truncation and the _x000D_ corruption problem. Source is
saved directly as UTF-8 .sol files with normalized LF line endings.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import logging
import os
import re
import sys
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from decimal import Decimal
from pathlib import Path, PurePosixPath
from typing import Any, Iterable

import requests

API_URL = "https://api.etherscan.io/v2/api"
ADDRESS_RE = re.compile(r"^0x[a-fA-F0-9]{40}$")
SOLIDITY_VERSION_RE = re.compile(r"v?(\d+)\.(\d+)\.(\d+)")

CATEGORY_ORDER = ("token", "defi", "nft", "utility")
CATEGORY_LABELS = {
    "token": "Token",
    "defi": "DeFi",
    "nft": "NFT",
    "utility": "Utility",
}


class ApiError(RuntimeError):
    pass


@dataclass
class RateLimiter:
    calls_per_second: float = 2.0
    last_call: float = 0.0

    def wait(self) -> None:
        interval = 1.0 / max(self.calls_per_second, 0.1)
        delay = interval - (time.monotonic() - self.last_call)
        if delay > 0:
            time.sleep(delay)
        self.last_call = time.monotonic()


class EtherscanClient:
    def __init__(self, api_key: str, chain_id: str, cache_dir: Path, calls_per_second: float) -> None:
        self.api_key = api_key
        self.chain_id = chain_id
        self.cache_dir = cache_dir
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        self.rate = RateLimiter(calls_per_second)
        self.session = requests.Session()
        self.session.headers.update({"User-Agent": "academic-smart-contract-dataset/1.0"})

    def _cache_path(self, params: dict[str, Any]) -> Path:
        stable = json.dumps(params, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
        return self.cache_dir / f"{hashlib.sha256(stable.encode()).hexdigest()}.json"

    def request(self, *, use_cache: bool = True, **params: Any) -> dict[str, Any]:
        full = {"chainid": self.chain_id, "apikey": self.api_key, **params}
        safe_for_cache = {k: v for k, v in full.items() if k != "apikey"}
        cache_path = self._cache_path(safe_for_cache)
        if use_cache and cache_path.exists():
            return json.loads(cache_path.read_text(encoding="utf-8"))

        last_error: Exception | None = None
        for attempt in range(1, 6):
            try:
                self.rate.wait()
                response = self.session.get(API_URL, params=full, timeout=45)
                response.raise_for_status()
                payload = response.json()
                if self._is_rate_limit(payload):
                    raise ApiError(str(payload))
                if use_cache:
                    cache_path.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")
                return payload
            except (requests.RequestException, ValueError, ApiError) as exc:
                last_error = exc
                sleep_for = min(2 ** attempt, 30)
                logging.warning("API attempt %d/5 failed: %s; sleeping %ss", attempt, exc, sleep_for)
                time.sleep(sleep_for)
        raise ApiError(f"Etherscan request failed after retries: {last_error}")

    @staticmethod
    def _is_rate_limit(payload: dict[str, Any]) -> bool:
        text = json.dumps(payload).lower()
        return "rate limit" in text or "max rate limit" in text

    def latest_block(self) -> int:
        payload = self.request(module="proxy", action="eth_blockNumber", use_cache=False)
        return int(payload["result"], 16)

    def block(self, number: int, full_transactions: bool = True) -> dict[str, Any]:
        payload = self.request(
            module="proxy",
            action="eth_getBlockByNumber",
            tag=hex(number),
            boolean="true" if full_transactions else "false",
        )
        result = payload.get("result")
        if not isinstance(result, dict):
            raise ApiError(f"No block result for {number}: {payload}")
        return result

    def receipt(self, tx_hash: str) -> dict[str, Any] | None:
        payload = self.request(module="proxy", action="eth_getTransactionReceipt", txhash=tx_hash)
        result = payload.get("result")
        return result if isinstance(result, dict) else None

    def source(self, address: str) -> dict[str, Any] | None:
        payload = self.request(module="contract", action="getsourcecode", address=address)
        result = payload.get("result")
        if payload.get("status") != "1" or not isinstance(result, list) or not result:
            return None
        row = result[0]
        return row if isinstance(row, dict) else None

    def code(self, address: str) -> str:
        payload = self.request(module="proxy", action="eth_getCode", address=address, tag="latest")
        return str(payload.get("result") or "")

    def balance_wei(self, address: str) -> int | None:
        payload = self.request(module="account", action="balance", address=address, tag="latest")
        if payload.get("status") != "1":
            return None
        try:
            return int(payload["result"])
        except (KeyError, TypeError, ValueError):
            return None

    def normal_transaction_count(self, address: str, cap: int = 10_000) -> tuple[int | None, bool]:
        payload = self.request(
            module="account",
            action="txlist",
            address=address,
            startblock=0,
            endblock=99_999_999,
            page=1,
            offset=cap,
            sort="asc",
        )
        result = payload.get("result")
        if payload.get("status") == "0" and isinstance(result, str) and "No transactions" in result:
            return 0, False
        if not isinstance(result, list):
            return None, False
        return len(result), len(result) >= cap


def clean_text(value: str) -> str:
    """Remove NUL/_x000D_ damage and normalize all newlines to LF."""
    value = value.replace("\x00", "")
    value = re.sub(r"_x000D_", "", value, flags=re.IGNORECASE)
    value = value.replace("\r\n", "\n").replace("\r", "\n")
    return value.lstrip("\ufeff")


def safe_relative_path(raw: str, fallback: str) -> Path:
    raw = clean_text(raw).strip().replace("\\", "/")
    path = PurePosixPath(raw)
    safe_parts = [p for p in path.parts if p not in ("", ".", "..", "/")]
    if not safe_parts:
        safe_parts = [fallback]
    candidate = Path(*safe_parts)
    if candidate.suffix.lower() != ".sol":
        candidate = candidate.with_suffix(".sol")
    return candidate


def unwrap_etherscan_json(source: str) -> Any:
    text = clean_text(source).strip()
    # Etherscan often wraps Standard JSON as {{ ... }}.
    candidates = [text]
    if text.startswith("{{") and text.endswith("}}"):
        candidates.insert(0, text[1:-1])
    for candidate in candidates:
        try:
            return json.loads(candidate)
        except json.JSONDecodeError:
            continue
    return None


def extract_source_files(source_code: str, contract_name: str, contract_file_name: str) -> dict[Path, str]:
    cleaned = clean_text(source_code)
    parsed = unwrap_etherscan_json(cleaned)
    files: dict[Path, str] = {}

    if isinstance(parsed, dict) and isinstance(parsed.get("sources"), dict):
        for index, (name, value) in enumerate(parsed["sources"].items(), start=1):
            content = value.get("content", "") if isinstance(value, dict) else value
            if isinstance(content, str) and clean_text(content).strip():
                files[safe_relative_path(str(name), f"Source{index}.sol")] = clean_text(content)
    elif isinstance(parsed, dict):
        # Older Etherscan multi-file form: {"File.sol": {"content": "..."}}
        for index, (name, value) in enumerate(parsed.items(), start=1):
            content = value.get("content", "") if isinstance(value, dict) else value
            if isinstance(content, str) and (".sol" in str(name).lower() or "pragma solidity" in content):
                files[safe_relative_path(str(name), f"Source{index}.sol")] = clean_text(content)

    if not files and cleaned.strip():
        fallback = contract_file_name or f"{contract_name or 'Contract'}.sol"
        files[safe_relative_path(fallback, "Contract.sol")] = cleaned
    return files


def canonical_source_hash(files: dict[Path, str]) -> str:
    digest = hashlib.sha256()
    for path in sorted(files, key=lambda p: p.as_posix().lower()):
        digest.update(path.as_posix().encode("utf-8"))
        digest.update(b"\0")
        normalized = "\n".join(line.rstrip() for line in clean_text(files[path]).splitlines()).strip()
        digest.update(normalized.encode("utf-8"))
        digest.update(b"\0")
    return digest.hexdigest()


def canonical_bytecode_hash(bytecode: str) -> str:
    normalized = bytecode.lower().strip()
    if normalized.startswith("0x"):
        normalized = normalized[2:]
    # Solidity metadata differs for otherwise identical deployments. Remove the
    # common CBOR suffix when its two-byte length marker is valid.
    try:
        raw = bytes.fromhex(normalized)
        if len(raw) > 2:
            metadata_len = int.from_bytes(raw[-2:], "big")
            if 0 < metadata_len + 2 < len(raw):
                raw = raw[: -(metadata_len + 2)]
        normalized = raw.hex()
    except ValueError:
        pass
    return hashlib.sha256(normalized.encode("ascii", errors="ignore")).hexdigest()


def parse_abi(raw: str) -> list[dict[str, Any]]:
    try:
        value = json.loads(raw)
        return value if isinstance(value, list) else []
    except (TypeError, json.JSONDecodeError):
        return []


def classify_contract(source_text: str, abi: list[dict[str, Any]], contract_name: str) -> str:
    text = (source_text + "\n" + contract_name).lower()
    fn_names = {str(item.get("name", "")).lower() for item in abi if isinstance(item, dict)}

    nft_signals = ("erc721", "erc1155", "nft", "tokenuri", "safetransferfrom", "onerc721received")
    defi_signals = (
        "uniswap", "swap", "liquidity", "lending", "borrow", "repay", "vault", "staking",
        "stake", "unstake", "flashloan", "oracle", "pool", "router", "amm", "yield",
    )
    token_signals = ("erc20", "totalSupply", "balanceOf", "transferFrom", "allowance", "approve")

    if any(signal in text or signal.lower() in fn_names for signal in nft_signals):
        return "nft"
    if any(signal in text or signal in fn_names for signal in defi_signals):
        return "defi"
    if any(signal.lower() in text or signal.lower() in fn_names for signal in token_signals):
        return "token"
    return "utility"


def version_tuple(compiler_version: str) -> tuple[int, int, int] | None:
    match = SOLIDITY_VERSION_RE.search(compiler_version or "")
    return tuple(map(int, match.groups())) if match else None


def within_version_range(compiler_version: str, minimum: str | None, maximum: str | None) -> bool:
    value = version_tuple(compiler_version)
    if value is None:
        return False
    if minimum and value < tuple(map(int, minimum.split("."))):
        return False
    if maximum and value > tuple(map(int, maximum.split("."))):
        return False
    return True


def quotas_for(total: int) -> dict[str, int]:
    base, remainder = divmod(total, len(CATEGORY_ORDER))
    return {category: base + (1 if i < remainder else 0) for i, category in enumerate(CATEGORY_ORDER)}


def atomic_json_write(path: Path, value: Any) -> None:
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding="utf-8")
    temp.replace(path)


def load_state(path: Path) -> dict[str, Any]:
    if path.exists():
        return json.loads(path.read_text(encoding="utf-8"))
    return {"next_block": None, "records": [], "seen_source_hashes": [], "seen_bytecode_hashes": []}


def write_contract_files(root: Path, address: str, files: dict[Path, str], bytecode: str) -> list[str]:
    contract_dir = root / "contracts" / address.lower()
    source_root = contract_dir / "sources"
    written: list[str] = []
    for relative, content in files.items():
        destination = source_root / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(clean_text(content), encoding="utf-8", newline="\n")
        written.append(destination.relative_to(root).as_posix())
    (contract_dir / "bytecode.hex").write_text(bytecode.strip() + "\n", encoding="ascii")
    return written


def write_dataset(output: Path, records: list[dict[str, Any]]) -> None:
    fields = [
        "address", "contract_name", "category", "compiler_version", "compiler_type",
        "license", "balance_wei", "balance_eth", "transaction_count",
        "transaction_count_capped", "creation_date_utc", "creation_tx_hash",
        "creator_address", "creation_block", "source_hash", "bytecode_hash",
        "source_file_count", "source_files", "bytecode_file", "abi_file",
        "optimization_used", "optimization_runs", "proxy", "implementation",
        "collected_at_utc",
    ]
    with (output / "dataset.csv").open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        for row in records:
            csv_row = dict(row)
            csv_row["source_files"] = " | ".join(row.get("source_files", []))
            writer.writerow(csv_row)
    atomic_json_write(output / "dataset.json", records)


def validate_dataset(output: Path, records: list[dict[str, Any]], target: int) -> dict[str, Any]:
    missing_source: list[str] = []
    missing_bytecode: list[str] = []
    bad_source: list[str] = []
    bad_bytecode: list[str] = []
    for row in records:
        address = row["address"]
        source_paths = [output / path for path in row.get("source_files", [])]
        bytecode_path = output / row["bytecode_file"]
        if not source_paths or any(not p.exists() or p.stat().st_size == 0 for p in source_paths):
            missing_source.append(address)
        else:
            combined = "\n".join(p.read_text(encoding="utf-8") for p in source_paths)
            if "\x00" in combined or "_x000D_" in combined:
                bad_source.append(address)
        if not bytecode_path.exists() or bytecode_path.stat().st_size <= 3:
            missing_bytecode.append(address)
        else:
            code = bytecode_path.read_text(encoding="ascii").strip()
            if code in ("", "0x", "0x0") or not re.fullmatch(r"0x[0-9a-fA-F]+", code):
                bad_bytecode.append(address)

    addresses = [row["address"].lower() for row in records]
    source_hashes = [row["source_hash"] for row in records]
    bytecode_hashes = [row["bytecode_hash"] for row in records]
    categories = {category: sum(row["category"] == category for row in records) for category in CATEGORY_ORDER}
    report = {
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "target": target,
        "record_count": len(records),
        "unique_addresses": len(set(addresses)),
        "unique_source_hashes": len(set(source_hashes)),
        "unique_bytecode_hashes": len(set(bytecode_hashes)),
        "category_counts": categories,
        "missing_source_files": missing_source,
        "missing_bytecode_files": missing_bytecode,
        "source_corruption_detected": bad_source,
        "invalid_bytecode_detected": bad_bytecode,
    }
    report["passed"] = (
        len(records) >= target
        and len(addresses) == len(set(addresses))
        and len(source_hashes) == len(set(source_hashes))
        and len(bytecode_hashes) == len(set(bytecode_hashes))
        and not missing_source and not missing_bytecode and not bad_source and not bad_bytecode
    )
    atomic_json_write(output / "quality_report.json", report)
    return report


def candidate_creations(client: EtherscanClient, block_number: int) -> Iterable[tuple[str, str, str, int]]:
    block = client.block(block_number, full_transactions=True)
    timestamp = int(block.get("timestamp", "0x0"), 16)
    transactions = block.get("transactions", [])
    for tx in transactions if isinstance(transactions, list) else []:
        if not isinstance(tx, dict) or tx.get("to") is not None:
            continue
        tx_hash = str(tx.get("hash") or "")
        if not tx_hash:
            continue
        receipt = client.receipt(tx_hash)
        address = str((receipt or {}).get("contractAddress") or "")
        if ADDRESS_RE.match(address):
            yield address, tx_hash, str(tx.get("from") or ""), timestamp


def collect(args: argparse.Namespace) -> int:
    api_key = args.api_key or os.getenv("ETHERSCAN_API_KEY", "")
    if not api_key:
        print("ERROR: set ETHERSCAN_API_KEY or pass --api-key", file=sys.stderr)
        return 2

    output = Path(args.output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    (output / "contracts").mkdir(exist_ok=True)
    state_path = output / "state.json"
    state = load_state(state_path) if args.resume else load_state(Path("/__new_state__"))
    records: list[dict[str, Any]] = list(state.get("records", []))
    seen_addresses = {r["address"].lower() for r in records}
    seen_source = set(state.get("seen_source_hashes", [])) | {r["source_hash"] for r in records}
    seen_bytecode = set(state.get("seen_bytecode_hashes", [])) | {r["bytecode_hash"] for r in records}
    quotas = quotas_for(args.count)
    category_counts = {category: sum(r["category"] == category for r in records) for category in CATEGORY_ORDER}

    client = EtherscanClient(api_key, args.chain_id, output / "cache", args.calls_per_second)
    current_block = state.get("next_block") or args.start_block or client.latest_block()
    scanned = 0
    logging.info("Starting at block %s; already accepted %s/%s; quotas=%s", current_block, len(records), args.count, quotas)

    while len(records) < args.count and scanned < args.max_blocks:
        logging.info("Scanning block %d | accepted %d/%d | categories=%s", current_block, len(records), args.count, category_counts)
        try:
            creations = list(candidate_creations(client, current_block))
        except ApiError as exc:
            logging.warning("Skipping block %d after API error: %s", current_block, exc)
            creations = []

        for address, creation_tx, creator, timestamp in creations:
            if len(records) >= args.count:
                break
            address = address.lower()
            if address in seen_addresses:
                continue
            try:
                metadata = client.source(address)
                if not metadata:
                    continue
                source_code = str(metadata.get("SourceCode") or "")
                if not source_code.strip():
                    continue
                compiler_type = str(metadata.get("CompilerType") or "solc")
                compiler_version = str(metadata.get("CompilerVersion") or "")
                if compiler_type.lower() not in ("", "solc") or not version_tuple(compiler_version):
                    continue
                if not within_version_range(compiler_version, args.min_solc, args.max_solc):
                    continue

                bytecode = client.code(address).strip()
                if bytecode in ("", "0x", "0x0") or not re.fullmatch(r"0x[0-9a-fA-F]+", bytecode):
                    continue

                files = extract_source_files(
                    source_code,
                    str(metadata.get("ContractName") or "Contract"),
                    str(metadata.get("ContractFileName") or ""),
                )
                if not files:
                    continue
                source_hash = canonical_source_hash(files)
                bytecode_hash = canonical_bytecode_hash(bytecode)
                if source_hash in seen_source or bytecode_hash in seen_bytecode:
                    continue

                abi_raw = str(metadata.get("ABI") or "[]")
                abi = parse_abi(abi_raw)
                all_source = "\n".join(files.values())
                category = classify_contract(all_source, abi, str(metadata.get("ContractName") or ""))
                if args.strict_stratification and category_counts[category] >= quotas[category]:
                    continue

                source_paths = write_contract_files(output, address, files, bytecode)
                contract_dir = output / "contracts" / address
                abi_path = contract_dir / "abi.json"
                abi_path.write_text(json.dumps(abi, ensure_ascii=False, indent=2), encoding="utf-8")

                balance_wei = client.balance_wei(address)
                tx_count, tx_capped = client.normal_transaction_count(address, args.tx_count_cap)
                creation_date = datetime.fromtimestamp(timestamp, tz=timezone.utc).isoformat()
                collected_at = datetime.now(timezone.utc).isoformat()
                record = {
                    "address": address,
                    "contract_name": str(metadata.get("ContractName") or ""),
                    "category": category,
                    "category_label": CATEGORY_LABELS[category],
                    "compiler_version": compiler_version,
                    "compiler_type": compiler_type or "solc",
                    "license": str(metadata.get("LicenseType") or "Unknown"),
                    "balance_wei": balance_wei,
                    "balance_eth": str(Decimal(balance_wei) / Decimal(10**18)) if balance_wei is not None else None,
                    "transaction_count": tx_count,
                    "transaction_count_capped": tx_capped,
                    "creation_date_utc": creation_date,
                    "creation_tx_hash": creation_tx,
                    "creator_address": creator.lower(),
                    "creation_block": current_block,
                    "source_hash": source_hash,
                    "bytecode_hash": bytecode_hash,
                    "source_file_count": len(source_paths),
                    "source_files": source_paths,
                    "bytecode_file": (contract_dir / "bytecode.hex").relative_to(output).as_posix(),
                    "abi_file": abi_path.relative_to(output).as_posix(),
                    "optimization_used": str(metadata.get("OptimizationUsed") or ""),
                    "optimization_runs": str(metadata.get("Runs") or ""),
                    "proxy": str(metadata.get("Proxy") or "0"),
                    "implementation": str(metadata.get("Implementation") or ""),
                    "collected_at_utc": collected_at,
                }
                records.append(record)
                seen_addresses.add(address)
                seen_source.add(source_hash)
                seen_bytecode.add(bytecode_hash)
                category_counts[category] += 1
                logging.info("ACCEPTED %d/%d %s %s solc=%s", len(records), args.count, address, category, compiler_version)
                write_dataset(output, records)
                state = {
                    "next_block": current_block,
                    "records": records,
                    "seen_source_hashes": sorted(seen_source),
                    "seen_bytecode_hashes": sorted(seen_bytecode),
                }
                atomic_json_write(state_path, state)
            except (ApiError, OSError, ValueError, KeyError) as exc:
                logging.warning("Candidate %s rejected after error: %s", address, exc)

        current_block -= 1
        scanned += 1
        state = {
            "next_block": current_block,
            "records": records,
            "seen_source_hashes": sorted(seen_source),
            "seen_bytecode_hashes": sorted(seen_bytecode),
        }
        atomic_json_write(state_path, state)

    write_dataset(output, records)
    report = validate_dataset(output, records, args.count)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    if len(records) < args.count:
        logging.error("Stopped after %d blocks with only %d/%d accepted. Re-run with --resume and a larger --max-blocks.", scanned, len(records), args.count)
        return 1
    if not report["passed"]:
        logging.error("Collection finished but quality validation failed. See quality_report.json")
        return 1
    logging.info("SUCCESS: %d clean contracts written to %s", len(records), output)
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--api-key", help="Etherscan API key; safer alternative: ETHERSCAN_API_KEY environment variable")
    parser.add_argument("--chain-id", default="1", help="EVM chain ID (default: 1, Ethereum mainnet)")
    parser.add_argument("--count", type=int, default=30, help="Number of accepted contracts (default: 30)")
    parser.add_argument("--output", default="etherscan_dataset_30", help="Output directory")
    parser.add_argument("--start-block", type=int, help="Block to start scanning backward from; default: latest")
    parser.add_argument("--max-blocks", type=int, default=50_000, help="Maximum blocks scanned in this run")
    parser.add_argument("--calls-per-second", type=float, default=2.0, help="Conservative API pacing (default: 2)")
    parser.add_argument("--tx-count-cap", type=int, default=10_000, help="Maximum txlist rows counted per contract")
    parser.add_argument("--resume", action="store_true", help="Resume from output/state.json and reuse cache")
    parser.add_argument("--strict-stratification", action="store_true", help="Require near-equal Token/DeFi/NFT/Utility quotas")
    parser.add_argument("--min-solc", help="Optional minimum Solidity version, e.g. 0.5.0")
    parser.add_argument("--max-solc", help="Optional maximum Solidity version, e.g. 0.7.6")
    parser.add_argument("--verbose", action="store_true")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    if args.count <= 0 or args.max_blocks <= 0:
        print("ERROR: --count and --max-blocks must be positive", file=sys.stderr)
        return 2
    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(asctime)s | %(levelname)s | %(message)s",
    )
    return collect(args)


if __name__ == "__main__":
    raise SystemExit(main())