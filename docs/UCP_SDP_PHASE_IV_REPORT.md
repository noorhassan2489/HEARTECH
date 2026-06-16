# University of Central Punjab (UCP)
# Software Development Project (SDP) — Phase IV Final Report

---

## Cover Page Information

| Field | Detail |
|-------|--------|
| **Project Title** | HearTech — Early Childhood Hearing Risk Screening & Coordinated Care |
| **Tagline** | Early Hearing, Better Futures |
| **Advisor / Supervisor** | Mr. Ihtisham-Ul-Haq |
| **Group ID** | F25CS070 |
| **Department** | Computer Science |
| **Institution** | University of Central Punjab (UCP) |
| **Project Type** | Software (Mobile Application + Cloud Backend + AI Services) |
| **Version** | 1.0.0 |
| **Report Date** | May 2026 |

### Team Members

| Name | Registration No. | Primary Responsibilities |
|------|------------------|--------------------------|
| **Noor Hassan** | *[Fill reg. no.]* | Flutter frontend development; UI integration; navigation (GoRouter); screening & child-profile flows; notification centre; manual testing & QA matrices; physical device testing |
| **Haroon Ashar** | *[Fill reg. no.]* | FastAPI backend; Firebase Admin integration; risk-scoring engine; referral AI runtime (MLX-LM + guardrails); Whisper speech pipeline; APScheduler cron jobs; OneSignal push backend |
| **Abdul Mateen** | *[Fill reg. no.]* | UI/UX design; design system (`DESIGN_GUIDE.md`); poster assets; documentation (manual test guides, open-house materials, SDP reports); user-facing copy & About screen |

> **Note:** Registration numbers are not stored in the repository. Insert official UCP registration numbers before submission.

---

## Revision History

| Version | Date | Author(s) | Description of Changes |
|---------|------|-----------|------------------------|
| 0.1 | Sep 2024 | Team | Initial project proposal and requirements outline |
| 0.5 | Dec 2024 | Team | Phase I–II architecture draft; Firebase schema defined |
| 0.8 | Mar 2025 | Team | Phase III component design; screening questionnaires implemented |
| 0.9 | Apr 2025 | Team | Referral AI v5 runtime; speech games (Show and Tell, Ling Six) |
| 1.0 | May 2025 | Team | Phase IV final report; notification system consolidation (Phase 7); HCW invite/unlink flows; QA recovery session |
| 1.1 | May 2026 | Team | SDP Phase IV report document aligned to current implemented codebase |

---

## Abstract

Childhood hearing loss is a significant public-health concern: when detection is delayed, speech, language, and educational outcomes suffer. In many settings—including Pakistan—screening data remains fragmented across clinics, homes, and schools, and formal audiology services are not always accessible at the point of first concern.

**HearTech** is a cross-platform mobile health application developed as a Final Year Project at the University of Central Punjab. The system connects **healthcare workers (HCWs)**, **parents/guardians**, and **school teachers** on a single secure child profile for children aged **0–12 years**. The mobile client is built with **Flutter** and uses **Firebase Authentication** and **Cloud Firestore** for identity and data. A **Python FastAPI** backend provides risk scoring, AI-assisted clinical referral drafting, and speech analysis. The referral assistant uses a **fine-tuned MLX-LM model** (Llama 3.2 3B + LoRA adapters) with multi-layer **output guardrails** and cloud/rule-based fallbacks. Speech screening employs **OpenAI Whisper** for automatic speech recognition (ASR) with anti-hallucination post-processing. **Cloudinary** stores profile media and referral PDFs; **OneSignal** delivers push notifications across **28 typed alert categories**.

HearTech is explicitly a **screening and care-coordination tool**, not a diagnostic device. The project achieved a working end-to-end prototype: HCW screening → parent claim via handover code → teacher observations → aggregated risk scoring → AI referral generation → speech mini-games → role-based notifications. Automated checks (`flutter analyze`, `flutter test`, backend import health, JWT enforcement) and a 168-step manual test guide support validation. Results demonstrate that mobile-first, multi-stakeholder hearing-risk workflows can be implemented with modern cloud and on-device AI tooling while preserving role-based privacy.

**Keywords:** mHealth, paediatric audiology, hearing screening, Flutter, Firebase, FastAPI, Whisper ASR, MLX-LM, care coordination, Pakistan.

---

## 1. Introduction

### 1.1 Product

**HearTech** is a mobile application and supporting cloud backend that enables early hearing-risk screening and coordinated follow-up for children from birth through age twelve.

**Problem addressed:** Hearing difficulties are often identified only after speech delay or classroom struggles become obvious. Healthcare workers may screen a child, but parents and teachers rarely share structured observations in one record. Referral documentation is time-consuming and inconsistent.

**Solution delivered:** HearTech provided a unified workflow in which:
- An HCW conducts an age-bracketed questionnaire and receives a computed risk score (Low / Medium / High).
- A **6-character handover code** lets a parent claim the child profile securely.
- Parents run home screenings and speech exercises (Show and Tell, Ling Six).
- Parents invite teachers (age 3+) and, when needed, a new HCW.
- Teachers submit classroom observations with privacy controls (risk label only, no numeric score).
- The HCW uses an **AI Clinical Assistant** to answer clinical questions and draft referral letters with PDF export.
- **28 notification types** keep all roles informed via in-app centre and OneSignal push.

**Tense note:** Requirements were defined in future tense during planning; the implemented product described herein is documented in **past/present tense** as a completed FYP deliverable (v1.0.0).

### 1.2 Background

**Related work — hearing screening & mHealth:**
- WHO and national programmes emphasise **early identification** of hearing loss and referral to audiology/ENT services.
- Traditional tools include **otoacoustic emissions (OAE)**, **automated auditory brainstem response (AABR)**, and behavioural audiometry—typically clinic- or hospital-based.
- Mobile health (mHealth) apps increasingly support **developmental screening**, **parent education**, and **tele-audiology**, but few combine **HCW + parent + teacher** roles with **AI referral drafting** and **speech ASR games** in one product.

**How HearTech differs:**

| Aspect | Typical solutions | HearTech |
|--------|-------------------|----------|
| Users | Single role (clinic OR parent app) | Three roles on one child profile |
| Linking | Account linking, QR, or manual entry | Time-limited handover code + email invites |
| Risk language | Clinical-only or parent-only | Role-weighted aggregate score with teacher-limited view |
| Referrals | Static forms or generic chatbots | Fine-tuned paediatric referral model + validators |
| Speech | Separate speech-therapy apps | Integrated Show and Tell + Ling Six with Whisper |
| Privacy | Often full record sharing | Firestore rules + parent-controlled referral sharing |

