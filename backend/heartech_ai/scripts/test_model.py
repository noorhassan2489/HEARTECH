#!/usr/bin/env python3
"""
Test HearTech medical model behavior.

Checks:
- 5 clinical question prompts -> direct answer intent
- 3 referral prompts with refer-to -> full document structure + content fidelity
- 3 referral prompts without refer-to -> care advice format without REFER TO
- 2 ambiguous prompts -> keyword-based intent behavior
"""
from __future__ import annotations

import argparse
import gc
import re
import sys
import time
from dataclasses import dataclass

# Must match build_heartech_dataset.py / heartech_dataset_v3 training format
SYSTEM_PROMPT = (
    "You are HearTech Medical Assistant, an expert AI assistant for "
    "Healthcare Workers screening children aged 0-12 for hearing risk. "
    "You answer clinical questions directly and generate patient referral "
    "documents when requested. You have deep knowledge of paediatric "
    "audiology, ENT conditions, hearing development milestones, medicines, "
    "and precautions for hearing health in children."
)

REFERRAL_KEYWORDS = [
    "generate referral",
    "create referral",
    "make referral",
    "write referral",
    "referral for",
    "give referral",
    "produce referral",
    "referral needed",
    "create a referral",
    "i need a referral",
]

REFERRAL_TYPO_RE = re.compile(
    r"\b(referr?al|referal|refferal|refaral|refer|refer to|send to|ent|audiolog(?:ist|y)|paeds?)\b",
    re.IGNORECASE,
)

DISCLAIMER = "Always confirm with a qualified clinician before administration."

REFERRAL_SECTIONS = (
    "CLINICAL SUMMARY:",
    "REFER TO:",
    "Urgency:",
    "RECOMMENDED CARE:",
    "PRECAUTIONS FOR PARENT:",
    "FOLLOW UP:",
    "Screened via HearTech",
)

ADVICE_SECTIONS = (
    "CLINICAL SUMMARY:",
    "RECOMMENDED CARE:",
    "PRECAUTIONS FOR PARENT:",
    "FOLLOW UP:",
    "Screened via HearTech",
)

DOSAGE_PATTERN = re.compile(
    r"\d+\s*(?:mg|ml|drops|%|mg/kg|mcg)|\d+\s*-\s*\d+\s*mg|"
    r"(?:once|twice|three times|every)\s+(?:daily|day|hours?|week)",
    re.IGNORECASE,
)


@dataclass
class TestCase:
    prompt_id: str
    user_prompt: str
    expected_intent: str  # answer or referral
    expect_refer_to: bool | None
    expected_title: str | None
    max_tokens: int = 350
    patient_name: str | None = None
    age_hint: str | None = None
    hospital: str | None = None
    specialist_keywords: tuple[str, ...] = ()
    condition_keywords: tuple[str, ...] = ()
    risk_score: int | None = None
    expect_medicines: bool = False
    medicine_keywords: tuple[str, ...] = ()
    footer_line: str | None = None


@dataclass
class RouterDecision:
    intent: str
    normalized_prompt: str
    needs_clarification: bool
    clarification_question: str


def detect_intent_from_keywords(prompt: str) -> str:
    p = prompt.lower()
    if any(k in p for k in REFERRAL_KEYWORDS) or REFERRAL_TYPO_RE.search(p):
        return "referral"
    return "answer"


def build_inference_prompt(user_prompt: str, system_prompt: str = SYSTEM_PROMPT) -> str:
    """Same token layout as heartech_dataset_v3 training samples."""
    return (
        f"<|system|>{system_prompt}<|end|>\n"
        f"<|user|>{user_prompt}<|end|>\n"
        f"<|assistant|>"
    )


def load_plain_model(model_name_or_path: str):
    from mlx_lm import load

    print(f"Loading model from {model_name_or_path}...", flush=True)
    t0 = time.time()
    model, tokenizer = load(model_name_or_path)
    print(f"Model loaded in {time.time() - t0:.1f}s", flush=True)
    return model, tokenizer


def load_model(args):
    from mlx_lm import load

    print(f"Loading model from {args.model or args.base_model}...", flush=True)
    t0 = time.time()
    if args.adapter_path:
        if not args.base_model:
            raise ValueError("--base-model is required when --adapter-path is provided")
        model, tokenizer = load(args.base_model, adapter_path=args.adapter_path)
    else:
        model, tokenizer = load(args.model)
    print(f"Model loaded in {time.time() - t0:.1f}s", flush=True)
    return model, tokenizer


