#!/usr/bin/env python3
"""Validate heartech_dataset_v2 JSONL files."""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REQUIRED_PROMPT_END = "Write the complete referral letter:\n\n"
COMPLETION_START = re.compile(r"^Date:\s", re.MULTILINE)


def load_prompts(path: Path, limit: int | None = None) -> list[str]:
    prompts = []
    with path.open(encoding="utf-8") as f:
        for i, line in enumerate(f):
            if limit and i >= limit:
                break
            row = json.loads(line)
            prompts.append(row.get("prompt", ""))
    return prompts


def validate_file(path: Path) -> list[str]:
    errors: list[str] = []
    with path.open(encoding="utf-8") as f:
        for n, line in enumerate(f, 1):
            try:
                row = json.loads(line)
            except json.JSONDecodeError as e:
                errors.append(f"{path.name}:{n} invalid JSON: {e}")
                continue
            if "prompt" not in row or "completion" not in row:
                errors.append(f"{path.name}:{n} missing prompt/completion keys")
                continue
            p, c = row["prompt"], row["completion"]
            if not p.endswith(REQUIRED_PROMPT_END):
                errors.append(f"{path.name}:{n} prompt missing footer marker")
            if len(p) < 200:
                errors.append(f"{path.name}:{n} prompt too short ({len(p)})")
            if len(c) < 400:
                errors.append(f"{path.name}:{n} completion too short ({len(c)})")
            if not COMPLETION_START.search(c):
                errors.append(f"{path.name}:{n} completion should start with Date:")
            if "Dear Colleague" not in c:
                errors.append(f"{path.name}:{n} completion missing Dear Colleague")
            if "CLINICAL SUMMARY" not in c:
                errors.append(f"{path.name}:{n} completion missing CLINICAL SUMMARY")
    return errors


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dir", type=Path, required=True)
    args = parser.parse_args()
    data_dir = args.dir
    all_errors: list[str] = []
    counts = {}
    for name in ("train.jsonl", "valid.jsonl", "test.jsonl"):
        p = data_dir / name
        if not p.exists():
            all_errors.append(f"Missing {p}")
            continue
        counts[name] = sum(1 for _ in p.open())
        all_errors.extend(validate_file(p))

    train_p = load_prompts(data_dir / "train.jsonl", limit=5000) if (data_dir / "train.jsonl").exists() else []
    valid_p = load_prompts(data_dir / "valid.jsonl") if (data_dir / "valid.jsonl").exists() else []
    overlap = len(set(train_p) & set(valid_p))
    if overlap > 0:
        all_errors.append(f"Train/valid prompt overlap: {overlap} identical prompts (regenerate with new seed)")

    print("Counts:", counts)
    if all_errors:
        print(f"FAILED with {len(all_errors)} issue(s):")
        for e in all_errors[:30]:
            print(" -", e)
        if len(all_errors) > 30:
            print(f" ... and {len(all_errors) - 30} more")
        sys.exit(1)
    print("OK — dataset v2 passed validation.")


if __name__ == "__main__":
    main()