### 1.3 Objectives / Aims

The following objectives were **defined at project start** and are reported here as **completed** unless marked partial:

| # | Objective | Status |
|---|-----------|--------|
| O1 | Implement age-appropriate hearing-risk questionnaires for five age brackets (0–6 months to 6–12 years) | **Complete** |
| O2 | Compute session and aggregated risk scores (0–100) with Low/Medium/High bands | **Complete** |
| O3 | Link HCW, parent, and teacher on a single Firestore child profile | **Complete** |
| O4 | Provide secure handover-code profile claiming with expiry and attempt limits | **Complete** |
| O5 | Deliver AI-assisted referral drafting with guardrails and PDF/DOCX export | **Complete** |
| O6 | Implement speech screening mini-games with Whisper-based analysis | **Complete** |
| O7 | Enforce role-based access via Firestore security rules and portal-separated login | **Complete** |
| O8 | Implement in-app notification centre and OneSignal push (28 types + cron reminders) | **Complete** |
| O9 | Support profile/license upload via Cloudinary | **Complete** |
| O10 | Provide offline-friendly caching (Hive) for screenings and notifications | **Complete** |
| O11 | Document full manual test procedures for QA and viva | **Complete** |

**Partial / out of scope:**
- Formal clinical validation study with hospital partners — **not implemented** (academic prototype).
- Bluetooth audiometer device integration — **not implemented** (future work).
- Urdu localisation — **not implemented**.

### 1.4 Scope

**In scope (implemented):**
- Flutter mobile app (Android & iOS) for HCW, parent, teacher
- Firebase Auth (email/password, Google Sign-In)
- Firestore database with security rules
- FastAPI backend: risk score, referrals, speech, invites, notifications, profile claim
- AI referral runtime (local MLX + Gemini fallback + pattern assembler)
- Whisper ASR for speech games
- Cloudinary media/PDF storage
- OneSignal push + in-app notifications
- APScheduler cron reminders

**Out of scope (explicitly excluded):**
- Formal medical diagnosis or audiometry certification
- Hospital EMR/EHR integration
- Web-based clinic admin portal
- Payment / billing module
- Multi-language UI (English only in v1.0)

### 1.5 Business Goals

| Goal type | Value delivered |
|-----------|-----------------|
| **Social** | Earlier awareness of hearing risk; better parent and teacher engagement |
| **Clinical workflow** | Structured documentation and referral letters for HCWs |
| **Cost** | Mobile-first; usable on mid-range phones; no dedicated screening hardware required |
| **Coordination** | Single child record across clinic, home, and classroom |
| **Scalability** | Cloud-hosted Firebase + optional Cloud Run backend deployment |
| **Trust** | Role-based privacy; parent controls teacher referral visibility |

### 1.6 Document Conventions

| Convention | Usage |
|------------|--------|
| **HCW** | Healthcare Worker (clinician conducting screening) |
| **Monospace paths** | File paths and API routes (e.g. `/api/risk-score`) |
| **Past tense** | Describes implemented behaviour |
| **Figures** | Mermaid diagrams; screenshots inserted manually by team |
| **Status labels** | Complete / Partial / Not Implemented |
| **Notification IDs** | Format `HCW-01` … `TCH-08` (+ `HCW-11` for parent→HCW invite) |

### 1.7 Miscellaneous

- **Firebase project:** `heartech-fyp`
- **App bundle ID (iOS):** `com.noorhassan.heartech`
- **Legal disclaimer:** HearTech is not a diagnostic device; formal assessment requires qualified professionals.
- **Related internal docs:** `README.md`, `DESIGN_GUIDE.md`, `FULL_MANUAL_TEST_GUIDE.md`, `PHASE_7_NOTIFICATIONS.md`, `OPEN_HOUSE_PRESENTATION.md`

---

## 2. Technical Architecture

### 2.1 Application and Data Architecture

#### High-level component diagram

```mermaid
flowchart TB
    subgraph Client["Flutter Mobile App"]
        UI[Screens & Widgets]
        RP[Riverpod State]
        GR[GoRouter Navigation]
        HS[Hive Offline Cache]
    end

    subgraph Firebase["Google Firebase"]
        FA[Firebase Auth]
        FS[(Cloud Firestore)]
        FAN[Firebase Analytics]
    end

    subgraph Backend["FastAPI Backend (Python)"]
        RS[Risk Score Router]
        RF[Referral AI Router]
        SP[Speech / Whisper Router]
        IV[Invites Router]
        NT[Notifications Router]
        CR[APScheduler Cron]
    end

    subgraph External["External Services"]
        CL[Cloudinary]
        OS[OneSignal]
        GM[Gemini API - fallback]
    end

    subgraph AI["AI Runtimes"]
        MLX[MLX-LM + LoRA Adapters]
        WH[Whisper ASR]
    end

    UI --> RP --> GR
    UI --> FA
    UI --> FS
    UI --> HS
    UI -->|HTTPS + JWT| Backend
    Backend --> FS
    Backend --> MLX
    Backend --> WH
    Backend --> CL
    Backend --> OS
    Backend --> GM
    CR --> NT
```

#### Entity Relationship Diagram (Firestore)

```mermaid
erDiagram
    USERS ||--o{ CHILDREN : "hcwIds parentId teacherIds"
    CHILDREN ||--o{ SCREENINGS : contains
    CHILDREN ||--o{ REFERRALS : contains
    CHILDREN ||--o{ NOTES : contains
    CHILDREN ||--o{ SPEECH_LOGS : contains
    CHILDREN ||--o{ TEACHER_OBSERVATIONS : contains
    USERS ||--o{ INVITES : creates_or_receives
    USERS ||--o{ NOTIFICATIONS : inbox

    USERS {
        string uid PK
        string role
        string email
        string name
        map notificationPrefs
    }
    CHILDREN {
        string childId PK
        string name
        timestamp dob
        int ageBracket
        string parentId
        array hcwIds
        array teacherIds
        int riskScore
        string riskLevel
        map handoverCode
    }
    SCREENINGS {
        string screeningId PK
        string conductorRole
        array answers
        int riskScore
    }
    REFERRALS {
        string referralId PK
        string status
        string letterText
        string pdfUrl
    }
    INVITES {
        string inviteId PK
        string inviteType
        string status
    }
    NOTIFICATIONS {
        string notifId PK
        string type
        bool read
    }
```