def generate(
    model,
    tokenizer,
    user_prompt: str,
    max_tokens: int,
    temp: float,
    top_p: float,
    verbose: bool,
    system_prompt: str = SYSTEM_PROMPT,
) -> str:
    from mlx_lm import stream_generate
    from mlx_lm.sample_utils import make_sampler, make_logits_processors

    prompt = build_inference_prompt(user_prompt, system_prompt=system_prompt)
    prompt_tokens = tokenizer.encode(prompt, add_special_tokens=False)
    sampler = make_sampler(temp=temp, top_p=top_p)
    processors = make_logits_processors(repetition_penalty=1.12, repetition_context_size=96)

    parts: list[str] = []
    t0 = time.time()
    last_dot = t0
    token_count = 0
    for i, response in enumerate(
        stream_generate(
            model,
            tokenizer,
            prompt=prompt_tokens,
            max_tokens=max_tokens,
            sampler=sampler,
            logits_processors=processors,
        )
    ):
        token_count = i + 1
        if response.text:
            parts.append(response.text)
        if verbose and time.time() - last_dot >= 2.0:
            print(".", end="", flush=True)
            last_dot = time.time()
        if verbose and i > 0 and i % 50 == 0:
            print(f" [{i} tokens]", end="", flush=True)

    if verbose:
        print(f" done ({token_count} tokens, {time.time() - t0:.1f}s)", flush=True)

    text = "".join(parts).strip()
    if "<|assistant|>" in text:
        text = text.split("<|assistant|>", 1)[-1].strip()
    if "<|end|>" in text:
        text = text.split("<|end|>", 1)[0].strip()
    return text


def route_with_base_model(
    router_model,
    router_tokenizer,
    user_prompt: str,
) -> RouterDecision:
    router_system = (
        "You normalize messy healthcare-worker prompts for a hearing assistant. "
        "Return exactly 4 lines:\n"
        "INTENT: answer|referral\n"
        "NORMALIZED_PROMPT: <single cleaned prompt>\n"
        "NEEDS_CLARIFICATION: yes|no\n"
        "CLARIFICATION_QUESTION: <one short question or none>"
    )
    router_user = (
        f"Original prompt:\n{user_prompt}\n\n"
        "Rules:\n"
        "- Keep all entities exactly when present (name, age, hospital, specialist).\n"
        "- If user asks referral/advice without destination, keep it as advice-style referral request.\n"
        "- For very short/ambiguous prompts (1-2 words), set NEEDS_CLARIFICATION=yes.\n"
    )
    routed = generate(
        model=router_model,
        tokenizer=router_tokenizer,
        user_prompt=router_user,
        max_tokens=120,
        temp=0.0,
        top_p=1.0,
        verbose=False,
        system_prompt=router_system,
    )
    intent_match = re.search(r"INTENT:\s*(answer|referral)", routed, flags=re.IGNORECASE)
    normalized_match = re.search(r"NORMALIZED_PROMPT:\s*(.+)", routed, flags=re.IGNORECASE)
    clarify_match = re.search(r"NEEDS_CLARIFICATION:\s*(yes|no)", routed, flags=re.IGNORECASE)
    question_match = re.search(r"CLARIFICATION_QUESTION:\s*(.+)", routed, flags=re.IGNORECASE)

    intent = intent_match.group(1).lower() if intent_match else detect_intent_from_keywords(user_prompt)
    normalized_prompt = (
        normalized_match.group(1).strip() if normalized_match else user_prompt.strip()
    )
    if not normalized_prompt or normalized_prompt.startswith("<"):
        normalized_prompt = user_prompt.strip()
    needs_clarification = (
        clarify_match.group(1).lower() == "yes"
        if clarify_match
        else (len(user_prompt.strip().split()) <= 2)
    )
    if len(user_prompt.strip().split()) > 4:
        needs_clarification = False
    clarification_question = question_match.group(1).strip() if question_match else ""
    if clarification_question.lower() in {"none", "n/a", "na"} or clarification_question.startswith("<"):
        clarification_question = ""
    if not clarification_question and needs_clarification:
        clarification_question = (
            "Could you share age, key symptom, and whether you want advice or referral?"
        )
    if intent == "answer" and detect_intent_from_keywords(user_prompt) == "referral":
        intent = "referral"
    return RouterDecision(
        intent=intent,
        normalized_prompt=normalized_prompt,
        needs_clarification=needs_clarification,
        clarification_question=clarification_question,
    )


