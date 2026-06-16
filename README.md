# HearTech

**Early Hearing, Better Futures**

A Final Year Project mobile application for early childhood hearing risk screening and coordinated care — connecting **healthcare workers**, **parents**, and **teachers** around one shared child profile.

| | |
|---|---|
| **Institution** | University of Central Punjab |
| **Group** | F25CS070 |
| **Supervisor** | Mr. Ihtisham-Ul-Haq |
| **Platform** | Flutter (iOS & Android) |
| **Version** | 1.0.0 |

---

## Poster headline (copy-paste)

> **HearTech** helps detect hearing risk early in children aged 0–12 by linking clinics, homes, and classrooms in one secure app — with AI-assisted referrals and speech screening tools.

---

## The problem

- Hearing loss in young children is often **missed or diagnosed late**.
- Parents and teachers may notice speech or listening issues, but information stays **siloed**.
- Healthcare workers need better tools to **screen**, **document**, and **refer** — without replacing formal audiology.

## Our solution

HearTech is a **screening and decision-support platform** (not a diagnostic device). It:

1. Runs **age-bracketed hearing-risk questionnaires** (0–12 years).
2. Calculates a **risk score** (Low / Medium / High) with role-aware weighting.
3. Links **HCW → Parent → Teacher** on a single Firestore child profile.
4. Supports **AI Clinical Assistant** for clinical Q&A and referral letter drafting.
5. Offers **home and classroom speech exercises** (Show and Tell, Ling Six).
6. Sends **smart reminders** so follow-ups are not forgotten.

---

## Who uses HearTech?

```text
┌─────────────────┐     handover code      ┌─────────────────┐
│ Healthcare      │ ─────────────────────► │ Parent          │
│ Worker (HCW)    │                        │                 │
│                 │     email invite       │                 │
│ • Screen        │ ◄───────────────────── │ • Claim child   │
│ • Refer         │                        │ • Home screening│
│ • Clinical AI   │                        │ • Speech games  │
└────────┬────────┘                        └────────┬────────┘
         │                                          │
         │              shared child profile       │
         └──────────────────┬───────────────────────┘
                            │
                   ┌────────▼────────┐
                   │ Teacher         │
                   │                 │
                   │ • Observations  │
                   │ • Speech games  │
                   │ • Shared refs   │
                   └─────────────────┘
```

### Healthcare Worker (HCW)

| Feature | Description |
|---------|-------------|
| **New Screening** | 7-step flow: child info → age questionnaire → clinical note → risk result → profile creation |
| **Patient list** | All children linked to the HCW |
| **Child profile** | Overview, screenings history, referrals, notes, speech logs |
| **Clinical Assistant** | AI chat for clinical questions + referral letter generation/editing |
| **Referral workflow** | Draft → review → finalize → share with parent (PDF + letter text) |
| **Handover code** | Secure 6-character code so parents claim the child profile |

### Parent

| Feature | Description |
|---------|-------------|
| **Claim profile** | Enter HCW handover code to link a child |
| **Home screening** | Same questionnaire logic with plain-language results |
| **Monitor progress** | View screenings, referrals, and HCW notes marked public |
| **Speech games** | Show and Tell + Ling Six hearing exercises |
| **Invite teacher** | Email invite for children aged 3+ |
| **Referral sharing** | Parent controls whether finalized referrals are visible to the teacher |

### Teacher

| Feature | Description |
|---------|-------------|
| **Classroom observations** | Frequency-based questionnaire on listening/behaviour |
| **Limited profile view** | Risk label only (no numeric score) — privacy by design |
| **Speech sessions** | Run Show and Tell / Ling Six for linked children |
| **Shared referrals** | Read-only access to referrals the **parent** chose to share |

---

## How it works (3 steps)

**Step 1 — Screen**  
A healthcare worker runs an age-appropriate questionnaire. If risk is elevated, a child profile is created and a handover code is issued.

**Step 2 — Link**  
The parent installs HearTech, enters the code, and gains access to the child's record. They can run home screenings and speech exercises.

**Step 3 — Collaborate**  
The parent may invite the child's teacher. Observations, speech logs, and (optionally) referrals build a complete picture for follow-up with ENT/audiology services.