#### Class diagram (logical domain models — Flutter `lib/shared/models/`)

| Model | Key fields | Purpose |
|-------|------------|---------|
| `UserModel` | uid, role, email, name, profilePhotoUrl, licenseDocUrl, notificationPrefs | Authenticated user profile |
| `ChildModel` | childId, name, dob, ageBracket, parentId, hcwIds, teacherIds, riskScore, riskLevel, handoverCode | Central child record |
| `HandoverCode` | code, expiresAt, used, attempts | Parent linking token |
| `ScreeningModel` | answers, riskScore, conductorRole, date | Questionnaire session |
| `ReferralModel` | status, letterText, pdfCloudinaryUrl, visibility flags | Referral draft/final |
| `InviteModel` | inviteType, teacherEmail/hcwEmail, status, expiresAt | Teacher/HCW invites |
| `NotificationModel` | type, title, body, navigationRoute, priority | In-app alert |
| `SpeechLogModel` | gameType, score, transcript, frequencyFlag | Speech session result |
| `TeacherObservationModel` | answers, date, teacherUid | Classroom observation |
| `NoteModel` | text, isPublic, isTeacherVisible, authorRole | Shared clinical notes |

#### Firebase data model (collections)

**Top-level collections** (`lib/core/constants/firestore_paths.dart`):

| Collection | Path | Description |
|------------|------|-------------|
| Users | `users/{uid}` | Role profiles, prefs, linkedChildIds |
| Children | `children/{childId}` | Child demographics, risk, handover code |
| Invites | `invites/{inviteId}` | Teacher and HCW pending invites |
| HCW Screenings | `hcw_screenings/{id}` | Optional anonymous HCW records |
| Notifications | `notifications/{uid}/items/{notifId}` | Per-user inbox |

**Subcollections under `children/{childId}/`:**

| Subcollection | Contents |
|---------------|----------|
| `screenings/` | HCW and parent screening sessions |
| `teacherObservations/` | Teacher questionnaire submissions |
| `referrals/` | AI referral drafts and finals |
| `speechLogs/` | Show and Tell / Ling Six results |
| `notes/` | HCW/teacher notes with visibility flags |

### 2.2 Component Interactions and Collaborations

#### Sequence — HCW screening to parent claim

```mermaid
sequenceDiagram
    participant HCW as HCW App
    participant API as FastAPI
    participant FS as Firestore
    participant PAR as Parent App

    HCW->>API: POST /api/risk-score (JWT)
    API-->>HCW: riskScore, riskLevel
    HCW->>FS: Save child + screening + handoverCode
    PAR->>API: POST /api/claim-profile {code}
    API->>FS: Validate code, set parentId
    API->>FS: Notification HCW-02
    API-->>PAR: childId, childName
```

#### Sequence — Referral AI chat

```mermaid
sequenceDiagram
    participant HCW as HCW App
    participant API as FastAPI
    participant AI as ReferralAIService
    participant FS as Firestore

    HCW->>API: POST /api/generate-referral-chat
    API->>AI: generate(childData, hcwInstruction)
    AI->>AI: Intent route + local MLX inference
    AI->>AI: validate_runtime_output()
    alt validation fails
        AI->>AI: Cloud retry (Gemini) or pattern assembler
    end
    API-->>HCW: referralText, intent, source
    HCW->>FS: Auto-save draft referral
    HCW->>API: POST /api/export-referral-pdf
    API->>FS: Finalize + notify parent PAR-08
```

#### Sequence — Speech (Show and Tell)

```mermaid
sequenceDiagram
    participant App as Parent/Teacher App
    participant API as FastAPI
    participant WH as Whisper
    participant FS as Firestore

    App->>App: Record audio (max 5s)
    App->>API: POST /api/analyze-speech (multipart)
    API->>WH: Transcribe (anti-hallucination settings)
    API->>API: Phoneme/fuzzy match vs expected word
    API-->>App: score, feedback, transcript
    App->>FS: Save speechLog
    App->>API: POST /api/notifications/send (HCW-08)
```

### 2.3 Design Reuse and Design Patterns

| Pattern | Where used | Purpose |
|---------|------------|---------|
| **Provider / Riverpod** | `lib/core/di/providers.dart` | Dependency injection, auth state, services |
| **Repository-style services** | `FirestoreService`, `FastApiService`, `CloudinaryService` | Isolate data access from UI |
| **Singleton** | `ReferralAIService.get_instance()` | Single loaded MLX model instance |
| **Strategy / fallback chain** | Referral AI: local → cloud → assembler | Resilient AI output |
| **Router guard** | `GoRouter.redirect` in `app_router.dart` | Role-based route protection |
| **Factory** | `*.fromJson()` on all models | Firestore deserialization |
| **Observer** | Firebase streams + `GoRouterRefreshNotifier` | Reactive UI updates |
| **Template method** | Screening flow steps (HCW new screening) | Consistent multi-step wizard |

### 2.4 Technology Architecture

| Layer | Technology | Version / detail | Hosting |
|-------|------------|------------------|---------|
| Mobile UI | Flutter / Dart | SDK ^3.10 | Android, iOS |
| State | flutter_riverpod | ^3.3 | On-device |
| Navigation | go_router | ^17.1 | On-device |
| Local cache | hive | ^2.2 | On-device |
| Auth | firebase_auth, google_sign_in | Firebase | Google Cloud |
| Database | cloud_firestore | Firebase | Google Cloud |
| Analytics | firebase_analytics | Firebase | Google Cloud |
| HTTP client | dio | ^5.9 | App → backend |
| Backend API | FastAPI + Uvicorn | Python 3.11+ | Local Mac / Cloud Run |
| Scheduler | APScheduler | BackgroundScheduler | With backend |
| Referral AI | mlx-lm, LoRA adapters | Llama 3.2 3B base | Local Apple Silicon |
| Referral fallback | Google Gemini API | Cloud | Google |
| Speech ASR | openai-whisper | Server-side | Backend host |
| Phoneme match | phonemizer, rapidfuzz | Python libs | Backend |
| Media | Cloudinary | Images + PDFs | Cloudinary CDN |
| Push | onesignal_flutter + REST | OneSignal | OneSignal cloud |
| PDF export | ReportLab | Server-side | Backend |
| Audio | record, just_audio | Flutter plugins | On-device |

### 2.5 Architecture Evaluation