def build_human_fuzzy_prompts() -> list[tuple[str, str]]:
    return [
        ("h1", "what medicine ear infection 2yr"),
        ("h2", "GLUE EAR?"),
        ("h3", "failed oae now what"),
        ("h4", "risk 82"),
        ("h5", "urgent refer?"),
        ("h6", "plz gen referral ahmed 3y risk82 refer to ent childrens lahore"),
        ("h7", "CREATE REFERRAL FOR SARA GLUE EAR AGA KHAN KARACHI AUDIOLOGIST"),
        ("h8", "generate referal for bilal, hgh risk, send to paeds ent mayo hospitla lahore"),
        ("h9", "give precautions only no refer"),
        ("h10", "create referral if needed otherwise home advice for failed oae"),
        ("h11", "amox dose for 3yr otitis?"),
        ("h12", "ear discharge + fever + speech delay what do i do"),
        ("h13", "FOLLOWUP TIMELINE?"),
        ("h14", "ENT OR AUDIOLOGIST FIRST"),
        ("h15", "child not responding to name"),
    ]


def has_markdown_artifacts(text: str) -> bool:
    return bool(re.search(r"\*\*|```|^#{1,6}\s", text, flags=re.MULTILINE))


def contains_any(text: str, needles: tuple[str, ...]) -> bool:
    lower = text.lower()
    return any(n.lower() in lower for n in needles)


def has_section_headers(output: str, with_refer_to: bool) -> bool:
    sections = REFERRAL_SECTIONS if with_refer_to else ADVICE_SECTIONS
    return all(section in output for section in sections)


def has_trailing_garbage(output: str) -> bool:
    """Detect dataset bleed / degenerate tail after the disclaimer."""
    if DISCLAIMER not in output:
        return False
    tail = output.split(DISCLAIMER, 1)[-1].strip()
    if not tail:
        return False
    junk_markers = (
        "immediate complications",
        "disposition:",
        "clinical context:",
        "| ent -",
        "tolerated the procedure",
    )
    lower = tail.lower()
    return any(m in lower for m in junk_markers) or len(tail) > 40


def has_medicine_dosage(output: str) -> bool:
    if DOSAGE_PATTERN.search(output):
        return True
    if "MEDICINES" not in output.upper():
        return False
    med_block = output.split("MEDICINES", 1)[-1].split("PRECAUTIONS", 1)[0]
    return bool(DOSAGE_PATTERN.search(med_block))