---

## Key features at a glance

| Area | What it does |
|------|----------------|
| **Risk scoring** | Weighted answers + clinical flags → score 0–100 → Low / Medium / High |
| **Age brackets** | 5 bands from 0–6 months up to 6–12 years |
| **Clinical Assistant** | Fine-tuned medical AI (local MLX) + cloud fallback; edits referral letters in chat |
| **Referral lifecycle** | Auto-save drafts → HCW finalize → parent notified → optional teacher share |
| **Show and Tell** | Image prompts + voice recording + Whisper speech analysis |
| **Ling Six test** | Six critical frequencies (m, ah, oo, ee, sh, s) with Pass / Watch / Refer |
| **Notifications** | Typed alerts (e.g. PAR-08 referral ready, TCH-07 observation due) with deep links |
| **Offline cache** | Hive stores recent data when connectivity is poor |

---

## System architecture

```text
┌──────────────────────────────────────────────────────────────┐
│                    Flutter App (iOS / Android)                │
│  Riverpod · GoRouter · Firebase Auth · Hive offline cache     │
└────────────────────────────┬─────────────────────────────────┘
                             │
         ┌───────────────────┼───────────────────┐
         ▼                   ▼                   ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│ Firebase        │ │ FastAPI Backend │ │ Cloudinary      │
│ Auth + Firestore│ │ (Python)        │ │ Media + PDFs    │
└─────────────────┘ └────────┬────────┘ └─────────────────┘
                               │
              ┌────────────────┼────────────────┐
              ▼                ▼                ▼
       Risk scoring      Referral AI        Speech AI
       (rule engine)     (MLX + Gemini)     (Whisper ASR)
```

### Backend services (`backend/`)

| Service | Role |
|---------|------|
| **FastAPI** | REST API: risk score, referral chat, PDF export, speech analysis, invites, notifications |
| **Referral AI** | Custom fine-tuned model (`heartech_medical_model_v5_96000`) with validation guardrails |
| **Whisper** | Speech-to-text for Show and Tell pronunciation feedback |
| **APScheduler** | Cron jobs for follow-up reminders (screening gaps, invite expiry, etc.) |
| **OneSignal** | Push notifications to HCW / parent / teacher devices |

### Data stored in Firestore

| Collection | Contents |
|------------|----------|
| `users/{uid}` | Role, profile, notification preferences |
| `children/{childId}` | Child demographics, risk level, linked HCW/parent/teachers |
| `.../screenings/` | Questionnaire answers and scores |
| `.../referrals/` | AI referral letters (draft / finalized), PDF URLs |
| `.../notes/` | HCW clinical notes with visibility flags |
| `.../speechLogs/` | Show and Tell and Ling Six session results |
| `.../teacherObservations/` | Classroom observation records |
| `invites/` | Parent → teacher invite lifecycle |
| `notifications/` | In-app notification inbox per user |

Access is enforced with **Firestore security rules** — each role sees only what they are allowed to see.

---

## AI and innovation highlights

**For poster / viva talking points:**

1. **Domain-specific referral model** — Fine-tuned on paediatric hearing / ENT datasets (MedQuAD, ChatDoctor, NHS/WHO guidelines, custom referral corpus), not a generic chatbot.
2. **Guardrailed runtime** — Intent routing, output validators, and fallbacks reduce hallucinations and template leaks in clinical text.
3. **Multi-tier generation** — Local MLX inference → cloud retry → rule-based assembler for reliability on Apple Silicon dev hardware.
4. **Speech pipeline** — Record → Whisper transcript → phoneme comparison → child-friendly feedback.
5. **Three-stakeholder design** — Rare in student projects: true role separation with parent-controlled teacher visibility on referrals.

---

## Tech stack

| Layer | Technology |
|-------|------------|
| Mobile app | Flutter 3, Dart, Riverpod, GoRouter |
| Backend API | Python 3, FastAPI, APScheduler |
| Authentication | Firebase Auth (email + Google Sign-In) |
| Database | Cloud Firestore |
| Referral AI | MLX-LM, LoRA adapters, optional Google Gemini |
| Speech AI | OpenAI Whisper, phonemizer, rapidfuzz |
| File storage | Cloudinary |
| Push notifications | OneSignal |
| PDF generation | ReportLab (backend) |
| Local cache | Hive |
| Hosting | Google Cloud Run (backend), Firebase (heartech-fyp) |