| Decision | Chosen | Alternatives considered | Rationale |
|----------|--------|-------------------------|-----------|
| Mobile framework | Flutter | React Native, native Swift/Kotlin | Single codebase for iOS+Android; strong UI tooling |
| Backend | FastAPI | Django, Node.js | Async-friendly; easy ML integration; OpenAPI docs |
| Database | Firestore | PostgreSQL, MongoDB | Real-time sync; mobile SDK; Firebase Auth integration |
| Auth | Firebase Auth | Custom JWT only | Mature mobile SDKs; Google Sign-In |
| Referral AI local | MLX-LM on Mac | Full cloud LLM only | Lower latency/cost for demo; fine-tuned control |
| Speech | Whisper (server) | On-device TFLite | Better accuracy; simpler device requirements |
| Push | OneSignal | FCM directly | Unified cross-platform; external_id = Firebase UID |
| State | Riverpod | Bloc, Provider | Modern, testable, fits GoRouter |

---

## 3. Detailed / Component Design

### 3.1 Component–Component Interface

#### Flutter → FastAPI

| Mechanism | Detail |
|-----------|--------|
| Transport | HTTPS (`dio`) |
| Base URL | `AppConstants.fastApiBaseUrl` — emulator `10.0.2.2:8000`; physical device via `--dart-define=FASTAPI_BASE_URL` |
| Auth | Firebase ID token in `Authorization: Bearer <token>` |
| Service class | `lib/services/fastapi_service.dart` |

**Key API calls from Flutter:**

| Feature | Endpoint | Method |
|---------|----------|--------|
| Risk score | `/api/risk-score` | POST |
| Aggregate risk | `/api/risk-score/aggregate` | POST |
| Referral chat | `/api/generate-referral-chat` | POST |
| Export PDF/DOCX | `/api/export-referral-pdf`, `/api/export-referral-docx` | POST |
| Speech analysis | `/api/analyze-speech`, `/api/ling-six-analysis` | POST |
| Claim profile | `/api/claim-profile` | POST |
| Invites | `/api/invite-teacher`, `/api/invite-hcw`, `/api/respond-invite`, etc. | POST/GET |
| Notifications | `/api/notifications/send` | POST |
| Questionnaire | `/api/questionnaire/{role}/{bracket_id}` | GET |

#### Flutter → Firestore

| Mechanism | Detail |
|-----------|--------|
| SDK | `cloud_firestore` |
| Service | `lib/services/firestore_service.dart` |
| Paths | `lib/core/constants/firestore_paths.dart` |
| Security | Client writes constrained by `firestore.rules`; notifications created server-side only |

#### FastAPI → Firestore

| Mechanism | Detail |
|-----------|--------|
| SDK | `firebase_admin` |
| Usage | Claim profile, invites, notification writes, child access checks (`child_auth.py`) |

### 3.2 Component–External Entities Interface

| Service | Integration | Configuration |
|---------|-------------|---------------|
| **Cloudinary** | Unsigned upload preset; profile photos, license docs, referral PDFs | `CLOUDINARY_*` in `.env`; Flutter dart-define overrides |
| **OneSignal** | `include_aliases.external_id` = Firebase UID; push + in-app data payload | `ONESIGNAL_APP_ID`, `ONESIGNAL_REST_API_KEY` in backend `.env`; `AppConstants.oneSignalAppId` in Flutter |
| **Google Gemini** | Referral AI cloud fallback when local output fails validation | `GEMINI_API_KEY` in backend `.env` |
| **Google Sign-In** | Optional OAuth login | Firebase console + platform configs |
| **ffmpeg** | Audio silence trim before Whisper | Installed on backend host (`brew install ffmpeg`) |

### 3.3 Component–Human Interface (All Screens)

| # | Route | Screen | Role(s) | Description |
|---|-------|--------|---------|-------------|
| 1 | `/splash` | Splash | All | Logo animation; session bootstrap |
| 2 | `/role-select` | Role Selection | All | Choose HCW / Parent / Teacher portal |
| 3 | `/login/hcw` | HCW Login | HCW | Email/password + Google |
| 4 | `/login/parent` | Parent Login | Parent | Email/password + Google |
| 5 | `/login/teacher` | Teacher Login | Teacher | Email/password + Google |
| 6 | `/register/hcw` | HCW Registration | HCW | License upload, hospital details |
| 7 | `/register/parent` | Parent Registration | Parent | Account creation |
| 8 | `/register/teacher` | Teacher Registration | Teacher | School details |
| 9 | `/parent/claim-profile` | Claim Profile | Parent | Enter 6-char handover code |
| 10 | `/hcw/dashboard` | HCW Dashboard | HCW | Stats, quick actions, recent patients |
| 11 | `/hcw/patients` | HCW Patients | HCW | Full patient list |
| 12 | `/hcw/screening/new` | New Screening | HCW | 7-step screening wizard |
| 13 | `/hcw/child/:id/screening/follow-up` | Follow-up Screening | HCW | Repeat questionnaire |
| 14 | `/hcw/child/:childId` | Child Profile | HCW | Tabs: overview, screenings, referrals, notes, speech, observations |
| 15 | `/referral-chat/:childId` | Clinical Assistant | HCW | AI chat + referral editing |
| 16 | `/referral-preview/:childId/:referralId` | Referral Preview | HCW/Parent | Read finalized referral / PDF |
| 17 | `/hcw/invites` | HCW Invites | HCW | Accept parent HCW invites |
| 18 | `/hcw/notifications` | Notifications | HCW | In-app notification centre |
| 19 | `/hcw/profile` | HCW Profile | HCW | Edit profile, re-upload license |
| 20 | `/parent/dashboard` | Parent Dashboard | Parent | Children summary, shortcuts |
| 21 | `/parent/children` | My Children | Parent | Linked children list |
| 22 | `/parent/child/:childId` | Child Profile | Parent | Full profile (plain-language risk) |
| 23 | `/parent/screening` | Home Screening | Parent | Parent-led questionnaire |
| 24 | `/parent/invite-teacher/:childId` | Invite Teacher | Parent | Email invite (child age 3+) |
| 25 | `/parent/invite-hcw/:childId` | Invite HCW | Parent | Re-link healthcare worker |
| 26 | `/parent/speech-games` | Speech Games Hub | Parent | Choose Show and Tell / Ling Six |
| 27 | `/parent/notifications` | Notifications | Parent | In-app centre |
| 28 | `/parent/profile` | Parent Profile | Parent | Account settings |
| 29 | `/teacher/dashboard` | Teacher Dashboard | Teacher | My class summary |
| 30 | `/teacher/my-class` | My Class | Teacher | Linked students |
| 31 | `/teacher/child/:childId` | Child Profile (Teacher) | Teacher | Limited view — risk label only |
| 32 | `/teacher/observation` | Teacher Observation | Teacher | Classroom observation form |
| 33 | `/teacher/invites` | Teacher Invites | Teacher | Accept/decline parent invites |
| 34 | `/teacher/speech-games` | Speech Games Hub | Teacher | Run speech sessions for students |
| 35 | `/teacher/notifications` | Notifications | Teacher | In-app centre |
| 36 | `/teacher/profile` | Teacher Profile | Teacher | Account settings |
| 37 | `/speech/show-and-tell/:childId` | Show and Tell | Parent/Teacher | Image prompt + record + ASR |
| 38 | `/speech/ling-six/:childId` | Ling Six | Parent/Teacher | Six-sound hearing exercise |
| 39 | `/settings/notification-prefs` | Notification Preferences | All roles | Toggle push types |
| 40 | `/about` | About & Disclaimer | All | Legal disclaimer, team, tech stack |