def run_checks(
    case: TestCase, output: str
) -> tuple[bool, dict[str, bool], dict[str, dict[str, bool]]]:
    checks: dict[str, bool] = {}
    categories: dict[str, dict[str, bool]] = {
        "format": {},
        "fidelity": {},
        "safety": {},
    }
    lower = output.lower()

    checks["non_empty"] = len(output.strip()) >= 40
    checks["no_markdown"] = not has_markdown_artifacts(output)
    checks["clean_ending"] = not has_trailing_garbage(output)
    # Observational fields are printed for debugging but not always required.
    checks["obs_has_refer_to"] = "REFER TO:" in output
    checks["obs_has_disclaimer"] = DISCLAIMER in output

    if case.expected_intent == "answer":
        checks["title_check"] = (
            "PATIENT REFERRAL" not in output and "PATIENT CARE ADVICE" not in output
        )
        checks["refer_to_rule"] = True
        checks["disclaimer_rule"] = True
        checks["not_doctor_letter"] = "dear colleague" not in lower
    else:
        checks["title_check"] = (
            case.expected_title in output if case.expected_title else True
        )
        checks["disclaimer_rule"] = checks["obs_has_disclaimer"]
        if case.expect_refer_to is None:
            checks["refer_to_rule"] = True
        else:
            checks["refer_to_rule"] = checks["obs_has_refer_to"] == case.expect_refer_to

        with_refer = case.expect_refer_to is True
        checks["section_headers"] = has_section_headers(output, with_refer_to=with_refer)
        checks["patient_name"] = (
            case.patient_name is None
            or f"patient: {case.patient_name.lower()}" in lower
            or case.patient_name.lower() in lower
        )
        checks["age_hint"] = case.age_hint is None or case.age_hint.lower() in lower
        checks["hospital"] = (
            case.hospital is None or case.hospital.lower() in lower
        )
        checks["specialist"] = (
            not case.specialist_keywords or contains_any(output, case.specialist_keywords)
        )
        checks["condition_keywords"] = (
            not case.condition_keywords or contains_any(output, case.condition_keywords)
        )
        checks["risk_score"] = (
            case.risk_score is None or str(case.risk_score) in output
        )
        checks["medicine_keywords"] = (
            not case.expect_medicines
            or contains_any(output, case.medicine_keywords)
            or "medicines" in lower
        )
        if case.expect_medicines:
            checks["medicine_dosage"] = has_medicine_dosage(output)
        else:
            checks["medicine_dosage"] = True
        expected_footer = case.footer_line or (
            "This referral was generated by HearTech screening system."
            if with_refer
            else "This advice was generated by HearTech screening system."
        )
        checks["footer_line"] = expected_footer in output
        checks["not_doctor_letter"] = "dear colleague" not in lower
        checks["clean_ending"] = not has_trailing_garbage(output)

    categories["format"]["non_empty"] = checks["non_empty"]
    categories["format"]["no_markdown"] = checks["no_markdown"]
    categories["format"]["title_check"] = checks["title_check"]
    categories["format"]["refer_to_rule"] = checks["refer_to_rule"]
    if case.expected_intent == "referral":
        categories["format"]["section_headers"] = checks["section_headers"]
        categories["format"]["footer_line"] = checks["footer_line"]

    categories["fidelity"]["not_doctor_letter"] = checks["not_doctor_letter"]
    if case.expected_intent == "referral":
        categories["fidelity"]["patient_name"] = checks["patient_name"]
        categories["fidelity"]["age_hint"] = checks["age_hint"]
        categories["fidelity"]["hospital"] = checks["hospital"]
        categories["fidelity"]["specialist"] = checks["specialist"]
        categories["fidelity"]["condition_keywords"] = checks["condition_keywords"]
        categories["fidelity"]["risk_score"] = checks["risk_score"]
        categories["fidelity"]["medicine_keywords"] = checks["medicine_keywords"]
        categories["fidelity"]["medicine_dosage"] = checks["medicine_dosage"]

    categories["safety"]["disclaimer_rule"] = checks["disclaimer_rule"]
    categories["safety"]["clean_ending"] = checks["clean_ending"]

    passed = all(
        ok
        for section in categories.values()
        for ok in section.values()
    )
    return passed, checks, categories


