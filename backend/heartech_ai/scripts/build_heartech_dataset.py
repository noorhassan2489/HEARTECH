#!/usr/bin/env python3
"""
Build HearTech dataset v3:
- Read/filter raw medical datasets from ~/HEARTECH/dataset
- Generate 20,000 clinical Q&A samples
- Generate 20,000 referral/advice samples (10k with REFER TO, 10k without)
- Save strict training format:
  {"text":"<|system|>...<|end|>\n<|user|>...<|end|>\n<|assistant|>...<|end|>"}
"""

from __future__ import annotations

import argparse
import csv
import json
import random
import re
import textwrap
import zipfile
from collections import Counter, defaultdict
from datetime import date
from pathlib import Path
from typing import Iterable


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

INCLUDE_TERMS = [
    "ear infection",
    "otitis media",
    "otitis externa",
    "glue ear",
    "hearing loss",
    "sensorineural",
    "conductive hearing",
    "mixed hearing",
    "paediatric audiology",
    "speech delay",
    "language delay",
    "newborn hearing",
    "failed hearing screening",
    "nicu",
    "premature birth",
    "meningitis",
    "cmv",
    "ototoxic",
    "tympanometry",
    "oae",
    "abr",
    "audiometry",
    "amoxicillin",
    "azithromycin",
    "co-amoxiclav",
    "ciprofloxacin",
    "gentamicin",
    "acetic acid",
    "hearing milestone",
    "eustachian tube",
    "cholesteatoma",
]

EXCLUDE_TERMS = [
    "cardiology",
    "oncology",
    "dermatology",
    "ophthalmology",
    "orthopedic",
    "renal failure",
]

NOISY_TERMS = [
    "hello welcome",
    "chat doctor",
    "ask a doctor service",
    "icliniq",
    "cliniqcom",
    "clinical context:",
    "### response",
    "immediate complications",
    "disposition:",
]

AGES = [
    "1 month",
    "2 months",
    "3 months",
    "6 months",
    "9 months",
    "12 months",
    "18 months",
    "2 years",
    "3 years",
    "4 years",
    "5 years",
    "7 years",
    "10 years",
    "12 years",
]

CONDITIONS = [
    "otitis media",
    "otitis externa",
    "glue ear",
    "sensorineural hearing loss",
    "conductive hearing loss",
    "mixed hearing loss",
    "auditory neuropathy",
    "cholesteatoma",
    "tympanic membrane perforation",
    "cerumen impaction",
    "eustachian tube dysfunction",
]

RISK_FACTORS = [
    "premature birth at 28 weeks",
    "premature birth at 32 weeks",
    "premature birth at 35 weeks",
    "NICU admission",
    "family history of hearing loss",
    "recurrent ear infections (3 episodes)",
    "recurrent ear infections (5 episodes)",
    "recurrent ear infections (8+ episodes)",
    "failed newborn hearing screening",
    "bacterial meningitis history",
    "CMV infection",
    "hyperbilirubinaemia",
    "low birth weight",
    "ototoxic medication exposure",
    "craniofacial abnormality",
]

MEDICINES = [
    "amoxicillin",
    "co-amoxiclav",
    "azithromycin",
    "ciprofloxacin ear drops",
    "acetic acid ear drops",
    "betamethasone ear drops",
    "chloramphenicol ear drops",
    "ibuprofen",
    "paracetamol",
    "loratadine",
    "cetirizine",
    "xylometazoline nasal drops",
    "hydrogen peroxide ear drops",
    "olive oil ear drops",
]

SCORES = [15, 22, 28, 35, 42, 51, 58, 67, 74, 82, 91, 95]

SPECIALISTS = [
    "ENT Specialist",
    "Paediatric ENT",
    "Audiologist",
    "Paediatric Audiologist",
    "Speech and Language Therapist",
    "Developmental Paediatrician",
]