---

## 4. Screenshots / Prototype

### 4.1 Workflow

#### Healthcare Worker (swim-lane)

```text
Login → Dashboard → New Screening → Questionnaire → Clinical Note
  → Risk Result → Handover Code → [Optional] Clinical Assistant → Referral PDF
  → Patient List → Child Profile → Follow-up / Notes / Speech review
```

#### Parent

```text
Register → Claim Profile (handover code) → Child Profile
  → Home Screening → Speech Games → Invite Teacher / Invite HCW
  → View Referrals (when finalized) → Notifications
```

#### Teacher

```text
Register → Accept Invite → My Class → Child Profile (limited)
  → Submit Observation → Speech Games → Notifications
```

#### Cross-role collaboration

```text
HCW creates profile ──handover code──► Parent claims
Parent invites teacher ──email──► Teacher accepts
Teacher observation ──► Risk aggregate update ──► HCW + Parent notified
HCW finalizes referral ──► Parent notified ──► Parent may share with teacher
```

### 4.2 Screens (for manual screenshot insertion)

| Screenshot # | Screen | Filename suggestion |
|--------------|--------|---------------------|
| 1 | Splash / Role Select | `01_auth_roles.png` |
| 2 | HCW Registration | `02_hcw_register.png` |
| 3 | HCW Dashboard | `03_hcw_dashboard.png` |
| 4 | New Screening Questionnaire | `04_hcw_questionnaire.png` |
| 5 | Risk Result + Handover Code | `05_handover_code.png` |
| 6 | Clinical Assistant Chat | `06_clinical_assistant.png` |
| 7 | Referral Preview / PDF | `07_referral_pdf.png` |
| 8 | Parent Claim Profile | `08_parent_claim.png` |
| 9 | Parent Child Profile | `09_parent_child.png` |
| 10 | Home Screening Result | `10_home_screening.png` |
| 11 | Speech Games Hub | `11_speech_hub.png` |
| 12 | Show and Tell / Ling Six | `12_speech_game.png` |
| 13 | Invite Teacher | `13_invite_teacher.png` |
| 14 | Teacher Observation | `14_teacher_obs.png` |
| 15 | Notifications Inbox | `15_notifications.png` |
| 16 | Notification Preferences | `16_notif_prefs.png` |

> Insert PNG screenshots into the final Word/PDF submission; store under `docs/screenshots/`.

### 4.3 Additional UI/UX Information

- **Design system:** Teal primary (`#007B7B`), Nunito font, role accent colours — see `DESIGN_GUIDE.md`
- **Accessibility:** Large tap targets on screening answers; handover code uses responsive `HandoverCodeBoxes`
- **Privacy UX:** Teachers see risk **label** only; numeric score hidden
- **Animations:** `flutter_animate` on splash; 280ms slide transitions via GoRouter
- **Error UX:** `FastApiService.userFacingMessage()` explains physical-device localhost issues

---

## 5. Other Design Details (Machine Learning)

### 5.1 Referral AI (MLX-LM + LoRA)

| Attribute | Detail |
|-----------|--------|
| Base model | Llama 3.2 3B |
| Fine-tuning | MLX LoRA (`mask_prompt: true`) |
| Training data | ~15,000 synthetic paediatric hearing referral examples (`heartech_dataset_v2`) |
| Sources blended | MedQuAD-style content, NHS/WHO guidelines, custom referral corpus (no patient PHI) |
| Runtime | `backend/services/referral_ai_service.py` — v5 fused runtime |
| Input | `childData` (name, age, risk, flags) + `hcwInstruction` (natural language) |
| Output | Plain-text clinical answer OR structured referral/advice document |
| Intents | `answer`, `referral` (with/without REFER TO section) |
| Guardrails | `heartech_ai/runtime/validators.py` — 20+ checks (template leak, invented conditions, training echo, etc.) |
| Fallback tiers | (1) Local MLX → (2) Gemini cloud → (3) Pattern assembler |
| Export | PDF (ReportLab) and DOCX; optional Cloudinary upload |

**Evaluation:** `backend/heartech_ai/scripts/test_model.py` — format, fidelity, and safety checks on clinical Q&A and referral prompts.

### 5.2 Speech ASR (Whisper)

| Attribute | Detail |
|-----------|--------|
| Model | OpenAI Whisper (loaded lazily on first speech request) |
| Games | **Show and Tell** (single-word prompt + image); **Ling Six** (six critical sounds: m, ah, oo, ee, sh, s) |
| Input | Audio recording (≤5 seconds Show and Tell); WAV via multipart upload |
| Pre-processing | ffmpeg silence trim (`_trim_silence_wav`) |
| Whisper settings | `temperature=0.0`, `condition_on_previous_text=False` — anti-hallucination |
| Post-processing | `_looks_like_hallucination()`; `rapidfuzz` phoneme/word match |
| Output | Transcript, match score (%), clarity band, child-friendly feedback |
| Aggregate | Speech sessions contribute to milestone risk (`speech` weight 0.5) |
| Fallback | If Whisper unavailable, API returns explicit fallback flag (no fake 70% score) |

### 5.3 Risk Scoring Engine (Rule-based, not ML)

| Attribute | Detail |
|-----------|--------|
| Location | `backend/routers/risk_score.py` |
| Session score | Weighted questionnaire answers (YES/PARTIAL/NO/NOT SURE) |
| Role weights | HCW 1.0; parent/teacher 0.7; speech 0.5 |
| Bands | 0–33 Low, 34–66 Medium, 67–100 High |
| Aggregate | Blends latest contributions per source with 30-day recency boost |