def build_test_suite() -> list[TestCase]:
    return [
        TestCase("q1", "What does recurrent ear infection mean for a 2-year-old?", "answer", None, None, 280),
        TestCase("q2", "What medicine is best for otitis media in children?", "answer", None, None, 280),
        TestCase("q3", "What precautions should I give a parent for hearing loss risk?", "answer", None, None, 280),
        TestCase("q4", "What are the signs of sensorineural hearing loss in infants?", "answer", None, None, 280),
        TestCase("q5", "What does a risk score of 78 mean for a 3-year-old child?", "answer", None, None, 280),
        TestCase(
            "r1",
            "Generate referral for Ahmed, 3 years, risk score 82, recurrent ear infections, refer to ENT at Children's Hospital Lahore",
            "referral",
            True,
            "PATIENT REFERRAL",
            420,
            patient_name="Ahmed",
            age_hint="3 years",
            hospital="Children's Hospital Lahore",
            specialist_keywords=("ENT",),
            condition_keywords=("ear infection", "recurrent"),
            risk_score=82,
        ),
        TestCase(
            "r2",
            "Create referral: Sara, glue ear, refer to audiologist at Aga Khan Hospital Karachi",
            "referral",
            True,
            "PATIENT REFERRAL",
            420,
            patient_name="Sara",
            hospital="Aga Khan Hospital Karachi",
            specialist_keywords=("audiologist",),
            condition_keywords=("glue ear",),
        ),
        TestCase(
            "r3",
            "I need a referral for Bilal, high risk, send to paediatric ENT specialist at Mayo Hospital Lahore",
            "referral",
            True,
            "PATIENT REFERRAL",
            420,
            patient_name="Bilal",
            hospital="Mayo Hospital Lahore",
            specialist_keywords=("ENT", "paediatric"),
        ),
        TestCase(
            "a1",
            "Generate referral for Inaya, 2 years, risk score 58, prescribe amoxicillin and give home care advice",
            "referral",
            False,
            "PATIENT CARE ADVICE",
            420,
            patient_name="Inaya",
            age_hint="2 years",
            risk_score=58,
            expect_medicines=True,
            medicine_keywords=("amoxicillin",),
            footer_line="This advice was generated by HearTech screening system.",
        ),
        TestCase(
            "a2",
            "Create referral with medicines and precautions for Rayyan, no specialist mentioned",
            "referral",
            False,
            "PATIENT CARE ADVICE",
            420,
            patient_name="Rayyan",
            expect_medicines=True,
            medicine_keywords=("mg", "ml", "drops", "amoxicillin", "paracetamol", "ibuprofen"),
            footer_line="This advice was generated by HearTech screening system.",
        ),
        TestCase(
            "a3",
            "Make referral for Noor, medium risk, give parent precautions and follow-up only",
            "referral",
            False,
            "PATIENT CARE ADVICE",
            420,
            patient_name="Noor",
            footer_line="This advice was generated by HearTech screening system.",
        ),
        TestCase(
            "amb1",
            "Should I refer this child now or monitor for 2 weeks?",
            "answer",
            None,
            None,
            280,
        ),
        TestCase(
            "amb2",
            "Create a referral if needed, otherwise explain precautions for failed OAE",
            "referral",
            False,
            "PATIENT CARE ADVICE",
            420,
            condition_keywords=("OAE", "precaution"),
            footer_line="This advice was generated by HearTech screening system.",
        ),
    ]


def format_checks(checks: dict[str, bool], categories: dict[str, dict[str, bool]]) -> str:
    required = {
        name
        for section in categories.values()
        for name in section.keys()
    }
    failed = [name for name in required if not checks.get(name, False)]
    if not failed:
        return "all passed"
    return "FAILED: " + ", ".join(failed)


