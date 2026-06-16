#!/usr/bin/env python3
"""
Generate HearTech referral dataset v2 (prompt/completion JSONL for MLX LoRA + mask_prompt).

Usage:
  python scripts/generate_referral_dataset_v2.py --train 12000 --valid 1500 --test 1500
"""
from __future__ import annotations

import argparse
import json
import random
import re
from datetime import date, timedelta
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
AI_ROOT = SCRIPT_DIR.parent
DEFAULT_OUT = AI_ROOT / "heartech_dataset_v2"

PROMPT_HEADER = (
    "You are a clinical audiologist assistant for HearTech, "
    "a paediatric hearing screening system.\n\n"
    "Generate a formal paediatric hearing referral letter "
    "using the following data:\n\n"
)

PROMPT_FOOTER = "Write the complete referral letter:\n\n"

# ── Name / hospital pools ───────────────────────────────────────────────────
FIRST_NAMES = [
    "Ayesha", "Fatima", "Zainab", "Maryam", "Hania", "Sana", "Iqra", "Laiba",
    "Ahmed", "Hassan", "Usman", "Bilal", "Hamza", "Omar", "Ali", "Hussain",
    "Khadija", "Yasmeen", "Danyal", "Nana", "Saad", "Rayyan", "Inaya", "Musa",
]
LAST_NAMES = [
    "Khan", "Malik", "Sheikh", "Ahmed", "Hussain", "Raza", "Iqbal", "Siddiqui",
    "Farooq", "Nawaz", "Bangash", "Qureshi", "Mirza", "Chaudhry", "Abbasi",
]
TITLES = ["Dr.", "Dr.", "Dr.", "Assoc. Prof.", "Prof."]
SPECIALTIES = [
    "Paediatric Audiologist", "ENT Specialist", "Developmental Paediatrician",
    "Paediatrician", "Neonatologist", "General Practitioner",
]
HOSPITALS = [
    "Aga Khan University Hospital Karachi", "Shaukat Khanum Memorial Cancer Hospital",
    "Holy Family Hospital Rawalpindi", "Mayo Hospital Lahore",
    "Nishtar Medical University Multan", "Pakistan Institute of Medical Sciences",
    "Combined Military Hospital Rawalpindi", "Indus Hospital Karachi",
    "Liaquat National Hospital", "Services Hospital Lahore",
    "Lady Reading Hospital Peshawar", "Civil Hospital Karachi",
]
RECIPIENT_ROLES = [
    "The Paediatric Audiologist", "The ENT Specialist",
    "The Developmental Paediatrician", "The Paediatrician",
    "The Paediatric ENT Department", "The Audiology Clinic",
]
RECIPIENT_DEPTS = [
    "Paediatric Audiology Clinic", "Department of Otolaryngology",
    "Paediatric Hearing Centre", "Child Development Unit",
    "ENT Outpatient Department", "Cochlear Implant Programme",
]

AGE_BRACKETS = {
    "newborn": (0, 3, "newborn"),
    "young infant": (3, 9, "young infant"),
    "older infant": (9, 18, "older infant"),
    "toddler": (18, 36, "toddler"),
    "preschool": (36, 60, "preschool child"),
    "school age": (60, 144, "school-age child"),
}

DEV_BY_BRACKET = {
    "newborn": "startle responses to sound, early cooing, and orientation to voice",
    "young infant": "localisation to sound, consonant-vowel babbling, and joint attention",
    "older infant": "localisation, babbling, joint attention, and early word forms",
    "toddler": "first words, two-word combinations, following simple instructions, and turn-taking",
    "preschool": "sentence formation, speech clarity, and classroom listening skills",
    "school age": "academic listening, speech discrimination, and peer communication",
}

FLAGS_POOL = [
    "Premature birth (<37 weeks gestation)",
    "NICU admission in neonatal period",
    "Family history of childhood-onset sensorineural hearing loss",
    "Recurrent otitis media ({n} episodes in past 12 months)",
    "Failed or absent newborn hearing screening",
    "Cytomegalovirus (CMV) infection in infancy",
    "Down syndrome with known audiological risk",
    "Significant speech and language delay (approx. {months} months behind peers)",
    "Asymmetric hearing responses on clinical observation",
    "Unilateral hearing concern reported by caregiver",
    "Persistent tinnitus reported by caregiver",
    "Reduced vocalisation since last clinical visit",
    "Parent reports child increases television volume excessively",
    "Ototoxic medication exposure in neonatal period",
    "Craniofacial anomaly associated with hearing risk",
    "Meningitis during infancy",
    "Hyperbilirubinaemia requiring exchange transfusion",
    "TORCH infection in pregnancy",
    "Sibling with confirmed permanent hearing loss",
    "Teacher concern regarding classroom listening",
]