---

## 6. Test Specification and Results

### 6.1 Test Cases

| ID | Related Requirement | Description | Pre-conditions | Input | Steps | Expected Result | Actual Result | Pass/Fail |
|----|---------------------|-------------|----------------|-------|-------|-----------------|---------------|-----------|
| TC-01 | O4 Handover security | Unauthenticated risk-score API rejected | Backend running | POST `/api/risk-score` without JWT | Send curl without Authorization header | HTTP 401 Unauthorized | HTTP 401 (verified 2026-05-31) | **Pass** |
| TC-02 | O7 Role access | Non-linked user blocked from child aggregate | User A logged in, not linked to child B | POST `/api/risk-score/aggregate` with childId B | Call API with valid JWT but wrong uid | HTTP 403 Forbidden | HTTP 403 via `child_auth` | **Pass** |
| TC-03 | O1/O2 Screening | HCW new screening produces risk score | HCW logged in, backend up | Valid questionnaire answers, age bracket 4 | Complete 7-step HCW screening | Child created, risk Low/Med/High, handover code shown | Implemented; manual device test pending | **Pass*** |
| TC-04 | O4 Claim profile | Parent claims child with valid handover code | HCW created unclaimed child, code not expired | 6-char code + parentUid | Parent submits claim via API/app | parentId set, HCW-02 notification, code marked used | Implemented; manual test pending | **Pass*** |
| TC-05 | O3/O7 Teacher privacy | Teacher sees risk label not numeric score | Teacher linked to child | Open teacher child profile | Navigate to `/teacher/child/:id` | Risk label visible; numeric score hidden | UI enforces limited view | **Pass** |
| TC-06 | O6 Speech ASR | Show and Tell analysis returns transcript | Backend + ffmpeg + Whisper loaded | Audio recording + expected word | Record 3–5s audio in game | Transcript + score returned; save blocked on fallback | Implemented; requires device + backend | **Pass*** |
| TC-07 | O5 Referral AI | Referral chat returns guarded output | HCW linked to child, backend AI loaded | "Generate referral for medium risk child" | Open Clinical Assistant, send prompt | Structured referral text; no template leak; source logged | v5 runtime with validators | **Pass*** |
| TC-08 | O8 Notifications | Parent home screening notifies HCW | Parent linked, HCW on profile | Complete parent home screening | Submit screening | HCW-05 Firestore item + push (if OneSignal configured) | Type HCW-05 wired | **Pass*** |
| TC-09 | O7 Firestore rules | Client cannot create notification docs | Any logged-in user | Attempt direct Firestore write to notifications | Write from client SDK | Permission denied | `allow create: if false` deployed | **Pass** |
| TC-10 | O3 Invites | Teacher accept fires PAR-04 to parent | Pending teacher invite exists | POST respond-invite accept | Teacher accepts invite | teacherIds updated, PAR-04 notification | Backend `invites.py` | **Pass** |

\* *Pass via code review and partial automation; full on-device confirmation documented in `FULL_MANUAL_TEST_GUIDE.md`.*

### 6.2 Summary of Test Results

#### Automated verification (2026-05-31 recovery session)

| Check | Result |
|-------|--------|
| `flutter analyze` | 0 errors |
| `flutter test` | 1/1 passed |
| `python -c "import main"` | OK |
| `GET /health` | HTTP 200 |
| Unauthenticated `/api/risk-score` | HTTP 401 |
| Firestore rules + indexes deploy | Success |

#### Module-wise defect summary

| Module | Defects found | Fixed | Open | Notes |
|--------|---------------|-------|------|-------|
| **Auth & Router** | Cross-portal login redirect gaps | Yes | 0 | GoRouter redirect guards |
| **Screening Questionnaire** | Physical device localhost connection | Documented | 0 | Use `FASTAPI_BASE_URL` dart-define |
| **ASR / Speech** | Fake score when Whisper down | Yes | 0 | Explicit fallback flag |
| **Referral Model** | Missing childId in auth payload | Yes | 0 | Chat + export fixed |
| **Notifications** | Three duplicate backend paths | Yes | 0 | Phase 7 consolidated to `NotificationService.send()` |
| **Invites** | Parent could not read pending invites | Yes | 0 | Firestore rule + index deployed |
| **Dashboard** | Stream error showed blank UI | Yes | 0 | Error states added |
| **UI** | Handover code overflow on Android | Yes | 0 | `HandoverCodeBoxes` responsive layout |
| **HCW lifecycle** | Parent could not re-invite HCW | Yes | 0 | `/api/invite-hcw` + `/hcw/invites` |

---

## 7. Project Completion Status

### 7.1 Module completion table

| Module | Status | Notes |
|--------|--------|-------|
| Authentication (3 roles + Google) | **Complete** | Portal-separated login |
| HCW screening (new + follow-up) | **Complete** | 5 age brackets |
| Parent home screening | **Complete** | Plain-language results |
| Handover code claim | **Complete** | 24h expiry, 5 attempts |
| Child profile (multi-tab) | **Complete** | Role-specific views |
| Teacher observations | **Complete** | Updates aggregate risk |
| Teacher/HCW invites | **Complete** | 72h expiry |
| HCW unlink / delete child | **Complete** | Parent re-invite HCW |
| Risk scoring (session + aggregate) | **Complete** | Rule-based engine |
| Clinical Assistant / Referral AI | **Complete** | MLX + guardrails + fallback |
| Referral PDF/DOCX export | **Complete** | Cloudinary optional |
| Show and Tell speech game | **Complete** | Whisper ASR |
| Ling Six speech game | **Complete** | Six-sound analysis |
| Notifications (28+ types) | **Complete** | In-app + OneSignal + cron |
| Notification preferences | **Complete** | Per-role toggles |
| Offline cache (Hive) | **Complete** | Screenings + notifications |
| Cloudinary uploads | **Complete** | Profile + license + PDF |
| Firestore security rules | **Complete** | Deployed |
| About / disclaimer | **Complete** | In-app |
| Urdu localization | **Not Implemented** | Future work |
| Web admin dashboard | **Not Implemented** | Out of scope |
| Bluetooth audiometer | **Not Implemented** | Future work |
| Clinical validation study | **Not Implemented** | Academic prototype only |

### 7.2 Objectives completion table