def main() -> int:
    parser = argparse.ArgumentParser(description="Test HearTech medical model behavior")
    parser.add_argument("--model", default="./heartech_medical_model", help="Fused model path")
    parser.add_argument("--base-model", default="", help="Base model path/name when using adapter")
    parser.add_argument("--adapter-path", default="", help="Adapter path (optional)")
    parser.add_argument("--max-tokens", type=int, default=0, help="Override per-case token limits")
    parser.add_argument("--temp", type=float, default=0.2)
    parser.add_argument("--top-p", type=float, default=0.9)
    parser.add_argument("--only", default="", help="Run one test id, e.g. q1 or r1")
    parser.add_argument("--verbose", action="store_true", help="Show generation progress")
    parser.add_argument("--show-full", action="store_true", help="Print full model output per test")
    parser.add_argument(
        "--use-base-router",
        action="store_true",
        help="Use base Llama to normalize messy prompts before final generation.",
    )
    parser.add_argument(
        "--router-model",
        default="meta-llama/Llama-3.2-3B",
        help="Base router model path/name used with --use-base-router.",
    )
    parser.add_argument(
        "--human-fuzzy",
        action="store_true",
        help="Run human-style messy prompt test set.",
    )
    parser.add_argument(
        "--release-gate",
        action="store_true",
        help="Release gate mode: excludes amb* tests unless --include-ambiguous is set.",
    )
    parser.add_argument(
        "--include-ambiguous",
        action="store_true",
        help="Include amb* tests even when --release-gate is enabled.",
    )
    args = parser.parse_args()

    if args.human_fuzzy:
        fuzzy = build_human_fuzzy_prompts()
        routed: dict[str, RouterDecision] = {}
        if args.use_base_router:
            router_model, router_tokenizer = load_plain_model(args.router_model)
            for pid, prompt in fuzzy:
                routed[pid] = route_with_base_model(router_model, router_tokenizer, prompt)
            del router_model, router_tokenizer
            gc.collect()

        model, tokenizer = load_model(args)
        print(f"\nRunning {len(fuzzy)} human-fuzzy prompt(s)...", flush=True)
        for pid, prompt in fuzzy:
            decision = routed.get(
                pid,
                RouterDecision(
                    intent=detect_intent_from_keywords(prompt),
                    normalized_prompt=prompt,
                    needs_clarification=False,
                    clarification_question="",
                ),
            )
            user_prompt = decision.normalized_prompt
            if decision.needs_clarification and decision.intent == "answer":
                output = decision.clarification_question
                tok_count = 0
            else:
                before = time.time()
                output = generate(
                    model=model,
                    tokenizer=tokenizer,
                    user_prompt=user_prompt,
                    max_tokens=args.max_tokens or 220,
                    temp=args.temp,
                    top_p=args.top_p,
                    verbose=False,
                )
                tok_count = -1
                if args.verbose:
                    print(f"[{pid}] elapsed={time.time()-before:.1f}s")
            preview = " ".join(output.split())[:380]
            print(f"\n[{pid}] raw: {prompt}")
            if args.use_base_router:
                print(
                    f"  router intent={decision.intent} needs_clarification={decision.needs_clarification}"
                )
                print(f"  normalized: {user_prompt}")
            if tok_count == 0:
                print("  output_type=clarification")
            print(f"  output: {preview}")
            if args.show_full:
                print("  --- full output ---")
                print(output)
                print("  --- end output ---")
        return 0

    routed_tests: dict[str, RouterDecision] = {}
    tests = build_test_suite()
    if args.release_gate and not args.include_ambiguous:
        tests = [t for t in tests if not t.prompt_id.startswith("amb")]
    if args.only:
        tests = [t for t in tests if t.prompt_id == args.only]
        if not tests:
            print(f"Unknown test id: {args.only}", file=sys.stderr)
            return 2

    if args.use_base_router:
        router_model, router_tokenizer = load_plain_model(args.router_model)
        for case in tests:
            routed_tests[case.prompt_id] = route_with_base_model(
                router_model, router_tokenizer, case.user_prompt
            )
        del router_model, router_tokenizer
        gc.collect()

    model, tokenizer = load_model(args)

    total = 0
    failed = 0
    print(f"\nRunning {len(tests)} test(s)...", flush=True)

    for case in tests:
        total += 1
        decision = routed_tests.get(
            case.prompt_id,
            RouterDecision(
                intent=detect_intent_from_keywords(case.user_prompt),
                normalized_prompt=case.user_prompt,
                needs_clarification=False,
                clarification_question="",
            ),
        )
        detected_intent = decision.intent
        max_tokens = args.max_tokens or case.max_tokens
        print(f"\n[{case.prompt_id}] generating (max {max_tokens} tokens)...", flush=True)
        if args.use_base_router:
            print(
                f"  router: intent={decision.intent} clarification={decision.needs_clarification}"
            )
            print(f"  router_prompt: {decision.normalized_prompt}")

        output = generate(
            model=model,
            tokenizer=tokenizer,
            user_prompt=decision.normalized_prompt,
            max_tokens=max_tokens,
            temp=args.temp,
            top_p=args.top_p,
            verbose=args.verbose,
        )

        intent_ok = detected_intent == case.expected_intent
        passed, checks, categories = run_checks(case, output)
        ok = intent_ok and passed
        if not ok:
            failed += 1

        preview = " ".join(output.split())[:220]
        print(f"[{case.prompt_id}] {'PASS' if ok else 'FAIL'}")
        print(f"  expected_intent={case.expected_intent} detected_intent={detected_intent}")
        if not intent_ok:
            print("  intent: FAILED")
        print(f"  checks: {format_checks(checks, categories)}")
        for section_name, section in categories.items():
            section_failed = [k for k, v in section.items() if not v]
            if section_failed:
                print(f"  {section_name}: FAIL ({', '.join(section_failed)})")
            else:
                print(f"  {section_name}: PASS")
        for name, value in checks.items():
            print(f"    {name}={value}")
        print(f"  preview: {preview}")
        if args.show_full:
            print("  --- full output ---")
            print(output)
            print("  --- end output ---")

    print(f"\nSummary: {total - failed}/{total} passed, {failed} failed")
    if args.release_gate:
        print(
            f"Release gate summary (non-amb unless overridden): {total - failed}/{total} passed",
            flush=True,
        )
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
