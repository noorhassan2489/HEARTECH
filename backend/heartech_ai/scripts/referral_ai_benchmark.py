"""Deterministic benchmark artifact and baseline capture for Referral AI."""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

SCRIPT_PATH = Path(__file__).resolve()
PROJECT_BACKEND_ROOT = SCRIPT_PATH.parents[2]
if str(PROJECT_BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_BACKEND_ROOT))

from heartech_ai.runtime.model_selection import CANDIDATE_MODEL_DIRS, PINNED_WINNER_DIR


ROOT = SCRIPT_PATH.parents[1]
EVAL_REPORTS_DIR = ROOT / "eval_reports"
STRICT_REPORT = EVAL_REPORTS_DIR / "v5_96000_release_gate_strict.txt"
FUZZY_REPORT = EVAL_REPORTS_DIR / "v5_96000_release_gate_human_fuzzy.txt"


def _read_text(path: Path) -> str:
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8")


def parse_release_gate_metrics(text: str) -> dict[str, int]:
    metrics = {
        "passed": 0,
        "total": 0,
        "failed": 0,
    }
    match = re.search(r"Summary:\s*(\d+)/(\d+)\s*passed,\s*(\d+)\s*failed", text)
    if match:
        metrics["passed"] = int(match.group(1))
        metrics["total"] = int(match.group(2))
        metrics["failed"] = int(match.group(3))
    return metrics


def parse_human_fuzzy_metrics(text: str) -> dict[str, int]:
    lines = text.splitlines()
    prompts_observed = sum(
        1 for ln in lines if re.search(r"^\[h\d+\]\s+raw:", ln.strip())
    )
    clarifications = sum(1 for ln in lines if "output_type=clarification" in ln)
    suspicious = sum(
        1
        for ln in lines
        if ln.strip().startswith("output:")
        and any(
            marker in ln.lower()
            for marker in (
                "if these signs persist beyond 2-4 weeks",
                "at around 3 years",
                "my 12 years patient",
            )
        )
    )
    return {
        "prompts_observed": prompts_observed,
        "clarifications": clarifications,
        "suspicious_leak_like_outputs": suspicious,
    }


def candidate_inventory() -> dict[str, dict[str, object]]:
    inventory: dict[str, dict[str, object]] = {}
    for model_dir in CANDIDATE_MODEL_DIRS:
        path = ROOT / model_dir
        inventory[model_dir] = {
            "path": str(path),
            "exists": path.exists() and path.is_dir(),
        }
    return inventory


def benchmark_commands() -> dict[str, str]:
    model_rel = f"./heartech_ai/{PINNED_WINNER_DIR}"
    return {
        PINNED_WINNER_DIR: (
            "python heartech_ai/scripts/test_model.py "
            f"--model {model_rel} "
            "--release-gate "
            "--use-base-router "
            "--router-model meta-llama/Llama-3.2-3B"
        )
    }


def three_turn_acceptance() -> dict[str, object]:
    turns = [
        {
            "turn": 1,
            "input": "the child has ear wax what should i do?",
            "expect": "Mentions wax/cerumen/otoscopy and gives actionable care (not generic repeated boilerplate).",
        },
        {
            "turn": 2,
            "input": "could the child have vertigo or not? suggest",
            "expect": "Yes/no/likely response with vertigo reasoning and different content from turn 1.",
        },
        {
            "turn": 3,
            "input": "give me the referral about all of this",
            "expect": "PATIENT REFERRAL structure with both wax and vertigo reflected and valid footer.",
        },
    ]
    return {
        "name": "ear_wax_to_vertigo_to_referral",
        "turns": turns,
        "stealth_log_check": "rg -i \"gemini|google|aux|backup\" backend/logs backend -g \"*.log\"",
    }


def build_baseline() -> dict[str, object]:
    strict_text = _read_text(STRICT_REPORT)
    fuzzy_text = _read_text(FUZZY_REPORT)
    strict_metrics = parse_release_gate_metrics(strict_text)
    fuzzy_metrics = parse_human_fuzzy_metrics(fuzzy_text)
    inventory = candidate_inventory()

    winner = PINNED_WINNER_DIR
    winner_available = bool(inventory.get(winner, {}).get("exists"))

    return {
        "benchmark_version": "referral-ai-recovery-phase1-v1",
        "captured_at_utc": datetime.now(timezone.utc).isoformat(),
        "artifact_inputs": {
            "strict_report": str(STRICT_REPORT),
            "fuzzy_report": str(FUZZY_REPORT),
        },
        "strict_release_gate": strict_metrics,
        "human_fuzzy_observation": fuzzy_metrics,
        "candidate_inventory": inventory,
        "pinned_winner": {
            "model_dir": winner,
            "available": winner_available,
            "selection_basis": (
                "Existing strict release-gate evidence and deterministic pin order; "
                "other candidates currently lack equivalent release-gate reports."
            ),
        },
        "benchmark_commands": benchmark_commands(),
        "three_turn_acceptance": three_turn_acceptance(),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Capture deterministic Referral AI benchmark baseline.")
    parser.add_argument(
        "--output",
        default=str(EVAL_REPORTS_DIR / "referral_ai_phase1_baseline.json"),
        help="Baseline output JSON path.",
    )
    parser.add_argument(
        "--print",
        action="store_true",
        help="Print baseline JSON to stdout.",
    )
    args = parser.parse_args()

    baseline = build_baseline()
    output_path = Path(args.output).resolve()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(baseline, indent=2) + "\n", encoding="utf-8")

    if args.print:
        print(json.dumps(baseline, indent=2))
    else:
        print(f"Baseline written to: {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