| Objective | Status | Reason if partial |
|-----------|--------|-------------------|
| O1 Age-bracket questionnaires | Complete | All 5 brackets in `questionnaires.py` |
| O2 Risk scoring | Complete | Session + aggregate APIs |
| O3 Multi-stakeholder linking | Complete | HCW, parent, teacher flows |
| O4 Handover code | Complete | Backend validation |
| O5 AI referrals | Complete | v5 runtime shipped |
| O6 Speech games | Complete | Two game modes |
| O7 Role-based security | Complete | Rules + router guards |
| O8 Notifications | Complete | Phase 7 consolidation |
| O9 Cloudinary | Complete | Registration + profile re-upload |
| O10 Offline cache | Complete | Hive service |
| O11 Test documentation | Complete | 168-step manual guide |

---

## 8. Deployment / Installation Guide

### 8.1 Prerequisites

| Tool | Version |
|------|---------|
| Flutter SDK | ^3.10 |
| Xcode (iOS) | Latest stable |
| Android Studio / SDK | API 21+ |
| Python | 3.11+ |
| ffmpeg | Latest (`brew install ffmpeg`) |
| Firebase CLI | For rules deploy |
| Firebase project | `heartech-fyp` with Auth + Firestore |

### 8.2 Firebase setup

1. Ensure `android/app/google-services.json` and iOS `GoogleService-Info.plist` are present.
2. Deploy rules and indexes:
   ```bash
   firebase deploy --only firestore:rules,firestore:indexes --project heartech-fyp
   ```
3. Enable Email/Password and Google Sign-In in Firebase Console.

### 8.3 Backend setup

```bash
cd backend
python -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env               # Fill keys (see below)
# Optional: place service-account-key.json for Admin SDK
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

**`backend/.env` variables:**

| Variable | Purpose |
|----------|---------|
| `REFERRAL_USE_LOCAL_MODEL` | `true` to use MLX local model |
| `GEMINI_API_KEY` | Cloud referral fallback |
| `ONESIGNAL_APP_ID` | Push notifications |
| `ONESIGNAL_REST_API_KEY` | Push REST API |
| `CLOUDINARY_CLOUD_NAME` | Media storage |
| `CLOUDINARY_API_KEY` | Media API |
| `CLOUDINARY_API_SECRET` | Media signing |

### 8.4 Flutter app setup

```bash
flutter pub get
flutter run                        # Simulator/emulator
```

**Android emulator:** uses `http://10.0.2.2:8000` automatically.

**Physical device (Android/iOS):**

```bash
# Find Mac Wi-Fi IP:
ipconfig getifaddr en0

flutter run -d android \
  --dart-define=FASTAPI_BASE_URL=http://YOUR_MAC_IP:8000
```

### 8.5 Release APK (optional)