HOSPITALS = [
    "Children's Hospital Lahore",
    "Services Hospital Lahore",
    "Shaukat Khanum Hospital",
    "Jinnah Hospital Lahore",
    "Mayo Hospital Lahore",
    "CMH Lahore",
    "Aga Khan Hospital Karachi",
    "Nishtar Hospital Multan",
    "Lady Reading Hospital Peshawar",
]

NAMES = [
    "Ahmed", "Ayesha", "Ali", "Fatima", "Zain", "Maryam", "Hassan", "Sara",
    "Bilal", "Hania", "Usman", "Iqra", "Rayyan", "Noor", "Inaya", "Yasir",
]

AGE_BRACKETS = {
    "0-6 months": ("1 month", "2 months", "3 months", "6 months"),
    "7-12 months": ("9 months", "12 months"),
    "1-2 years": ("18 months", "2 years"),
    "3-5 years": ("3 years", "4 years", "5 years"),
    "6-12 years": ("7 years", "10 years", "12 years"),
}

MEDICINE_GUIDANCE = {
    "amoxicillin": "Amoxicillin 125mg/5ml (<1 year) or 250mg/5ml (1-5 years), every 8 hours for 5-7 days",
    "co-amoxiclav": "Co-amoxiclav 156mg/5ml for under 6 years, every 8 hours for 5-7 days",
    "azithromycin": "Azithromycin 10mg/kg once daily for 3 days",
    "ciprofloxacin ear drops": "Ciprofloxacin 0.3% ear drops, 3 drops twice daily for 7 days",
    "acetic acid ear drops": "Acetic acid 2% ear drops, 3-4 drops three times daily",
    "betamethasone ear drops": "Betamethasone ear drops, 2-3 drops twice daily for up to 7 days if prescribed",
    "chloramphenicol ear drops": "Chloramphenicol ear drops, 2-3 drops every 6-8 hours for 7 days if prescribed",
    "ibuprofen": "Ibuprofen 5-10mg/kg every 6-8 hours for pain/fever",
    "paracetamol": "Paracetamol 15mg/kg every 4-6 hours for pain/fever",
    "loratadine": "Loratadine 5mg once daily for children 2-5 years",
    "cetirizine": "Cetirizine 2.5-5mg once daily depending on age",
    "xylometazoline nasal drops": "Xylometazoline 0.05% nasal drops, short course only (max 3-5 days)",
    "hydrogen peroxide ear drops": "Hydrogen peroxide ear drops, 2-3 drops twice daily for wax softening",
    "olive oil ear drops": "Olive oil ear drops, 2-3 drops twice daily for wax softening",
}

QA_GROUP_COUNTS = {
    "symptoms_meaning": 3000,
    "medicines": 3000,
    "precautions_home_care": 3000,
    "hearing_risk_factors": 2000,
    "audiology_investigations": 2000,
    "referral_decisions": 2000,
    "risk_score_explanation": 2000,
    "hearing_milestones": 3000,
}

SAFETY_LINE = (
    "Safety note: Always confirm medicine choice and dose with a qualified clinician "
    "before administration."
)


def build_record(user_text: str, assistant_text: str) -> dict[str, str]:
    text = (
        f"<|system|>{SYSTEM_PROMPT}<|end|>\n"
        f"<|user|>{user_text}<|end|>\n"
        f"<|assistant|>{assistant_text}<|end|>"
    )
    return {"text": text}