INVESTIGATIONS_BY_RISK = {
    "LOW": [
        "Behavioural observation audiometry (BOA)",
        "Tympanometry and otoscopy",
        "Speech and language therapy screening assessment",
        "Otoacoustic emissions (OAE) repeat screening",
    ],
    "MEDIUM": [
        "Play audiometry — conditioned responses",
        "Tympanometry and acoustic reflex testing",
        "Auditory Brainstem Response (ABR) — click and tone-burst stimuli",
        "Speech discrimination and recognition testing",
        "Speech and language therapy assessment",
    ],
    "HIGH": [
        "Auditory Brainstem Response (ABR) — click and tone-burst stimuli",
        "Auditory steady-state response (ASSR)",
        "High-frequency audiometry (above 8 kHz)",
        "MRI internal auditory meatus protocol if indicated",
        "Genetic counselling referral for syndromic hearing loss workup",
        "Speech and language therapy urgent assessment",
    ],
}

PRECAUTIONS = [
    "Minimise exposure to loud environments; use hearing protection where appropriate",
    "Ensure the child's class teacher is informed of the potential hearing concern",
    "Seat the child near the teacher during group instruction",
    "Avoid insertion of objects into the ear canal; seek review if ear pain develops",
    "Monitor for delayed speech milestones and re-screen in 3 months if concerns persist",
    "Provide clear visual cues during communication at home",
    "Limit prolonged headphone use at high volume",
    "Follow up ear infections promptly with primary care or ENT",
]

HCW_INSTRUCTIONS = [
    "Please recommend the most appropriate investigations for this child's age and risk profile.",
    "Make this referral urgent and request review within two weeks.",
    "Parent reports the child turns the television volume to maximum — please note this as a clinical indicator.",
    "Child has had multiple ear infections this year — please reference this and suggest ENT review.",
    "Include speech and language therapy in the management plan.",
    "Add genetic counselling given the family history of hearing loss.",
    "Request ABR testing as a priority investigation.",
    "Suggest behavioural observation audiometry given the child's age.",
    "Please note asymmetric responses observed during screening.",
    "Recommend school seating adjustments and teacher notification.",
    "Include precautions for parents regarding noise exposure at home.",
    "Request cochlear implant programme opinion if bilateral severe loss is confirmed.",
    "Emphasise need for early intervention given high risk score.",
    "Please add tympanometry and assess for middle-ear effusion.",
    "Include developmental paediatrician input for global developmental concerns.",
    "Suggest ASSR testing in addition to standard audiometry.",
    "Make routine follow-up in 2–3 months unless findings warrant earlier review.",
    "Document NICU history and link to neonatal hearing surveillance pathway.",
    "Please include CMV-related audiological surveillance in the plan.",
    "Add parental guidance on communication strategies pending definitive results.",
    "Request high-frequency audiometry given risk profile.",
    "Note failed newborn screen and recommend diagnostic assessment.",
    "Include precautions for swimming and bathing if tympanostomy tubes considered.",
    "Suggest play audiometry when developmentally appropriate.",
    "Please reference Down syndrome audiological surveillance guidelines.",
    "Add ENT review for recurrent otitis media management.",
    "Request MRI only if asymmetric sensorineural loss is suspected clinically.",
    "Include teacher questionnaire for classroom listening behaviours.",
    "Emphasise sibling screening given family history.",
    "Suggest otoacoustic emissions and ABR as combined protocol.",
]

OPENING_LINES = [
    "Thank you for seeing {name}, aged {age}. This child was screened using the HearTech paediatric hearing detection system, and the results suggest clinical follow-up is warranted.",
    "I write to seek your expert opinion regarding {name} ({age}), who was assessed through the HearTech structured hearing screening protocol.",
    "I would like to bring to your attention the case of {name}, a {age} old child, whose recent hearing risk screening has yielded findings requiring specialist assessment.",
    "Please accept this referral for {name} (date of birth {dob}), following a structured HearTech hearing risk assessment.",
]