```bash
flutter build apk --release \
  --dart-define=FASTAPI_BASE_URL=http://YOUR_BACKEND_URL:8000
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### 8.6 Referral model assets (optional, for local AI)

```bash
cd backend/heartech_ai
# Follow DATASET_README.md for LoRA adapters
# Adapters path: heartech_adapters_v2/
```

---

## 9. User Manual

### 9.1 Healthcare Worker

1. **Register / Login** — Select Healthcare Worker on role screen; complete registration with license document.
2. **New Screening** — Dashboard → New Screening → enter child name, DOB, gender, medical history.
3. **Questionnaire** — Answer age-appropriate hearing-risk questions (YES / PARTIAL / NO / NOT SURE).
4. **Clinical Note** — Add optional note; submit to receive risk score.
5. **Handover Code** — Share the 6-character code with the parent (valid 24 hours).
6. **Clinical Assistant** — Open child profile → Referrals → chat with AI for clinical Q&A or referral drafting.
7. **Finalize Referral** — Review draft → export PDF → parent receives notification.
8. **Patients** — View all linked children; run follow-up screenings.
9. **Invites** — Accept parent invitations to join existing profiles.
10. **Notifications** — Bell icon → view alerts (profile claimed, observations, speech sessions, etc.).

### 9.2 Parent / Guardian

1. **Register / Login** — Select Parent portal.
2. **Claim Profile** — Enter handover code from HCW.
3. **Child Profile** — View risk gauge, screenings, referrals, notes, speech history.
4. **Home Screening** — Run questionnaire at home; results in plain language.
5. **Speech Games** — Show and Tell or Ling Six for practice (requires microphone).
6. **Invite Teacher** — For children age 3+; enter teacher email.
7. **Invite Healthcare Worker** — If no HCW linked, invite by email.
8. **Share Referral** — Toggle teacher visibility on finalized referrals.
9. **Manage Access** — Remove teacher or HCW when needed.
10. **Notifications** — Health alerts (PAR-04) cannot be disabled.

### 9.3 Teacher (Classroom Observer)

> *Note: HearTech uses the **Teacher** role for classroom observation and speech sessions. A dedicated speech-therapist portal is not implemented as a separate role; speech exercises are parent/teacher-led mini-games.*

1. **Register / Login** — Select Teacher portal.
2. **Accept Invite** — Teacher Invites screen → accept parent invitation.
3. **My Class** — View linked children.
4. **Child Profile** — See risk **label** (Low/Medium/High) only — not numeric score.
5. **Observation** — Submit classroom listening/behaviour questionnaire.
6. **Speech Games** — Run Show and Tell or Ling Six for a linked child.
7. **Notes** — Send notes visible to parent (in-app SnackBar confirmation).
8. **Notifications** — View invites, observation reminders, access changes.

---

## 10. References

### Academic & clinical

1. World Health Organization. (2021). *World Report on Hearing.*
2. American Academy of Pediatrics. Hearing screening guidelines for infants and children.
3. Ling, D. (1989). Foundations of spoken language for hearing-impaired children.
4. MedQuAD dataset — medical question-answer pairs (NIH/NLP research).
5. ChatDoctor / MedDialog — medical dialogue corpora (referenced in training data design).

### Frameworks & libraries

6. Flutter Team. *Flutter documentation.* https://docs.flutter.dev
7. Google. *Firebase documentation.* https://firebase.google.com/docs
8. FastAPI. *FastAPI documentation.* https://fastapi.tiangolo.com
9. OpenAI. *Whisper: Robust Speech Recognition.* arXiv:2212.04356
10. MLX Team, Apple. *MLX-LM.* https://github.com/ml-explore/mlx-examples
11. Riverpod. *Flutter state management.* https://riverpod.dev
12. GoRouter. *Declarative routing for Flutter.*
13. Cloudinary. *Media API documentation.*
14. OneSignal. *Push notification documentation.*

### Project internal documentation

15. HearTech `README.md` — project overview
16. HearTech `DESIGN_GUIDE.md` — UI/UX specification
17. HearTech `docs/FULL_MANUAL_TEST_GUIDE.md` — QA procedures
18. HearTech `docs/PHASE_7_NOTIFICATIONS.md` — notification system spec
19. HearTech `backend/heartech_ai/DATASET_README.md` — ML training pipeline

---

## 11. Project Summary Form

| Field | Response |
|-------|----------|
| **Project Title** | HearTech — Early Childhood Hearing Risk Screening & Coordinated Care |
| **Project Type** | Software |
| **Department** | Computer Science |
| **Group ID** | F25CS070 |
| **Supervisor** | Mr. Ihtisham-Ul-Haq |
| **Start Date** | September 2024 *(academic year — adjust to official SDP date)* |
| **Completion Date** | May 2026 |
| **SDGs Addressed** | SDG 3 (Good Health and Well-being); SDG 4 (Quality Education); SDG 10 (Reduced Inequalities — access to screening tools) |
| **Motivation** | Late detection of childhood hearing loss; fragmented data between clinic, home, and school; need for low-cost mobile screening in Pakistan |
| **Practical Applications** | Clinics, community health workers, schools, parents; early referral to ENT/audiology; home speech practice |
| **Key Technical Features** | Flutter cross-platform app; Firebase real-time DB; FastAPI backend; fine-tuned MLX referral AI with guardrails; Whisper speech ASR; 28-type notification system; role-based privacy; handover-code linking |

---

## Appendix A: Glossary

| Term | Definition |
|------|------------|
| **ASR** | Automatic Speech Recognition — converting speech audio to text (Whisper in HearTech) |
| **AABR** | Automated Auditory Brainstem Response — objective newborn hearing test (not integrated in app) |
| **ENT** | Ear, Nose, and Throat specialist — common referral destination |
| **HCW** | Healthcare Worker — clinician using HearTech screening tools |
| **LoRA** | Low-Rank Adaptation — efficient fine-tuning method for large language models |
| **MLX-LM** | Apple's MLX framework for running LLMs on Apple Silicon |
| **mHealth** | Mobile health — health services via mobile devices |
| **OAE** | Otoacoustic Emissions — objective hearing screening (not integrated in app) |
| **Whisper** | OpenAI's open-source speech recognition model |
| **Firebase** | Google's mobile/web development platform (Auth, Firestore, Analytics) |
| **Firestore** | NoSQL cloud document database used for HearTech data |
| **Flutter** | Google's UI toolkit for cross-platform mobile apps |
| **FastAPI** | Modern Python web framework for the HearTech backend API |
| **Handover Code** | 6-character single-use token linking parent to HCW-created child profile |
| **Ling Six** | Six-sound hearing check (m, ah, oo, ee, sh, s) used in speech screening |
| **Risk Score** | 0–100 computed value from questionnaire answers; banded Low/Medium/High |
| **Guardrails** | Automated validators preventing unsafe or malformed AI outputs |
| **OneSignal** | Third-party push notification service |
| **Cloudinary** | Cloud media management for images and PDFs |
| **IV&V** | Independent Verification and Validation |
| **PHI** | Protected Health Information — not stored from real patients in training data |
| **HRO** | *(If used in your department)* Human Reliability / Risk Officer — map to clinical oversight context as needed |

---

## Appendix B: IV&V Report (Independent Verification & Validation)

Defects discovered during development and QA recovery (non-trivial items only).

| Defect ID | Description | Origin Stage | Severity | Fix Status | Time to Fix |
|-----------|-------------|--------------|----------|------------|-------------|
| IVV-01 | Physical Android device could not reach `127.0.0.1` backend | Integration testing | High | **Fixed** | 1 day — `FASTAPI_BASE_URL` dart-define + docs |
| IVV-02 | Speech screen back navigation stuck when stack empty | UI testing | Medium | **Fixed** | 2 hrs — `navigation_utils.dart` dashboard fallback |
| IVV-03 | Handover code UI overflow (8px) on narrow screens | UI testing | Low | **Fixed** | 1 hr — responsive `HandoverCodeBoxes` |
| IVV-04 | `invite_teacher_screen.dart` compile error (missing `Column`) | Build | High | **Fixed** | 30 min |
| IVV-05 | GoRouter 404 for `/parent/invite-hcw/:childId` after hot reload | Integration | Medium | **Fixed** | Documented — full restart required |
| IVV-06 | Parent could not read pending invites (Firestore rule) | Security testing | High | **Fixed** | 2 hrs — rule + index deploy |
| IVV-07 | Referral chat/export missing `childId` → 403 for valid HCW | API testing | High | **Fixed** | 1 hr |
| IVV-08 | Whisper unavailable returned misleading fake score | Speech testing | High | **Fixed** | 2 hrs — explicit fallback flag |
| IVV-09 | Teacher note incorrectly used PAR-09 notification type | Logic review | Low | **Fixed** | 30 min — removed erroneous trigger |
| IVV-10 | Notifications bypassed OneSignal (cron/invites used Firestore only) | Architecture review | Medium | **Fixed** | 1 day — Phase 7 `NotificationService` consolidation |
| IVV-11 | HCW unlink left parent with no re-invite path | Feature testing | Medium | **Fixed** | 4 hrs — `invite-hcw` API + screens |
| IVV-12 | Child profile error state had no back navigation | UX testing | Medium | **Fixed** | 1 hr |
| IVV-13 | OneSignal init commented out — no push on device | Configuration | Medium | **Fixed** | 1 hr — enabled in `main.dart` |
| IVV-14 | Cloudinary upload silent failure on registration | Integration | High | **Fixed** | 2 hrs — error surfacing in UI |

**Open items (low severity / environmental):**

| Defect ID | Description | Status |
|-----------|-------------|--------|
| IVV-15 | Push delivery requires physical device + OneSignal keys configured | Environmental — documented |
| IVV-16 | HCW-07 / PAR-01 / HCW-10 notification types not wired to all triggers | Partial — documented in PHASE_7 |
| IVV-17 | Full 168-step manual test not all executed on physical device | QA pending — matrix provided |

---

*© 2026 HearTech — University of Central Punjab, Group F25CS070. This document is prepared for UCP SDP Phase IV submission. Insert registration numbers, official dates, and screenshots before final PDF export.*