---

## Demo script (for exhibition / poster live demo)

**Suggested 5-minute walkthrough:**

1. **Login as HCW** → Start **New Screening** → complete questionnaire → show **High Risk** result.
2. **Create child profile** → copy **handover code** shown on profile.
3. **Clinical Assistant** → ask a clinical question → generate referral → show draft in **Referrals** tab.
4. **Finalize referral** → explain parent receives notification (PAR-08).
5. **Login as Parent** → **Claim profile** with code → open **Referrals** tab → toggle **Share with teacher**.
6. *(Optional)* **Show and Tell** or **Ling Six** speech game on a linked child.

---

## Project structure

```text
HEARTECH/
├── lib/                    # Flutter app source
│   ├── features/           # auth, screening, referral, speech, dashboard, …
│   ├── services/           # Firestore, FastAPI, Cloudinary, notifications
│   └── shared/models/      # Data models
├── backend/                # FastAPI + AI runtime
│   ├── routers/            # API endpoints
│   ├── services/           # Referral AI, notifications
│   └── heartech_ai/        # Model runtime, training scripts, datasets
├── dataset/                # Training data (MedQuAD, NHS PDFs, etc.)
├── firestore.rules         # Security rules
└── android/ ios/           # Native platform configs
```

---

## Development team

| Name | Role |
|------|------|
| **Noor Hassan** | Frontend Developer & Testing |
| **Haroon Ashar** | AI & Backend Developer |
| **Abdul Mateen** | UI/UX & Documentation |

**Supervised by:** Mr. Ihtisham-Ul-Haq  
**University of Central Punjab — Group F25CS070**

---

## Disclaimer

HearTech is **NOT** a medical diagnostic tool. Risk assessments are based on observational screening data and are intended to **guide — not replace** — clinical evaluation. Always consult a qualified audiologist, ENT specialist, or paediatrician for formal hearing assessment.

---

## Data and privacy

- Only the minimum data needed for screening is collected.
- Child records are visible only to the linked HCW, parent, and invited teacher.
- Role-based Firestore rules restrict read/write per user type.
- Referral teacher visibility is controlled by the **parent**, not the HCW.

---

## Getting started (developers)

### Prerequisites

- Flutter SDK ^3.10
- Python 3.11+ with `backend/requirements.txt`
- Firebase project (`heartech-fyp`) with Auth + Firestore enabled
- (Optional) Cloudinary, OneSignal, Gemini API keys for full feature set

### Run the Flutter app

```bash
flutter pub get
flutter run
```

### Run the backend

```bash
cd backend
python -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Update `AppConstants.fastApiBaseUrl` in `lib/core/constants/app_constants.dart` if testing on a physical device (use your machine's LAN IP instead of `127.0.0.1`).

### Deploy Firestore rules

```bash
firebase deploy --only firestore:rules,firestore:indexes --project heartech-fyp
```

---

## Poster layout suggestion

**Visual design (colors, fonts, logo, cards, role accents):** see [`DESIGN_GUIDE.md`](DESIGN_GUIDE.md).

When designing your physical poster, consider these **sections as columns or blocks**:

| Block | Content from this README |
|-------|--------------------------|
| **Header** | Logo + tagline + team names |
| **Problem → Solution** | Two short paragraphs + 3-step diagram |
| **Features** | Role table (HCW / Parent / Teacher) |
| **Architecture** | System diagram + tech stack table |
| **Innovation** | AI highlights bullet list |
| **Screenshots** | 4–6 app screenshots (HCW screening, Clinical Assistant, parent profile, speech game) |
| **QR code** | Link to demo video or GitHub repo |
| **Footer** | Disclaimer + UCP + supervisor name |

---

## License and copyright

© 2025 HearTech — University of Central Punjab. Final Year Project, Group F25CS070.

---

*This README is written for project documentation, exhibition posters, and viva preparation. For in-app product text, see the About screen in the application.*