RISK_NARRATIVE = {
    "LOW": "This places the child in the low risk band, suggesting a low but non-negligible probability of subclinical hearing difficulty.",
    "MEDIUM": "This finding is clinically significant as it indicates developmental patterns associated with undetected hearing difficulty.",
    "HIGH": "This finding is clinically significant as it indicates a critical risk profile consistent with significant audiological pathology.",
}

URGENCY_BY_RISK = {
    "LOW": "It is recommended that this child be reviewed on a routine basis within the next 2–3 months. Routine monitoring is appropriate at this stage.",
    "MEDIUM": "Review within 4–6 weeks is recommended to exclude progressive or undiagnosed hearing loss.",
    "HIGH": "Urgent specialist review within 2 weeks is recommended given the risk profile and clinical indicators identified.",
}


def age_string(months: int) -> str:
    if months < 1:
        return "newborn"
    if months < 24:
        m = months
        return f"{m} month{'s' if m != 1 else ''}"
    years, rem = divmod(months, 12)
    parts = []
    if years:
        parts.append(f"{years} year{'s' if years != 1 else ''}")
    if rem:
        parts.append(f"{rem} month{'s' if rem != 1 else ''}")
    return " and ".join(parts)


def pick_bracket(months: int) -> str:
    for _, (lo, hi, label) in AGE_BRACKETS.items():
        if lo <= months < hi:
            return label
    return "school-age child"


def risk_from_score(score: int) -> str:
    if score <= 33:
        return "LOW"
    if score <= 66:
        return "MEDIUM"
    return "HIGH"


def score_for_risk(risk: str, rng: random.Random) -> int:
    if risk == "LOW":
        return rng.randint(3, 33)
    if risk == "MEDIUM":
        return rng.randint(34, 66)
    return rng.randint(67, 98)


def build_prompt(
    name: str,
    age: str,
    gender: str,
    dob: str,
    score: int,
    risk: str,
    bracket: str,
    flags: list[str],
    hcw_title: str,
    hcw_name: str,
    hcw_spec: str,
    hcw_hospital: str,
    instruction: str,
) -> str:
    flags_str = "; ".join(flags) if flags else "None reported"
    body = (
        f"Patient Name: {name}\n"
        f"Age: {age}\n"
        f"Gender: {gender}\n"
        f"Date of Birth: {dob}\n"
        f"Risk Score: {score}/100\n"
        f"Risk Level: {risk}\n"
        f"Age Bracket: {bracket}\n"
        f"Clinical Risk Flags: {flags_str}\n"
        f"Referring Clinician: {hcw_title} {hcw_name} ({hcw_spec}), {hcw_hospital}\n"
        f"Clinician Instruction: {instruction}\n\n"
    )
    return PROMPT_HEADER + body + PROMPT_FOOTER


def build_completion(
    rng: random.Random,
    name: str,
    age: str,
    dob: str,
    risk: str,
    score: int,
    bracket: str,
    flags: list[str],
    instruction: str,
    hcw_title: str,
    hcw_name: str,
    hcw_spec: str,
    hcw_hospital: str,
) -> str:
    today = date(2026, 5, 22)
    recipient = rng.choice(RECIPIENT_ROLES)
    dept = rng.choice(RECIPIENT_DEPTS)
    hospital = rng.choice(HOSPITALS)
    opening = rng.choice(OPENING_LINES).format(
        name=name, age=age, dob=dob
    )
    dev_key = "school age" if bracket == "school-age child" else bracket
    dev = DEV_BY_BRACKET.get(dev_key, DEV_BY_BRACKET["toddler"])

    inv_pool = INVESTIGATIONS_BY_RISK[risk][:]
    rng.shuffle(inv_pool)
    n_inv = 2 if risk == "LOW" else (4 if risk == "MEDIUM" else 5)
    investigations = inv_pool[:n_inv]

    prec = rng.sample(PRECAUTIONS, k=3 if risk != "LOW" else 2)

    lines = [
        f"Date: {today.strftime('%d %B %Y')}",
        "",
        "To,",
        recipient,
        f"{dept}, {hospital}",
        "",
        f"Subject: Paediatric Hearing Referral — {name} | D.O.B: {dob} | Risk Level: {risk}",
        "",
        "Dear Colleague,",
        "",
        opening,
        "",
        "CLINICAL SUMMARY:",
        "",
        f"The standardised assessment produced a risk score of {score}/100 ({risk.lower()} risk). "
        f"{RISK_NARRATIVE[risk]}",
        "",
        f"The child's current developmental stage ({bracket}) is characterised by expected progress in "
        f"{dev}. The screening assessment identified deviations from age-expected norms that are "
        f"consistent with the risk classification above.",
        "",
    ]

    if flags:
        lines.append("IDENTIFIED RISK FACTORS:")
        lines.append("")
        for f in flags:
            lines.append(f"  • {f}")
        lines.append("")

    lines.extend([
        "ADDITIONAL CLINICAL NOTES FROM REFERRING CLINICIAN:",
        "",
        instruction,
        "",
        "RECOMMENDED INVESTIGATIONS:",
        "",
        "The following investigations are recommended in order of clinical priority:",
        "",
    ])
    for i, inv in enumerate(investigations, 1):
        lines.append(f"  {i}. {inv}")
    lines.append("")

    lines.extend([
        "PRECAUTIONARY MEASURES AND PARENTAL GUIDANCE:",
        "",
        "The following recommendations have been communicated to the family and should be "
        "reinforced at the specialist visit:",
        "",
    ])
    for p in prec:
        lines.append(f"  • {p}")
    lines.append("")

    lines.extend([
        "URGENCY AND TIMELINE:",
        "",
        URGENCY_BY_RISK[risk],
        "",
        "I appreciate your consideration of this referral and your support in ensuring this child "
        "receives appropriate audiological care. Please contact me with any queries.",
        "",
        "Yours sincerely,",
        "",
        f"{hcw_title} {hcw_name}",
        hcw_spec,
        hcw_hospital,
    ])
    return "\n".join(lines)