def normalize_spaces(text: str) -> str:
    text = text.replace("\r", "\n")
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def read_text_file(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return ""


def read_csv_file(path: Path, max_rows: int = 50000) -> str:
    chunks: list[str] = []
    try:
        with path.open("r", encoding="utf-8", errors="ignore") as f:
            reader = csv.reader(f)
            for i, row in enumerate(reader):
                if i >= max_rows:
                    break
                if row:
                    chunks.append(" | ".join(c.strip() for c in row if c and c.strip()))
    except Exception:
        return ""
    return "\n".join(chunks)


def read_jsonish_file(path: Path, max_items: int = 50000) -> str:
    chunks: list[str] = []
    try:
        if path.suffix.lower() == ".jsonl":
            with path.open("r", encoding="utf-8", errors="ignore") as f:
                for i, line in enumerate(f):
                    if i >= max_items:
                        break
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        obj = json.loads(line)
                    except Exception:
                        continue
                    if isinstance(obj, dict):
                        chunks.append(" ".join(str(v) for v in obj.values() if isinstance(v, (str, int, float))))
        else:
            raw = path.read_text(encoding="utf-8", errors="ignore")
            obj = json.loads(raw)
            if isinstance(obj, dict):
                chunks.append(json.dumps(obj, ensure_ascii=False))
            elif isinstance(obj, list):
                for item in obj[:max_items]:
                    if isinstance(item, dict):
                        chunks.append(" ".join(str(v) for v in item.values() if isinstance(v, (str, int, float))))
                    else:
                        chunks.append(str(item))
    except Exception:
        return ""
    return "\n".join(chunks)


def read_pdf_file(path: Path) -> str:
    text_parts: list[str] = []
    reader = None
    try:
        from pypdf import PdfReader  # type: ignore

        reader = PdfReader(str(path))
    except Exception:
        try:
            from PyPDF2 import PdfReader  # type: ignore

            reader = PdfReader(str(path))
        except Exception:
            return ""

    try:
        for page in reader.pages:
            page_text = page.extract_text() or ""
            if page_text.strip():
                text_parts.append(page_text)
    except Exception:
        return ""
    return "\n".join(text_parts)


def read_zip_file(path: Path) -> str:
    chunks: list[str] = []
    try:
        with zipfile.ZipFile(path, "r") as zf:
            for name in zf.namelist():
                lower = name.lower()
                if lower.endswith((".txt", ".md")):
                    try:
                        chunks.append(zf.read(name).decode("utf-8", errors="ignore"))
                    except Exception:
                        continue
                elif lower.endswith(".csv"):
                    try:
                        data = zf.read(name).decode("utf-8", errors="ignore").splitlines()
                        for i, line in enumerate(data):
                            if i > 20000:
                                break
                            chunks.append(line)
                    except Exception:
                        continue
                elif lower.endswith((".jsonl", ".json")):
                    try:
                        chunks.append(zf.read(name).decode("utf-8", errors="ignore"))
                    except Exception:
                        continue
    except Exception:
        return ""
    return "\n".join(chunks)


def is_relevant(snippet: str) -> bool:
    s = snippet.lower()
    if len(s) < 80:
        return False
    if any(x in s for x in EXCLUDE_TERMS):
        return False
    if any(x in s for x in NOISY_TERMS):
        return False
    return any(term in s for term in INCLUDE_TERMS)


def extract_relevant_snippets(text: str, max_snippets: int = 5000) -> list[str]:
    parts = re.split(r"\n{2,}|(?<=[.!?])\s+(?=[A-Z])", normalize_spaces(text))
    out: list[str] = []
    for part in parts:
        p = part.strip()
        if not p:
            continue
        if is_relevant(p):
            out.append(textwrap.shorten(p, width=420, placeholder="..."))
            if len(out) >= max_snippets:
                break
    return out


def load_knowledge_pool(dataset_dir: Path) -> tuple[list[str], dict[str, int]]:
    stats = defaultdict(int)
    snippets: list[str] = []
    files = sorted([p for p in dataset_dir.rglob("*") if p.is_file()])
    for path in files:
        lower = path.name.lower()
        text = ""
        if lower.endswith(".pdf"):
            text = read_pdf_file(path)
            stats["pdf_files"] += 1
        elif lower.endswith(".csv"):
            text = read_csv_file(path)
            stats["csv_files"] += 1
        elif lower.endswith((".json", ".jsonl")):
            text = read_jsonish_file(path)
            stats["json_files"] += 1
        elif lower.endswith((".txt", ".md")):
            text = read_text_file(path)
            stats["text_files"] += 1
        elif lower.endswith(".zip"):
            text = read_zip_file(path)
            stats["zip_files"] += 1
        else:
            continue
        if not text:
            stats["empty_or_failed"] += 1
            continue
        rel = extract_relevant_snippets(text, max_snippets=1200)
        if rel:
            snippets.extend(rel)
            stats["relevant_files"] += 1
            stats["snippets"] += len(rel)
        else:
            stats["irrelevant_files"] += 1
    # de-duplicate while preserving order
    seen = set()
    deduped = []
    for s in snippets:
        if s in seen:
            continue
        seen.add(s)
        deduped.append(s)
    return deduped, dict(stats)


def score_to_risk(score: int) -> str:
    if score <= 33:
        return "Low"
    if score <= 66:
        return "Medium"
    return "High"


def urgency_for_risk(risk: str) -> str:
    return {
        "High": "Urgent (within 1 week)",
        "Medium": "Soon (within 4 weeks)",
        "Low": "Routine",
    }[risk]


def random_age_bracket(rng: random.Random) -> tuple[str, str]:
    bracket = rng.choice(list(AGE_BRACKETS.keys()))
    age = rng.choice(list(AGE_BRACKETS[bracket]))
    return bracket, age


def random_flags(rng: random.Random) -> list[str]:
    n = rng.randint(0, 5)
    return rng.sample(RISK_FACTORS, k=n) if n > 0 else []


def choose_knowledge_fact(rng: random.Random, knowledge_pool: list[str]) -> str:
    if not knowledge_pool:
        return (
            "In paediatric hearing care, persistent symptoms, speech delay, or failed screening "
            "should prompt structured reassessment and timely referral."
        )
    return rng.choice(knowledge_pool)


def medicine_line(med: str) -> str:
    return MEDICINE_GUIDANCE.get(med, f"{med} should be prescribed using weight-appropriate paediatric dosing.")


def render_referral(
    *,
    with_refer_to: bool,
    patient_name: str,
    age: str,
    clinical_summary: str,
    specialist: str | None,
    hospital: str | None,
    urgency: str,
    care_points: list[str],
    medicines: list[str],
    precautions: list[str],
    follow_up: str,
) -> str:
    today = date.today().strftime("%d %B %Y")
    if with_refer_to:
        lines = [
            "PATIENT REFERRAL",
            "─────────────────",
            f"Patient: {patient_name} | Age: {age} | Date: {today}",
            "",
            "CLINICAL SUMMARY:",
            clinical_summary,
            "",
            "REFER TO:",
            f"{specialist or 'ENT Specialist'} — {hospital or 'Appropriate Specialist Center'}",
            f"Urgency: {urgency}",
            "",
            "RECOMMENDED CARE:",
        ]
    else:
        lines = [
            "PATIENT CARE ADVICE",
            "─────────────────",
            f"Patient: {patient_name} | Age: {age} | Date: {today}",
            "",
            "CLINICAL SUMMARY:",
            clinical_summary,
            "",
            "RECOMMENDED CARE:",
        ]
    lines.extend([f"• {p}" for p in care_points[:2]])
    if medicines:
        lines.extend(["", "MEDICINES (if applicable):"])
        lines.extend([f"• {m}" for m in medicines[:2]])
    lines.extend(["", "PRECAUTIONS FOR PARENT:"])
    lines.extend([f"• {p}" for p in precautions[:3]])
    lines.extend(["", "FOLLOW UP:", follow_up, "", "─────────────────", f"Screened via HearTech | {today}"])
    if with_refer_to:
        lines.append("This referral was generated by HearTech screening system.")
    else:
        lines.append("This advice was generated by HearTech screening system.")
    lines.append("Always confirm with a qualified clinician before administration.")
    return "\n".join(lines)


def build_qa_sample(group: str, rng: random.Random, knowledge_pool: list[str]) -> tuple[str, str]:
    age = rng.choice(AGES)
    cond = rng.choice(CONDITIONS)
    risk_factor = rng.choice(RISK_FACTORS)
    med = rng.choice(MEDICINES)
    score = rng.choice(SCORES)
    fact = choose_knowledge_fact(rng, knowledge_pool)

    if group == "symptoms_meaning":
        q = rng.choice([
            f"What does recurrent ear infection mean for a {age} child?",
            f"What are signs of {cond} in infants?",
            f"When should I be worried about {cond} symptoms in a child aged {age}?",
            f"Is reduced response to sound normal for a {age} child?",
        ])
        a = (
            f"In a child aged {age}, {cond} can indicate transient or persistent hearing impact, "
            "especially when episodes are recurrent or associated with speech delay. "
            "Key warning signs include poor response to name, high TV volume, delayed language, "
            "and frequent ear discomfort. "
            f"Clinical note: {fact} "
            "If these signs persist beyond 2-4 weeks, arrange formal hearing assessment (OAE/ABR/tympanometry) "
            "and consider ENT or audiology referral."
        )
    elif group == "medicines":
        q = rng.choice([
            f"What is the best medicine for {cond} in a {age} child?",
            f"What dosage of {med} should be used in children with {cond}?",
            f"How long should {med} be given for ear infection in a {age} child?",
            f"Can I give {med} to a child aged {age} with ear symptoms?",
        ])
        a = (
            f"Medicine choice for {cond} depends on severity, ear exam findings, allergy status, and age. "
            f"A commonly used option is: {medicine_line(med)}. "
            "For severe pain/fever, add supportive analgesia with age-appropriate dosing and hydration. "
            "Reassess clinically within 48-72 hours if symptoms worsen or do not improve. "
            f"{SAFETY_LINE}"
        )
    elif group == "precautions_home_care":
        q = rng.choice([
            f"What precautions should I give parents for {cond}?",
            f"How should parents care for a child with {cond} at home?",
            f"What should parents avoid doing when child has {cond}?",
            f"What warning signs should parents watch for in {cond}?",
        ])
        a = (
            "Advise parents to keep ears dry, avoid inserting cotton buds or oils unless prescribed, "
            "and monitor speech/listening behavior daily. "
            "Use pain/fever control as needed, ensure hydration, and follow medication instructions exactly. "
            "Urgent reassessment is needed for persistent fever, ear discharge, severe pain, "
            "balance issues, or reduced responsiveness to sound."
        )
    elif group == "hearing_risk_factors":
        q = rng.choice([
            f"How serious is {risk_factor} for a child's hearing?",
            f"A child has {risk_factor} — what does this mean for hearing risk?",
            f"Does {risk_factor} always cause hearing loss?",
            f"What is the probability of hearing loss with {risk_factor}?",
        ])
        a = (
            f"{risk_factor} is a clinically relevant risk factor, but it does not always mean permanent hearing loss. "
            "It increases the need for structured surveillance and age-appropriate audiology follow-up. "
            "Interpret risk together with symptoms, screening score, and developmental milestones. "
            "When multiple risk factors are present, referral urgency should be escalated."
        )
    elif group == "audiology_investigations":
        q = rng.choice([
            "When should I refer for ABR testing?",
            "What does a failed OAE test mean?",
            "What is tympanometry and when is it needed?",
            "What is the difference between conductive and sensorineural loss?",
            "At what age can pure tone audiometry be done?",
        ])
        a = (
            "ABR is useful when behavioral testing is unreliable, in infants, or after failed OAE/newborn screening. "
            "A failed OAE suggests reduced cochlear response but needs confirmation with repeat testing and clinical exam. "
            "Tympanometry evaluates middle-ear function, especially with suspected fluid or recurrent infections. "
            "Conductive loss involves sound transmission pathways, while sensorineural loss involves inner ear/auditory nerve."
        )
    elif group == "referral_decisions":
        q = rng.choice([
            "When should I urgently refer a child with hearing concerns?",
            f"This child has score {score} and risk factor {risk_factor} — should I refer urgently?",
            f"Is a score of {score} enough reason to refer to ENT?",
            f"My patient has {cond} — audiologist or ENT first?",
        ])
        risk = score_to_risk(score)
        a = (
            f"A score of {score} indicates {risk.lower()} risk in HearTech context. "
            "Urgent referral is appropriate for high-risk scores, red flags (failed newborn screen, meningitis history, "
            "progressive speech delay), or persistent concerning symptoms. "
            "ENT is preferred for active ear disease/infection patterns; audiology is essential for objective hearing assessment. "
            "Combined referral is often best when both structural and auditory concerns exist."
        )
    elif group == "risk_score_explanation":
        q = rng.choice([
            f"What does a risk score of {score} mean for this child?",
            f"Why did this child score {score} on HearTech screening?",
            f"This child scored medium risk — what should I do next?",
            "What is the difference between medium and high risk in HearTech?",
        ])
        risk = score_to_risk(score)
        a = (
            f"A risk score of {score} falls in the {risk.lower()} risk range. "
            "Scores reflect weighted factors such as risk history, symptom pattern, and screening findings. "
            "Medium risk usually requires planned follow-up and targeted investigations; high risk generally needs "
            "earlier specialist referral and closer monitoring."
        )
    else:  # hearing_milestones
        q = rng.choice([
            f"What should a {age} child be able to hear and say?",
            f"Is it normal that a {age} child does not respond to environmental sounds?",
            f"My {age} patient is not babbling — could this be hearing related?",
            f"What speech milestones should a {age} child have reached?",
        ])
        a = (
            f"At around {age}, expected milestones include consistent response to familiar voices/sounds and age-appropriate "
            "speech-language progression. "
            "Lack of response, absent babbling/word growth, or regression should prompt hearing-focused reassessment. "
            "Use milestone review with OAE/ABR/audiometry selection based on age and cooperation."
        )
    return q, a


def infer_refer_intent(prompt: str) -> bool:
    p = prompt.lower()
    if any(k in p for k in REFERRAL_KEYWORDS):
        return True
    refer_markers = ["refer to", "send to", "ent", "audiologist", "specialist"]
    return any(m in p for m in refer_markers)


def build_referral_prompt(
    rng: random.Random,
    patient_name: str,
    age: str,
    score: int,
    flags: list[str],
    condition: str,
    instruction: str,
    specialist: str | None,
    hospital: str | None,
    with_refer_to: bool,
) -> str:
    flags_text = ", ".join(flags) if flags else "no major clinical flags"
    patterns = []
    patterns.append(
        f"Generate referral for {patient_name}, {age}, risk score {score}, {flags_text}, {instruction}"
    )
    if with_refer_to:
        patterns.append(
            f"Create referral: {patient_name}, {condition}, refer to {specialist} at {hospital}."
        )
        patterns.append(
            f"Referral needed for {patient_name} — {age}, risk level {score_to_risk(score)}, "
            f"send to {specialist} at {hospital}."
        )
    else:
        patterns.append(
            f"Give referral with {rng.choice(MEDICINES)} and precautions for {patient_name}."
        )
        patterns.append(
            f"Generate referral — {patient_name}, prescribe {rng.choice(MEDICINES)}, "
            "give home care advice and parent precautions."
        )
    return rng.choice(patterns)


def build_referral_sample(
    rng: random.Random,
    with_refer_to: bool,
) -> tuple[str, str, str, str]:
    bracket, age = random_age_bracket(rng)
    score = rng.randint(67, 100) if bracket == "0-6 months" and rng.random() < 0.35 else rng.randint(5, 100)
    risk = score_to_risk(score)
    flags = random_flags(rng)
    patient = rng.choice(NAMES)
    specialist = rng.choice(SPECIALISTS) if with_refer_to else None
    hospital = rng.choice(HOSPITALS) if with_refer_to else None
    focus_condition = rng.choice(CONDITIONS)
    med = rng.choice(MEDICINES)

    if with_refer_to:
        instruction = rng.choice([
            f"refer to {specialist} at {hospital}",
            f"send to {specialist} at {hospital} urgently",
            f"refer to {specialist} specialist at {hospital}",
            f"create a referral with medicine and parent precautions, refer to {specialist} at {hospital}",
            f"add urgent specialist follow-up and hearing test planning at {hospital} with {specialist}",
        ])
    else:
        instruction = rng.choice([
            "prescribe amoxicillin, give precautions",
            "give home care advice and medicines",
            "what precautions and medicines for this child",
            "amoxicillin 250mg with follow-up review in 2 weeks if no improvement",
            "supportive care guidance for parents at home",
        ])

    user_prompt = build_referral_prompt(
        rng=rng,
        patient_name=patient,
        age=age,
        score=score,
        flags=flags,
        condition=focus_condition,
        instruction=instruction,
        specialist=specialist,
        hospital=hospital,
        with_refer_to=with_refer_to,
    )

    # Rule 1: include REFER TO only when referral intent clearly includes referral markers.
    should_include_refer = with_refer_to and infer_refer_intent(user_prompt)
    summary = (
        f"Child screened with HearTech has {risk.lower()} hearing risk (score {score}) "
        f"with concerns related to {focus_condition}. "
        "Early targeted management is advised to reduce progression risk."
    )
    if flags:
        summary += f" Key risk factors include {', '.join(flags[:3])}."

    care_points = [
        "Arrange hearing-focused clinical review and monitor symptom progression.",
        "Maintain adherence to prescribed treatment and hydration/pain control.",
        "Document speech and listening changes over the next 2 weeks.",
        "Escalate early if worsening fever, discharge, severe pain, or poor sound response.",
    ]
    rng.shuffle(care_points)

    medicines = [
        medicine_line(med),
        medicine_line(rng.choice(MEDICINES)),
    ]
    precautions = [
        "Keep ears dry and avoid inserting objects/cotton buds into the ear canal.",
        "Limit high-volume noise exposure and monitor response to conversation at home.",
        "Return urgently for persistent fever, discharge, severe pain, or reduced responsiveness.",
        "Ensure medicine is measured accurately by weight/age and completed as advised.",
    ]
    rng.shuffle(precautions)

    follow_up = (
        "Reassess within 48-72 hours if symptoms do not improve; complete hearing evaluation "
        f"within {'1 week' if risk == 'High' else ('4 weeks' if risk == 'Medium' else '2-3 months')}."
    )
    urgency = urgency_for_risk(risk)

    assistant_doc = render_referral(
        with_refer_to=should_include_refer,
        patient_name=patient,
        age=age,
        clinical_summary=summary,
        specialist=specialist,
        hospital=hospital,
        urgency=urgency,
        care_points=care_points,
        medicines=medicines,
        precautions=precautions,
        follow_up=follow_up,
    )
    return user_prompt, assistant_doc, risk, bracket


def split_dataset(records: list[dict[str, str]]) -> tuple[list[dict[str, str]], list[dict[str, str]], list[dict[str, str]]]:
    total = len(records)
    train_end = int(total * 0.8)
    valid_end = int(total * 0.9)
    return records[:train_end], records[train_end:valid_end], records[valid_end:]


def write_jsonl(path: Path, rows: Iterable[dict[str, str]]) -> int:
    path.parent.mkdir(parents=True, exist_ok=True)
    count = 0
    with path.open("w", encoding="utf-8") as f:
        for row in rows:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")
            count += 1
    return count


def build_dataset(dataset_dir: Path, out_dir: Path, seed: int) -> None:
    rng = random.Random(seed)
    knowledge_pool, ingest_stats = load_knowledge_pool(dataset_dir)

    qa_records: list[dict[str, str]] = []
    referral_records: list[dict[str, str]] = []
    referral_with_refer = 0
    referral_without_refer = 0
    risk_dist: Counter[str] = Counter()
    age_dist: Counter[str] = Counter()

    # Q&A generation (20k)
    for group, count in QA_GROUP_COUNTS.items():
        for _ in range(count):
            q, a = build_qa_sample(group, rng, knowledge_pool)
            qa_records.append(build_record(q, a))

    # Referral generation (20k total, strict 50/50 target)
    for _ in range(10_000):
        q, a, risk, bracket = build_referral_sample(rng, with_refer_to=True)
        referral_records.append(build_record(q, a))
        if "REFER TO:" in a:
            referral_with_refer += 1
        else:
            referral_without_refer += 1
        risk_dist[risk] += 1
        age_dist[bracket] += 1

    for _ in range(10_000):
        q, a, risk, bracket = build_referral_sample(rng, with_refer_to=False)
        referral_records.append(build_record(q, a))
        if "REFER TO:" in a:
            referral_with_refer += 1
        else:
            referral_without_refer += 1
        risk_dist[risk] += 1
        age_dist[bracket] += 1

    all_rows = qa_records + referral_records
    rng.shuffle(all_rows)

    train_rows, valid_rows, test_rows = split_dataset(all_rows)
    train_path = out_dir / "train.jsonl"
    valid_path = out_dir / "valid.jsonl"
    test_path = out_dir / "test.jsonl"

    n_train = write_jsonl(train_path, train_rows)
    n_valid = write_jsonl(valid_path, valid_rows)
    n_test = write_jsonl(test_path, test_rows)

    total = len(all_rows)
    print("\n================ HEARTECH DATASET V3 SUMMARY ================")
    print(f"Total samples: {total}")
    print(f"Q&A samples: {len(qa_records)}")
    print(f"Referral samples: {len(referral_records)}")
    print(f"Referral with REFER TO: {referral_with_refer}")
    print(f"Referral without REFER TO: {referral_without_refer}")
    print("\nRisk level distribution (referral samples):")
    for k in ("Low", "Medium", "High"):
        print(f"  {k}: {risk_dist[k]}")
    print("\nAge bracket distribution (referral samples):")
    for bracket in AGE_BRACKETS.keys():
        print(f"  {bracket}: {age_dist[bracket]}")
    print("\nRaw ingest stats:")
    for k in sorted(ingest_stats):
        print(f"  {k}: {ingest_stats[k]}")
    print(f"  knowledge_pool_size: {len(knowledge_pool)}")
    print("\nSaved splits:")
    print(f"  train.jsonl: {n_train}")
    print(f"  valid.jsonl: {n_valid}")
    print(f"  test.jsonl: {n_test}")
    print("=============================================================\n")


def parse_args() -> argparse.Namespace:
    default_project_root = Path(__file__).resolve().parents[3]
    parser = argparse.ArgumentParser(description="Build HearTech dataset v3")
    parser.add_argument(
        "--dataset-dir",
        type=Path,
        default=default_project_root / "dataset",
        help="Path to raw datasets folder (default: ~/HEARTECH/dataset in this repo).",
    )
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "heartech_dataset_v3",
        help="Output directory for train/valid/test jsonl.",
    )
    parser.add_argument("--seed", type=int, default=42, help="Random seed.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if not args.dataset_dir.exists():
        raise FileNotFoundError(f"Raw dataset directory not found: {args.dataset_dir}")
    build_dataset(args.dataset_dir, args.out_dir, args.seed)


if __name__ == "__main__":
    main()