def sample_example(rng: random.Random, idx: int) -> dict:
    gender = rng.choice(["Male", "Female"])
    months = rng.randint(0, 140)
    bracket = pick_bracket(months)
    age = age_string(months)
    dob_dt = date(2026, 5, 22) - timedelta(days=months * 30)
    dob = f"{dob_dt.day} {dob_dt.strftime('%B')} {dob_dt.year}"

    risk = rng.choices(["LOW", "MEDIUM", "HIGH"], weights=[0.25, 0.4, 0.35])[0]
    score = score_for_risk(risk, rng)

    first, last = rng.choice(FIRST_NAMES), rng.choice(LAST_NAMES)
    name = f"{first} {last}"

    n_flags = rng.randint(0, 4) if risk == "LOW" else rng.randint(1, 5)
    flags = []
    pool = FLAGS_POOL.copy()
    rng.shuffle(pool)
    for tpl in pool[:n_flags]:
        flags.append(
            tpl.format(n=rng.randint(2, 8), months=rng.randint(3, 18))
        )

    hcw_title = rng.choice(TITLES)
    hcw_name = f"{rng.choice(FIRST_NAMES)} {rng.choice(LAST_NAMES)}"
    hcw_spec = rng.choice(SPECIALTIES)
    hcw_hospital = rng.choice(HOSPITALS)
    instruction = rng.choice(HCW_INSTRUCTIONS)
    if idx % 17 == 0:
        instruction = (
            f"{instruction} Also document: {rng.choice(HCW_INSTRUCTIONS).lower()}"
        )

    prompt = build_prompt(
        name, age, gender, dob, score, risk, bracket, flags,
        hcw_title, hcw_name, hcw_spec, hcw_hospital, instruction,
    )
    completion = build_completion(
        rng, name, age, dob, risk, score, bracket, flags, instruction,
        hcw_title, hcw_name, hcw_spec, hcw_hospital,
    )
    return {"prompt": prompt, "completion": completion}


def write_split(path: Path, count: int, seed: int) -> None:
    rng = random.Random(seed)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        for i in range(count):
            row = sample_example(rng, i)
            f.write(json.dumps(row, ensure_ascii=False) + "\n")
    print(f"Wrote {count} examples -> {path}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate HearTech referral dataset v2")
    parser.add_argument("--train", type=int, default=12000)
    parser.add_argument("--valid", type=int, default=1500)
    parser.add_argument("--test", type=int, default=1500)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    out = args.out
    write_split(out / "train.jsonl", args.train, args.seed)
    write_split(out / "valid.jsonl", args.valid, args.seed + 1)
    write_split(out / "test.jsonl", args.test, args.seed + 2)
    print(f"Done. Total {args.train + args.valid + args.test} examples in {out}")


if __name__ == "__main__":
    main()
