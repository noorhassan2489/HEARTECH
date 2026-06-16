# HearTech — Complete Diagram Specification

**Purpose:** This document is the authoritative source for creating all UML and systems diagrams for the HearTech FYP (Group F25CS070). Use it to write **PlantUML** and **Mermaid** code. Every entity, relationship, state, and flow reflects the **currently implemented** codebase (v1.0.0), including recent features: parent→HCW invite (`HCW-11`), HCW unlink/delete, Phase 7 notification consolidation, OneSignal push deep-links, aggregate risk scoring, and speech games.

**Diagram tooling map:**

| Diagram type | Recommended tool | PlantUML keyword | Mermaid keyword |
|--------------|------------------|------------------|-----------------|
| High-level architecture | Either | `component`, `package` | `flowchart TB` |
| Component | PlantUML preferred | `component` | `flowchart` |
| ER / Database schema | Either | `entity` | `erDiagram` |
| Class | PlantUML preferred | `class` | `classDiagram` |
| Activity | Either | `activity` | `flowchart` |
| Decision | Either | `activity` + `if` | `flowchart` + diamond |
| Design-level sequence | Either | `sequence` | `sequenceDiagram` |
| Collaboration / Communication | PlantUML | `object` + numbered arrows | Limited — use sequence |
| Event traces | Mermaid timeline or PlantUML | `concise` / custom | `gantt` or sequence |
| DFD Level 0 / 1 | Mermaid | — | `flowchart` |
| Deployment | PlantUML preferred | `deployment` | `flowchart` |
| State | Either | `state` | `stateDiagram-v2` |
| Petri net | PlantUML or custom | Custom tokens | Custom notation |
| Sequence (runtime) | Either | `sequence` | `sequenceDiagram` |
| Swim lane | Mermaid preferred | `activity` partitions | `flowchart` + subgraph |

**Notation conventions:**
- `«service»` = application service layer
- `«external»` = third-party cloud API
- `«database»` = persistent store
- `«AI»` = ML inference runtime
- Arrows: `-->` synchronous call; `-.->` async/event; `==>` data flow

---

## Table of Contents

1. [High-Level Architecture Diagram](#1-high-level-architecture-diagram)
2. [Component Diagram](#2-component-diagram)
3. [ER Diagram](#3-er-diagram)
4. [Class Diagram](#4-class-diagram)
5. [Activity Diagram](#5-activity-diagram)
6. [Decision Diagram](#6-decision-diagram)
7. [Design-Level Sequence Diagram](#7-design-level-sequence-diagram)
8. [Collaboration Diagram](#8-collaboration-diagram)
9. [Event Traces](#9-event-traces)
10. [DFD Level 0](#10-dfd-level-0)
11. [DFD Level 1](#11-dfd-level-1)
12. [Deployment Diagram](#12-deployment-diagram)
13. [Database Schema](#13-database-schema)
14. [State Diagram](#14-state-diagram)
15. [Petri Nets](#15-petri-nets)
16. [Sequence Diagrams (Runtime)](#16-sequence-diagrams-runtime)
17. [Swim Lane Diagrams](#17-swim-lane-diagrams)
18. [Diagram Index & Suggested Filenames](#18-diagram-index--suggested-filenames)

---

## 1. High-Level Architecture Diagram

### 1.1 Purpose
Show the **four-layer system** at executive level: mobile client, cloud data/auth, application backend, and external/AI services. Audience: supervisors, open house, SDP report §2.

### 1.2 Layers and major blocks

```
┌─────────────────────────────────────────────────────────────────────────┐
│ LAYER 1: PRESENTATION (Mobile Client)                                    │
│   Flutter App (Android + iOS)                                            │
│   • 3 role portals: HCW | Parent | Teacher                               │
│   • 40 routed screens, GoRouter, Riverpod                                │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │ HTTPS + Firebase SDK
        ┌───────────────────────┼───────────────────────┐
        ▼                       ▼                       ▼
┌───────────────┐     ┌─────────────────┐     ┌─────────────────┐
│ LAYER 2A:     │     │ LAYER 2B:       │     │ LAYER 3:        │
│ Firebase Auth │     │ Cloud Firestore │     │ FastAPI Backend │
│ (Identity)    │     │ (Real-time DB)  │     │ (Business+AI)   │
└───────────────┘     └─────────────────┘     └────────┬────────┘
                                                         │
              ┌──────────────────────────────────────────┼──────────────┐
              ▼                    ▼                     ▼              ▼
        ┌──────────┐      ┌────────────┐      ┌────────────┐  ┌──────────┐
        │ MLX-LM   │      │ Whisper    │      │ Cloudinary │  │ OneSignal│
        │ Referral │      │ ASR        │      │ Media/PDF  │  │ Push     │
        │ AI       │      │            │      │            │  │          │
        └──────────┘      └────────────┘      └────────────┘  └──────────┘
              │                    │
              └──────── Gemini API (fallback) ────────┘
```

### 1.3 Nodes (draw as boxes)

| Node ID | Label | Technology | Responsibilities |
|---------|-------|--------------|------------------|
| `APP` | HearTech Mobile App | Flutter 3.x / Dart | UI, local Hive cache, mic/camera, routing |
| `AUTH` | Firebase Authentication | Google Firebase | Email/password, Google Sign-In, JWT tokens |
| `FS` | Cloud Firestore | NoSQL document DB | Users, children, subcollections, rules-enforced access |
| `API` | HearTech FastAPI Server | Python 3.11 / Uvicorn | Risk score, referrals, speech, invites, notifications, cron |
| `MLX` | Referral AI Runtime | MLX-LM + LoRA adapters | Clinical Q&A, referral letter generation |
| `WH` | Whisper ASR | openai-whisper | Speech transcription for games |
| `CL` | Cloudinary | CDN + API | Profile photos, license docs, referral PDFs |
| `OS` | OneSignal | Push platform | Device push; external_id = Firebase UID |
| `GM` | Gemini API | Google Cloud | Referral AI cloud fallback |
| `CRON` | APScheduler | BackgroundScheduler | 5 scheduled notification jobs |

### 1.4 Primary data flows (label on arrows)

| From | To | Data / protocol |
|------|-----|-----------------|
| APP | AUTH | Login, register, token refresh |
| APP | FS | Read/write child profiles, streams (Firestore SDK) |
| APP | API | REST JSON + `Authorization: Bearer <Firebase JWT>` |
| API | FS | Admin SDK read/write (claim, invites, notifications) |
| API | MLX | Prompt + childData → referralText |
| API | WH | Audio WAV → transcript |
| API | CL | Upload PDF/image |
| API | OS | Push payload with navigationRoute |
| API | GM | Cloud prompt when local validation fails |
| CRON | FS | Query children/invites for reminders |
| CRON | OS | Scheduled push via NotificationService |

### 1.5 Boundaries
- **Trust boundary 1:** Mobile device (user credentials, mic audio)
- **Trust boundary 2:** Firebase (auth + data at rest)
- **Trust boundary 3:** Backend host (service account, API keys in `.env`)
- **Out of scope on diagram:** Hospital EMR, Bluetooth audiometer, web admin portal

### 1.6 PlantUML hints
```plantuml
@startuml HearTech_HighLevel
!define RECTANGLE class
package "Presentation" { [Flutter App] }
package "Firebase" { [Auth] [Firestore] }
package "Backend" { [FastAPI] [APScheduler] }
cloud "AI" { [MLX-LM] [Whisper] }
cloud "External" { [Cloudinary] [OneSignal] [Gemini] }
@enduml
```

### 1.7 Mermaid hints
Use `flowchart TB` with subgraphs: `Client`, `Firebase`, `Backend`, `AI`, `External`.

---

## 2. Component Diagram

### 2.1 Purpose
Decompose HearTech into **implementable software components** with explicit interfaces. More granular than high-level architecture. Maps to repository folders.

### 2.2 Flutter client components (`lib/`)

| Component | Package/path | Depends on | Provides |
|-----------|--------------|------------|----------|
| `UI.Features.Auth` | `features/auth/` | AuthService, Router | Splash, login, register, claim profile |
| `UI.Features.Dashboard` | `features/dashboard/` | FirestoreService | Role dashboards |
| `UI.Features.Screening` | `features/screening/` | FastAPI, Firestore | HCW/parent screening, child profile, invites |
| `UI.Features.Referral` | `features/referral/` | FastAPI, Firestore | Clinical Assistant chat, preview |
| `UI.Features.Speech` | `features/speech/` | FastAPI, Firestore | Show and Tell, Ling Six |
| `UI.Features.Notifications` | `features/notifications/` | FirestoreService | Notification centre |
| `UI.Features.Settings` | `features/settings/` | FirestoreService | Profiles, notification prefs |
| `UI.Features.TeacherDashboard` | `features/teacher_dashboard/` | FirestoreService | Teacher-limited child profile |
| `Core.Router` | `core/router/app_router.dart` | Riverpod providers | GoRouter, role guards |
| `Core.Theme` | `core/theme/` | — | HearTech design tokens |
| `Core.Constants` | `core/constants/` | — | API URLs, Firestore paths |
| `Services.Firestore` | `services/firestore_service.dart` | cloud_firestore | CRUD + streams |
| `Services.FastAPI` | `services/fastapi_service.dart` | dio | Backend REST client |
| `Services.Auth` | `services/firebase_auth_service.dart` | firebase_auth | Login + OneSignal register |
| `Services.Notification` | `services/notification_service.dart` | onesignal_flutter | Push init + tap handler |
| `Services.Cloudinary` | `services/cloudinary_service.dart` | cloudinary | Image upload |
| `Services.Offline` | `services/offline_service.dart` | hive | Local cache |
| `Shared.Models` | `shared/models/` | — | 9 domain models |
| `Shared.Widgets` | `shared/widgets/` | — | HandoverCodeBoxes, etc. |

### 2.3 FastAPI backend components (`backend/`)

| Component | Path | Depends on | Provides |
|-----------|------|------------|----------|
| `Main.App` | `main.py` | All routers | FastAPI app, CORS, startup |
| `Auth.JWT` | `auth_dependency.py` | firebase_admin | `verify_firebase_token` |
| `Auth.ChildAccess` | `child_auth.py` | Firestore | `assert_child_access` |
| `Router.RiskScore` | `routers/risk_score.py` | — | `/api/risk-score`, `/aggregate` |
| `Router.Referral` | `routers/referral.py` | ReferralAIService | Chat, PDF/DOCX export |
| `Router.Speech` | `routers/speech.py` | Whisper, ffmpeg | analyze-speech, ling-six |
| `Router.Invites` | `routers/invites.py` | NotificationService | Teacher/HCW invites, remove links |
| `Router.Profile` | `routers/profile.py` | NotificationService | claim-profile |
| `Router.Notifications` | `routers/notifications.py` | NotificationService | send, 28 trigger helpers |
| `Router.Questionnaires` | `routers/questionnaires.py` | — | Age-bracket questions |
| `Router.Utils` | `routers/utils.py` | — | age-bracket, handover regenerate |
| `Service.Notification` | `services/notification_service.py` | Firestore, OneSignal | Unified send + push |
| `Service.ReferralAI` | `services/referral_ai_service.py` | MLX, validators | v5 guarded generation |
| `Service.CloudProvider` | `services/runtime_cloud_provider.py` | Gemini | Cloud fallback |
| `AI.Runtime` | `heartech_ai/runtime/` | — | intent, validators, router |
| `Cron.Scheduler` | `cron_jobs.py` | NotificationService | 5 jobs |

### 2.4 Component interfaces (draw as lollipop/socket)

| Interface | Provider | Consumer | Protocol |
|-----------|----------|----------|----------|
| `IFirestore` | Firestore SDK / Admin | App services, API | gRPC/HTTPS |
| `IREST` | FastAPI routers | FastApiService | JSON REST |
| `IAuthToken` | Firebase Auth | dio interceptor | JWT Bearer |
| `IPush` | NotificationService | Cron, invites, Flutter triggers | OneSignal REST |
| `IReferralGen` | ReferralAIService | referral router | Internal async |
| `IASR` | speech router | Show and Tell, Ling Six | Multipart audio |

### 2.5 Key dependencies (draw as dashed arrows)

- `UI.Features.Referral` → `Services.FastAPI` → `Router.Referral` → `Service.ReferralAI` → `AI.Runtime.Validators`
- `UI.Features.Screening` → `Services.FastAPI` → `Router.RiskScore`
- `UI.Features.Screening` → `Router.Invites` (invite teacher/HCW)
- `Cron.Scheduler` → `Service.Notification` → `IPush` + Firestore
- All protected routers → `Auth.JWT`

### 2.6 New-feature components (highlight in diagram)
- **`Router.Invites.invite_hcw`** — parent re-links HCW (`HCW-11`)
- **`Router.Invites.remove_hcw`** — parent remove or HCW self-unlink
- **`Router.Invites.hcw_delete_child`** — delete unclaimed profile
- **`Service.Notification.send_sync`** — cron → unified push path
- **`UI.Features.Screening.invite_hcw_screen`** — `/parent/invite-hcw/:childId`
- **`UI.Features.Screening.pending_invites (role: hcw)`** — `/hcw/invites`

---

## 3. ER Diagram

### 3.1 Purpose
Model **persistent entities** and cardinalities in Cloud Firestore. Not SQL — document/subcollection hierarchy.

### 3.2 Entities (tables for ER tool)

#### Entity: `USERS`
| Attribute | Type | Key | Notes |
|-----------|------|-----|-------|
| uid | string | PK | Firebase Auth UID |
| email | string | | Unique per account |
| role | enum | | hcw \| parent \| teacher |
| name | string | | |
| profilePhotoUrl | string | | Cloudinary URL |
| linkedChildIds | string[] | | Denormalized |
| notificationPrefs | map | | Keys: HCW_01, PAR_04, etc. |
| licenseNumber | string | | HCW only |
| licenseDocUrl | string | | HCW only |
| hospitalName | string | | HCW only |
| schoolName | string | | Teacher only |
| phone | string | | Parent only |

#### Entity: `CHILDREN`
| Attribute | Type | Key | Notes |
|-----------|------|-----|-------|
| childId | string | PK | |
| name | string | | |
| dob | timestamp | | |
| gender | string | | |
| ageBracket | int | | 1–5 |
| createdByHcwId | string | FK→USERS | |
| parentId | string | FK→USERS | null until claimed |
| hcwIds | string[] | FK→USERS | |
| teacherIds | string[] | FK→USERS | |
| riskScore | int | | 0–100 |
| riskLevel | string | | low/medium/high |
| riskBreakdown | map | | hcw, parent, teacher, speech |
| medicalHistory | map | | premature, NICU, etc. |
| handoverCode | embedded | | see HANDOVER_CODE |
| lastScreeningDate | timestamp | | |
| homeScreeningReminderSent | bool | | Cron dedupe |
| nextScreeningReminderSent | bool | | Cron dedupe |
| observationReminderSent | bool | | Cron dedupe |

#### Embedded: `HANDOVER_CODE` (in CHILDREN)
| Attribute | Type | Notes |
|-----------|------|-------|
| code | string(6) | A-Z, 2-9 charset |
| createdAt | timestamp | |
| expiresAt | timestamp | +24h |
| used | bool | |
| attempts | int | max 5 |
| expiryWarningSent | bool | HCW-01 dedupe |

#### Entity: `SCREENINGS` (subcollection of CHILDREN)
| Attribute | Type | Key |
|-----------|------|-----|
| screeningId | string | PK |
| conductedBy | string | FK→USERS |
| conductorRole | string | hcw/parent/teacher |
| date | timestamp | |
| ageBracket | int | |
| answers | array | {questionId, answer} |
| riskScore | int | |
| riskLevel | string | |
| clinicalNote | string | optional |

#### Entity: `REFERRALS` (subcollection)
| Attribute | Type | Notes |
|-----------|------|-------|
| referralId | string | PK |
| generatedByHcwId | string | FK |
| status | enum | draft \| discarded \| finalized |
| letterText | string | AI output |
| pdfCloudinaryUrl | string | |
| isVisibleToParent | bool | |
| isVisibleToTeacher | bool | Parent controls |
| visibleToTeacherIds | string[] | |
| finalizedAt | timestamp | |

#### Entity: `SPEECH_LOGS` (subcollection)
| Attribute | Type | Notes |
|-----------|------|-------|
| logId | string | PK |
| game | string | showAndTell \| lingSix |
| conductedBy | string | FK |
| conductorRole | string | parent \| teacher |
| score | int | 0–100 |
| whisperTranscript | string | Show and Tell |
| expectedWord | string | |
| lingResults | array | Ling Six per sound |
| frequencyFlag | string | pass/watch/refer |

#### Entity: `TEACHER_OBSERVATIONS` (subcollection)
| Attribute | Type |
|-----------|------|
| obsId | string PK |
| teacherUid | string FK |
| date | timestamp |
| answers | array |
| isVisibleToHcw | bool |
| visibleToHcwIds | string[] |

#### Entity: `NOTES` (subcollection)
| Attribute | Type |
|-----------|------|
| noteId | string PK |
| authorUid | string FK |
| authorRole | string |
| text | string |
| isPublic | bool | parent visibility |
| isTeacherVisible | bool | |

#### Entity: `INVITES` (top-level)
| Attribute | Type | Notes |
|-----------|------|-------|
| inviteId | string | PK |
| inviteType | enum | teacher \| hcw |
| childId | string | FK→CHILDREN |
| parentUid | string | FK |
| teacherEmail / hcwEmail | string | |
| teacherUid / hcwUid | string | FK |
| status | enum | pending/accepted/declined/cancelled/expired |
| expiresAt | timestamp | +72h |
| inviteExpirySent | bool | |

#### Entity: `NOTIFICATIONS` (top-level path)
Path: `notifications/{uid}/items/{notifId}`

| Attribute | Type |
|-----------|------|
| notifId | string PK |
| type | string | HCW-01…TCH-08, HCW-11 |
| title | string |
| body | string |
| read | bool |
| priority | string | normal \| high |
| navigationRoute | string | GoRouter path |
| relatedChildId | string | FK optional |
| relatedInviteId | string | FK optional |

### 3.3 Relationships (cardinality)

```
USERS (HCW) 1 ──creates──► * CHILDREN
USERS (Parent) 1 ──claims──► 0..1 CHILDREN (via handoverCode)
USERS (Teacher) * ──linked──► * CHILDREN (via teacherIds)
CHILDREN 1 ──contains──► * SCREENINGS
CHILDREN 1 ──contains──► * REFERRALS
CHILDREN 1 ──contains──► * SPEECH_LOGS
CHILDREN 1 ──contains──► * TEACHER_OBSERVATIONS
CHILDREN 1 ──contains──► * NOTES
USERS 1 ──has inbox──► * NOTIFICATIONS
USERS (Parent) 1 ──sends──► * INVITES
USERS (Teacher/HCW) 1 ──receives──► * INVITES
```

### 3.4 ER diagram notes for Firestore
- Subcollections are **not separate top-level entities** in Firestore — draw with containment notation (crow's foot inside parent box).
- `linkedChildIds` on USERS is **denormalized** for teacher dashboard queries.
- Notifications are **never client-created** — only backend writes (security rule).

---

## 4. Class Diagram

### 4.1 Purpose
Show **domain model classes** (Flutter `shared/models/`) and key service classes with attributes, methods, and relationships.

### 4.2 Domain classes (draw all with attributes)

#### `UserModel`
```
- uid: String
- email: String
- role: String
- name: String
- linkedChildIds: List<String>
- notificationPrefs: Map<String, bool>
- licenseDocUrl: String?  {HCW}
- schoolName: String?     {Teacher}
+ fromJson()
+ toJson()
+ isHcw / isParent / isTeacher: bool
```

#### `ChildModel`
```
- childId: String
- name: String
- dob: DateTime
- ageBracket: int
- parentId: String?
- hcwIds: List<String>
- teacherIds: List<String>
- riskScore: int
- riskLevel: String
- handoverCode: HandoverCode?
- medicalHistory: MedicalHistory
+ isClaimed: bool
+ copyWith()
```

#### `HandoverCode`
```
- code: String
- expiresAt: DateTime
- used: bool
- attempts: int
+ isExpired: bool
+ timeRemaining: Duration
```

#### `ScreeningModel` / `ScreeningAnswer`
#### `ReferralModel` + `ReferralStatus` enum
#### `InviteModel`
#### `NotificationModel` + `colorKey` getter
#### `SpeechLogModel` + `LingSixResult`
#### `TeacherObservationModel`
#### `NoteModel`

### 4.3 Service classes

#### `FirestoreService`
```
- _db: FirebaseFirestore
+ createUser()
+ getChildStream()
+ addScreening()
+ addReferral()
+ addSpeechLog()
+ getNotificationsStream()
+ updateChild()
```

#### `FastApiService`
```
- _dio: Dio
+ scoreRisk()
+ aggregateRiskScore()
+ sendNotification()
+ claimProfile()  // via profile endpoint
+ inviteTeacher() / inviteHcw()
+ analyzeSpeech()
+ generateReferralChat()
```

#### `ReferralAIService` (backend)
```
+ get_instance(): ReferralAIService
+ generate(childData, hcwInstruction): GenerationResult
- _generate_with_two_tier()
- _validate_output()
- _can_ship_output()
```

#### `NotificationService` (backend)
```
+ send(uid, notif_type, title, body, ...): async
+ send_sync(**kwargs): void
```

### 4.4 Relationships (UML)

| From | To | Relationship |
|------|-----|--------------|
| ChildModel | HandoverCode | composition 1..1 |
| ChildModel | MedicalHistory | composition 1..1 |
| ChildModel | ScreeningModel | association 1..* |
| ChildModel | ReferralModel | association 1..* |
| ChildModel | SpeechLogModel | association 1..* |
| UserModel | ChildModel | association * (via ids) |
| FirestoreService | ChildModel | dependency «uses» |
| FastApiService | NotificationService | dependency HTTP |

### 4.5 Design patterns (stereotypes)
- `«singleton»` ReferralAIService
- `«factory»` *.fromJson() on models
- `«service»` FirestoreService, FastApiService
- `«enum»` ReferralStatus

---

## 5. Activity Diagram

### 5.1 Purpose
Show **control flow** through multi-step business processes. Draw separate diagrams per major process.

### 5.2 Activity A: HCW New Screening (7 steps)

**Initial node:** HCW taps "New Screening"

| Step | Action | Decision |
|------|--------|----------|
| 1 | Enter child demographics (name, DOB, gender) | |
| 2 | System computes ageBracket from DOB | |
| 3 | Enter medical history | |
| 4 | Fetch questionnaire `GET /api/questionnaire/hcw/{bracket}` | |
| 5 | Answer all questions | |
| 6 | `POST /api/risk-score` → receive score + level | |
| 7 | Enter optional clinical note | |
| 8 | Fork: risk level? | Low/Med → create profile; High → emphasize referral |
| 9 | Generate 6-char handoverCode (expires +24h) | |
| 10 | Write child + screening to Firestore | |
| 11 | Display HandoverCodeBoxes UI | |
| 12 | Optional: open Clinical Assistant | |

**Final node:** HCW dashboard or child profile

**Exception flows:**
- API unreachable → show `userFacingMessage` (physical device LAN IP hint)
- Risk API 401 → redirect to login

### 5.3 Activity B: Parent Claim Profile

| Step | Action |
|------|--------|
| 1 | Parent registers/logs in |
| 2 | Navigate to Claim Profile |
| 3 | Enter 6-char code |
| 4 | `POST /api/claim-profile` |
| 5 | Decision: code valid? |
| 5a | invalid → increment attempts, show error |
| 5b | expired → error |
| 5c | already_used → error |
| 5d | rate_limited (≥5) → error |
| 6 | Set parentId, mark used, update linkedChildIds |
| 7 | Fire HCW-02 notification |
| 8 | Navigate to child profile |

### 5.4 Activity C: Referral AI Generation

| Step | Action |
|------|--------|
| 1 | HCW opens Clinical Assistant |
| 2 | Enter instruction (chat) |
| 3 | Router decides intent: answer \| referral |
| 4 | Local MLX inference |
| 5 | `validate_runtime_output()` |
| 6 | Decision: output valid? |
| 6a | Yes → return to HCW, auto-save draft |
| 6b | No → Gemini cloud retry |
| 6c | Still no → pattern assembler fallback |
| 7 | HCW edits in chat (optional) |
| 8 | Finalize → export PDF → PAR-08 to parent |

### 5.5 Activity D: Show and Tell Speech Game

| Step | Action |
|------|--------|
| 1 | Select child (parent/teacher) |
| 2 | Load image prompt `GET /api/speech-images` |
| 3 | Start recording (max 5s auto-stop) |
| 4 | Upload audio `POST /api/analyze-speech` |
| 5 | ffmpeg silence trim → Whisper transcribe |
| 6 | Fuzzy match vs expected word |
| 7 | Decision: fallback flag? → block save |
| 8 | Save speechLog to Firestore |
| 9 | Notify HCW (HCW-08); if teacher-led also PAR-08 parent |

### 5.6 Activity E: Phase 7 Notification Dispatch

| Step | Action |
|------|--------|
| 1 | Trigger event (cron, invite, Flutter API) |
| 2 | `NotificationService.send()` |
| 3 | Write Firestore `notifications/{uid}/items` |
| 4 | Decision: skip_push? (PAR-10) → stop |
| 5 | Check notificationPrefs (unless priority=high) |
| 6 | OneSignal REST push with navigationRoute |
| 7 | User taps push → GoRouter.push(route) |

---

## 6. Decision Diagram

### 6.1 Purpose
Highlight **branching business rules** as decision diamonds. Can be extracted from activity diagrams.

### 6.2 Decision tree D1: Risk level classification

```
[Compute raw score 0-100]
        │
        ▼
   ┌─────────────┐
   │ score ≤ 33? │──Yes──► LOW
   └──────┬──────┘
          No
          ▼
   ┌─────────────┐
   │ score ≤ 66? │──Yes──► MEDIUM
   └──────┬──────┘
          No
          ▼
        HIGH
```

**Source:** `AppConstants.riskLevelFromScore()`, `risk_score.py`

### 6.3 Decision tree D2: Handover code validation (claim-profile)

```
[Receive code + parentUid]
        │
        ▼
   JWT uid == parentUid? ──No──► 401
        │Yes
        ▼
   Code exists? ──No──► error: invalid
        │Yes
        ▼
   attempts ≥ 5? ──Yes──► error: rate_limited
        │No
        ▼
   used == true? ──Yes──► error: already_used
        │No
        ▼
   now > expiresAt? ──Yes──► error: expired
        │No
        ▼
   SUCCESS: set parentId, used=true, HCW-02
```

### 6.4 Decision tree D3: Referral AI output shipping

```
[Model output received]
        │
        ▼
   intent == answer?
   ├─Yes─► _can_ship_answer()? ──Yes──► SHIP
   │              └─No──► relaxed check? ──Yes──► SHIP
   └─No──► validation.ok AND NOT degenerate? ──Yes──► SHIP
                      └─No──► try cloud → assembler
```

**Hard failures (never ship):** template_leak, invented_condition, training_qa_leak

### 6.5 Decision tree D4: Teacher invite eligibility

```
[Parent opens invite teacher]
        │
        ▼
   child.age ≥ 3 years? ──No──► block UI message
        │Yes
        ▼
   teacher email exists in users.role=teacher? ──No──► teacher_not_found
        │Yes
        ▼
   pending invite exists? ──No──► create invite, TCH-01
        │Yes
        ▼
   error: invite_already_pending
```

### 6.6 Decision tree D5: Push notification send

```
[NotificationService.send()]
        │
        ▼
   Write Firestore (always)
        │
        ▼
   skip_push == true? ──Yes──► END (in-app only)
        │No
        ▼
   priority == high? ──Yes──► skip pref check
        │No
        ▼
   pref[type] == false? ──Yes──► END (no push)
        │No
        ▼
   OneSignal configured? ──No──► log + END
        │Yes
        ▼
   SEND PUSH
```

### 6.7 Decision tree D6: HCW remove vs delete child

```
[HCW requests action]
        │
        ▼
   parentId set? ──No──► DELETE allowed (hcw-delete-child)
        │Yes
        ▼
   REMOVE only (unlink from hcwIds)
   Parent may invite new HCW (invite-hcw)
```

---

## 7. Design-Level Sequence Diagram

### 7.1 Purpose
**Design-time** interactions between logical components (not exact method names). Shows order of messages for major use cases.

### 7.2 SD-01: Authentication + session bootstrap

| # | From | To | Message |
|---|------|-----|---------|
| 1 | User | SplashScreen | launch app |
| 2 | SplashScreen | FirebaseAuth | check currentUser |
| 3 | FirebaseAuth | FirestoreService | getUserStream(uid) |
| 4 | SplashScreen | NotificationService | onLogin(uid, role) |
| 5 | SplashScreen | GoRouter | redirect to role dashboard |

### 7.3 SD-02: Screening + child creation

| # | From | To | Message |
|---|------|-----|---------|
| 1 | HcwNewScreening | FastApiService | getQuestionnaire(bracket) |
| 2 | FastApiService | QuestionnairesRouter | GET /questionnaire/hcw/{id} |
| 3 | HcwNewScreening | FastApiService | scoreRisk(answers) |
| 4 | FastApiService | RiskScoreRouter | POST /risk-score |
| 5 | HcwNewScreening | FirestoreService | createChild(childModel) |
| 6 | FirestoreService | Firestore | set children/{id} |

### 7.4 SD-03: Parent claim + HCW notification

| # | From | To | Message |
|---|------|-----|---------|
| 1 | ClaimProfileScreen | FastApiService | claimProfile(code) |
| 2 | FastApiService | ProfileRouter | POST /claim-profile |
| 3 | ProfileRouter | Firestore | batch update child + user |
| 4 | ProfileRouter | NotificationService | send(HCW-02) |
| 5 | NotificationService | Firestore | write notification doc |
| 6 | NotificationService | OneSignal | push to HCW uid |

### 7.5 SD-04: Teacher observation → aggregate risk

| # | From | To | Message |
|---|------|-----|---------|
| 1 | TeacherObservationScreen | FirestoreService | addTeacherObservation() |
| 2 | TeacherObservationScreen | FastApiService | aggregateRiskScore() |
| 3 | FastApiService | RiskScoreRouter | POST /risk-score/aggregate |
| 4 | TeacherObservationScreen | FirestoreService | updateChild(riskScore, riskLevel) |
| 5 | TeacherObservationScreen | FastApiService | sendNotification PAR-07 |
| 6 | TeacherObservationScreen | FastApiService | sendNotification HCW-04 |
| 7 | If risk changed | FastApiService | HCW-05 + PAR-04 (high priority) |

### 7.6 SD-05: Parent invite HCW (new feature)

| # | From | To | Message |
|---|------|-----|---------|
| 1 | InviteHcwScreen | FastApiService | inviteHcw(email) |
| 2 | FastApiService | InvitesRouter | POST /invite-hcw |
| 3 | InvitesRouter | Firestore | create invites/{id} inviteType=hcw |
| 4 | InvitesRouter | NotificationService | send(HCW-11) |
| 5 | HcwPendingInvites | InvitesRouter | POST respond-invite accept |
| 6 | InvitesRouter | Firestore | hcwIds arrayUnion, status=accepted |
| 7 | InvitesRouter | NotificationService | send(PAR-04) to parent |

---

## 8. Collaboration Diagram

### 8.1 Purpose
UML **communication diagram** — same messages as sequence but emphasizes **object graph** with numbered arrows. Use for referral generation.

### 8.2 Objects (nodes)

`:ReferralChatScreen` `:FastApiService` `:ReferralRouter` `:ReferralAIService` `:IntentRouter` `:Validators` `:MLXModel` `:GeminiProvider` `:PatternAssembler` `:FirestoreService`

### 8.3 Numbered interactions (Referral chat)

```
:ReferralChatScreen
    │
    │1: generateReferralChat(childData, instruction)
    ▼
:FastApiService ──2──► :ReferralRouter
                          │
                          │3: generate()
                          ▼
                     :ReferralAIService
                          │
                          │4: decide_intent()
                          ▼
                     :IntentRouter
                          │
                          │5: run_inference()
                          ▼
                     :MLXModel
                          │
                          │6: validate_output()
                          ▼
                     :Validators
                          │
                   ┌──────┴──────┐
              7: ok          8: fail
                   │              │
                   ▼              ▼
              return text    :GeminiProvider
                                  │9: retry
                                  ▼
                             :Validators
                                  │10: fail
                                  ▼
                             :PatternAssembler
                          │
                          │11: autoSaveDraft()
                          ▼
                     :FirestoreService
```

### 8.4 Collaboration: Notification dispatch

Objects: `:CronJob` `:InvitesRouter` `:FlutterApp` `:NotificationService` `:Firestore` `:OneSignal` `:UserDevice`

1. CronJob → NotificationService: send_sync(HCW-01)
2. NotificationService → Firestore: set notifications/{uid}/items
3. NotificationService → OneSignal: REST POST
4. OneSignal → UserDevice: push
5. UserDevice → FlutterApp: tap event
6. FlutterApp → GoRouter: push(navigationRoute)

---

## 9. Event Traces

### 9.1 Purpose
**Temporal log** of discrete events for one end-to-end scenario. Format for PlantUML timing or Mermaid gantt.

### 9.2 Trace T1: Full child lifecycle (happy path)

| Time | Event | Actor | System response |
|------|-------|-------|-----------------|
| T0 | HCW completes registration | HCW | users/{uid} created |
| T1 | HCW starts new screening | HCW | — |
| T2 | Risk score = 58 (Medium) | API | RiskScoreResponse |
| T3 | Child + handover code created | HCW App | children/{id} |
| T4 | Cron: code expires in 2h | Cron | HCW-01 queued |
| T5 | Parent claims code | Parent | parentId set |
| T6 | HCW receives HCW-02 | Backend | push + in-app |
| T7 | Parent home screening | Parent | screening added, HCW-05 |
| T8 | Parent invites teacher | Parent | invite pending |
| T9 | Teacher accepts | Teacher | teacherIds updated, PAR-04 |
| T10 | Teacher observation | Teacher | PAR-07, HCW-04, risk aggregate |
| T11 | Risk rises Medium→High | System | HCW-05 + PAR-04 high |
| T12 | HCW generates referral | HCW | draft referral |
| T13 | HCW finalizes PDF | HCW | PAR-08, Cloudinary URL |
| T14 | Parent shares with teacher | Parent | referral visibleToTeacher |
| T15 | Parent runs Ling Six | Parent | speechLog, HCW-08 |

### 9.3 Trace T2: HCW unlink + re-invite

| Time | Event | Actor | System response |
|------|-------|-------|-----------------|
| T0 | HCW self-unlinks | HCW | remove from hcwIds, PAR-10 parent |
| T1 | Parent opens invite HCW | Parent | — |
| T2 | POST invite-hcw | Parent | inviteType=hcw, HCW-11 |
| T3 | HCW accepts | HCW | hcwIds restored, PAR-04 |
| T4 | Cron 6h before expiry | Cron | HCW-11 / PAR-06 if still pending |

### 9.4 Trace T3: Speech analysis failure path

| Time | Event | System response |
|------|-------|-----------------|
| T0 | Record audio | local file |
| T1 | POST analyze-speech | ffmpeg trim |
| T2 | Whisper unavailable | fallback flag in response |
| T3 | UI blocks save | SnackBar error, no speechLog |
| T4 | No HCW-08 fired | — |

---

## 10. DFD Level 0

### 10.1 Purpose
**Context diagram** — HearTech as single process, external entities, data flows.

### 10.2 External entities

| ID | Entity | Description |
|----|--------|-------------|
| E1 | Healthcare Worker | Clinician user |
| E2 | Parent/Guardian | Child caregiver |
| E3 | Teacher | Classroom observer |
| E4 | Firebase Cloud | Auth + Firestore (draw as external store OR entity) |
| E5 | Cloudinary | Media storage |
| E6 | OneSignal | Push gateway |
| E7 | Gemini API | AI fallback |

### 10.3 Central process

**P0: HearTech System** (bubble containing app + backend as one system for Level 0)

### 10.4 Data flows (label every arrow)

| From | To | Data flow name |
|------|-----|----------------|
| E1 | P0 | Screening answers, clinical notes, referral instructions |
| P0 | E1 | Risk results, handover codes, referral letters, notifications |
| E2 | P0 | Handover code, home screening answers, speech audio |
| P0 | E2 | Child profile, risk (plain language), referrals, notifications |
| E3 | P0 | Classroom observations, speech audio |
| P0 | E3 | Risk label, shared referrals, invites, notifications |
| P0 | E4 | User credentials, child documents, real-time updates |
| E4 | P0 | Auth tokens, Firestore snapshots |
| P0 | E5 | Images, PDFs |
| E5 | P0 | CDN URLs |
| P0 | E6 | Push payloads |
| E6 | E3/E2/E1 | Mobile push notifications |
| P0 | E7 | Referral prompts (fallback) |
| E7 | P0 | Generated clinical text |

---

## 11. DFD Level 1

### 11.1 Purpose
Decompose P0 into **major processes** inside HearTech.

### 11.2 Processes

| ID | Process name | Description |
|----|--------------|-------------|
| P1 | User Authentication & Role Routing | Firebase Auth, portal guards |
| P2 | Screening & Risk Scoring | Questionnaires, session + aggregate scores |
| P3 | Profile Linking & Invites | Handover, teacher/HCW invites, remove/unlink |
| P4 | Clinical Referral AI | Chat, validation, PDF export |
| P5 | Speech Analysis | Whisper ASR, Ling Six, Show and Tell |
| P6 | Notification Management | In-app + OneSignal + cron |
| P7 | Child Profile Management | CRUD, notes, observations, speech logs |

### 11.3 Data stores

| ID | Store | Maps to |
|----|-------|---------|
| D1 | users | Firestore users |
| D2 | children | Firestore children |
| D3 | child_subcollections | screenings, referrals, speechLogs, notes, observations |
| D4 | invites | Firestore invites |
| D5 | notifications | notifications/{uid}/items |
| D6 | local_cache | Hive on device |

### 11.4 Level 1 flows (connect processes)

```
E1 ──screening data──► P2 ──risk score──► D2
P2 ──read/write──► D2
E2 ──handover code──► P3 ──parentId──► D2
P3 ──invite──► D4
P3 ──notify──► P6
E1 ──chat──► P4 ──draft──► D3
P4 ──pdf url──► D3 via Cloudinary
E2/E3 ──audio──► P5 ──speechLog──► D3
P5 ──trigger──► P6
P6 ──write──► D5
P6 ──push──► E6
P1 ──auth──► D1
P7 ──aggregate views──► D2, D3
All roles ──► P1
```

### 11.5 Sub-decomposition note (Level 2 optional)
- P2 → P2a Questionnaire fetch, P2b Score compute, P2c Aggregate milestone
- P6 → P6a Firestore write, P6b Pref check, P6c OneSignal REST, P6d Cron scheduler

---

## 12. Deployment Diagram

### 12.1 Purpose
Show **physical/logical nodes** where software runs in development and production.

### 12.2 Nodes

| Node | Artifact | OS / host |
|------|----------|-----------|
| `device_android` | HearTech APK/IPA | Android 8+ phone/tablet |
| `device_ios` | HearTech IPA | iOS 14+ iPhone/iPad |
| `dev_mac` | Flutter build + Xcode/Android SDK | macOS dev machine |
| `backend_host` | uvicorn main:app | Mac (dev) or Google Cloud Run (prod) |
| `firebase` | Auth + Firestore | Google Cloud (us-central or configured) |
| `cloudinary_cdn` | Static media | Cloudinary cloud |
| `onesignal` | Push service | OneSignal SaaS |
| `gemini` | Generative API | Google AI |

### 12.3 Deployment relationships

```
[dev_mac]
  │ flutter build / flutter run
  ├──────────────────────► [device_android]
  └──────────────────────► [device_ios]

[device_*]
  │ Firebase SDK (TLS)
  ├──────────────────────► [firebase]
  │ dio HTTPS + JWT (port 8000 dev, 443 prod)
  └──────────────────────► [backend_host]

[backend_host]
  │ firebase_admin
  ├──────────────────────► [firebase]
  │ REST API
  ├──────────────────────► [cloudinary_cdn]
  ├──────────────────────► [onesignal]
  └──────────────────────► [gemini]

[backend_host] contains:
  - Python venv
  - heartech_adapters_v2/ (MLX weights)
  - Whisper model (lazy load)
  - APScheduler threads
  - ffmpeg binary
  - .env secrets
```

### 12.4 Network notes for diagram
- Physical phone → backend: same Wi-Fi LAN, `FASTAPI_BASE_URL=http://<mac-ip>:8000`
- Emulator Android: `10.0.2.2:8000`
- Firestore rules deployed via Firebase CLI

### 12.5 PlantUML deployment stereotype
`node`, `artifact`, `component`, `database`

---

## 13. Database Schema

### 13.1 Purpose
Tabular **physical schema** for Firestore (not SQL). Complements ER diagram with field types and indexes.

### 13.2 Collection: `users`

| Field | Type | Required | Index |
|-------|------|----------|-------|
| uid | string | yes | PK |
| email | string | yes | |
| role | string | yes | composite with email queries |
| name | string | yes | |
| linkedChildIds | array<string> | no | |
| notificationPrefs | map<string,bool> | no | |
| profilePhotoUrl | string | no | |
| licenseDocUrl | string | no | HCW |
| hospitalName | string | no | HCW |
| schoolName | string | no | Teacher |
| createdAt | timestamp | yes | |
| lastLoginAt | timestamp | no | |

### 13.3 Collection: `children`

| Field | Type | Required | Index |
|-------|------|----------|-------|
| childId | string | yes | PK |
| name | string | yes | |
| dob | timestamp | yes | |
| ageBracket | int | yes | |
| createdByHcwId | string | yes | |
| parentId | string | no | |
| hcwIds | array | yes | |
| teacherIds | array | no | |
| riskScore | int | yes | |
| riskLevel | string | yes | in queries for cron |
| riskBreakdown | map | no | |
| medicalHistory | map | no | |
| handoverCode | map | no | nested fields |
| handoverCode.code | string | | scan in claim-profile |
| handoverCode.expiresAt | timestamp | | |
| handoverCode.used | bool | | |
| handoverCode.attempts | int | | |
| handoverCode.expiryWarningSent | bool | | |
| homeScreeningReminderSent | bool | no | |
| nextScreeningReminderSent | bool | no | |
| observationReminderSent | bool | no | |
| lastScreeningDate | timestamp | no | |
| createdAt | timestamp | yes | |
| lastUpdatedAt | timestamp | yes | |

### 13.4 Subcollection: `children/{id}/screenings`

| Field | Type |
|-------|------|
| screeningId | string |
| conductedBy | string |
| conductorRole | string |
| date | timestamp |
| ageBracket | int |
| answers | array of {questionId, answer, category} |
| riskScore | int |
| riskLevel | string |
| clinicalNote | string |

### 13.5 Subcollection: `children/{id}/referrals`

| Field | Type |
|-------|------|
| referralId | string |
| status | string |
| letterText | string |
| pdfCloudinaryUrl | string |
| generatedByHcwId | string |
| parentId | string |
| isVisibleToParent | bool |
| isVisibleToTeacher | bool |
| visibleToTeacherIds | array |
| finalizedAt | timestamp |

### 13.6 Subcollection: `children/{id}/speechLogs`

| Field | Type |
|-------|------|
| logId | string |
| game | string |
| conductedBy | string |
| conductorRole | string |
| score | int |
| whisperTranscript | string |
| expectedWord | string |
| matchScore | int |
| clarityRating | string |
| lingResults | array |
| frequencyFlag | string |

### 13.7 Collection: `invites`

| Field | Type | Index (firestore.indexes.json) |
|-------|------|-------------------------------|
| inviteId | string | PK |
| inviteType | string | teacher \| hcw |
| childId | string | composite childId+status |
| parentUid | string | parentUid+status |
| teacherUid | string | teacherUid+status |
| hcwUid | string | hcwUid+status |
| teacherEmail | string | |
| hcwEmail | string | |
| status | string | pending/accepted/... |
| expiresAt | timestamp | |
| inviteExpirySent | bool | |

### 13.8 Collection: `notifications/{uid}/items`

| Field | Type |
|-------|------|
| notifId | string |
| type | string |
| title | string |
| body | string |
| read | bool |
| priority | string |
| navigationRoute | string |
| relatedChildId | string |
| relatedInviteId | string |
| relatedReferralId | string |
| createdAt | timestamp |

### 13.9 Security rules summary (annotate on schema diagram)
- Notifications: `create: false` (client)
- Children: read only if uid in hcwIds/parentId/teacherIds
- Referrals: teacher read only if in visibleToTeacherIds

---

## 14. State Diagram

### 14.1 Purpose
Model **state machines** for entities with lifecycle transitions.

### 14.2 State machine SM1: Child profile linkage

```
[*] ──HCW creates──► Unclaimed
Unclaimed ──parent claims──► ParentLinked
ParentLinked ──invite teacher accepted──► TeacherLinked (optional)
ParentLinked ──HCW removed──► HCWUnlinked (hcwIds empty)
HCWUnlinked ──invite HCW accepted──► ParentLinked
Unclaimed ──HCW deletes──► [*] (deleted)
```

**States:**
- `Unclaimed`: parentId=null, handoverCode.used=false
- `ParentLinked`: parentId set
- `TeacherLinked`: teacherIds non-empty
- `HCWUnlinked`: parentId set but hcwIds empty

### 14.3 State machine SM2: Handover code

```
[*] ──generate──► Active
Active ──expires──► Expired
Active ──claim success──► Used
Active ──5 failed attempts──► Locked (rate_limited)
Expired ──[*]
Used ──[*]
```

### 14.4 State machine SM3: Invite (teacher or HCW)

```
[*] ──create──► Pending
Pending ──accept──► Accepted
Pending ──decline──► Declined
Pending ──cancel──► Cancelled
Pending ──time exceeded──► Expired
Pending ──cron warning──► ExpiryWarningSent (flag only, still Pending)
Accepted ──[*]
Declined ──[*]
```

### 14.5 State machine SM4: Referral

```
[*] ──AI/chat save──► Draft
Draft ──discard──► Discarded
Draft ──finalize PDF──► Finalized
Finalized ──parent shares──► SharedWithTeacher (visibility flag)
Discarded ──[*]
```

### 14.6 State machine SM5: Notification (in-app item)

```
[*] ──send()──► Unread
Unread ──user opens──► Read
Unread ──swipe delete──► [*]
Read ──swipe delete──► [*]
```

### 14.7 State machine SM6: HCW screening wizard (UI)

```
Step0_ChildInfo → Step1_MedicalHistory → Step2_Questionnaire
  → Step3_ClinicalNote → Step4_Processing → Step5_Result
  → Step6_HandoverCode → [Complete]
```

---

## 15. Petri Nets

### 15.1 Purpose
Formal **place-transition** model for concurrent/resource-sensitive flows. Optional for advanced SDP sections.

### 15.2 Petri net PN1: Notification pipeline

**Places (circles):**
- `P1`: Event triggered
- `P2`: Firestore doc written
- `P3`: Push eligible
- `P4`: Push sent
- `P5`: User inbox (unread)

**Transitions (bars):**
- `T1`: receive_trigger (cron/API/Flutter)
- `T2`: write_firestore
- `T3`: check_skip_push_and_prefs
- `T4`: send_onesignal
- `T5`: user_read

**Arcs:**
- P1 → T1 → P2 → T2 → P3 → T3 → P4 (if eligible) → T4 → P5
- P5 → T5 → (terminal)

**Tokens:** One token in P1 per event; inhibitor arc on prefs disabled → skip T4

### 15.3 Petri net PN2: Referral AI validation loop

**Places:**
- `P_prompt`: Instruction received
- `P_local_out`: Local model output
- `P_valid`: Validated output
- `P_cloud_out`: Cloud retry output
- `P_assembled`: Fallback output

**Transitions:**
- `T_infer_local`
- `T_validate` (fails → cloud)
- `T_infer_cloud`
- `T_validate_cloud` (fails → assemble)
- `T_assemble_pattern`
- `T_ship`

### 15.4 Petri net PN3: Child claim concurrency

Model mutual exclusion on handover code:
- Only one `T_claim_success` can fire when place `P_code_valid` has exactly one token
- `T_failed_attempt` removes token from attempt pool (5 max)

---

## 16. Sequence Diagrams (Runtime)

### 16.1 Purpose
**Runtime** sequence diagrams with exact API endpoints and Firebase paths. More detailed than §7.

### 16.2 SEQ-A: POST /api/risk-score (HCW screening)

```
Actor: HCW
Participant: HcwNewScreeningScreen
Participant: FastApiService
Participant: RiskScoreRouter
Participant: Firestore

HCW -> Screen: submit answers
Screen -> FastApi: POST /api/risk-score {answers, ageBracket, conductorRole}
FastApi -> Router: verify JWT
Router -> Router: _score_answers()
Router --> FastApi: {riskScore, riskLevel, recommendations}
FastApi --> Screen: display result
Screen -> Firestore: addScreening() + createChild()
```

### 16.3 SEQ-B: POST /api/claim-profile

```
Parent -> ClaimScreen: enter code
ClaimScreen -> FastApi: POST /api/claim-profile {code, parentUid}
FastApi -> ProfileRouter: verify JWT uid match
ProfileRouter -> Firestore: scan children for handoverCode.code
ProfileRouter -> Firestore: batch update parentId, used=true
ProfileRouter -> NotificationService: send(HCW-02)
NotificationService -> OneSignal: push
ProfileRouter --> ClaimScreen: {childId, childName, riskLevel}
```

### 16.4 SEQ-C: POST /api/generate-referral-chat

```
HCW -> ReferralChatScreen: send message
Screen -> FastApi: POST /api/generate-referral-chat {childData, hcwInstruction, childId}
FastApi -> ReferralRouter: verify child access
ReferralRouter -> ReferralAI: generate()
ReferralAI -> MLX: inference
ReferralAI -> Validators: validate_runtime_output()
alt valid
  ReferralAI --> Router: {referralText, source: v5_fused}
else invalid
  ReferralAI -> Gemini: cloud retry
  ReferralAI -> Assembler: pattern fallback
end
Router --> Screen: {referralText, intent, success}
Screen -> Firestore: upsert referral draft
```

### 16.5 SEQ-D: POST /api/analyze-speech

```
User -> ShowAndTellScreen: stop recording
Screen -> FastApi: POST /api/analyze-speech (multipart audio)
FastApi -> SpeechRouter: verify child access
SpeechRouter -> ffmpeg: trim silence
SpeechRouter -> Whisper: transcribe (temp=0)
SpeechRouter -> rapidfuzz: match expected word
SpeechRouter --> Screen: {transcript, score, clarityRating, fallback?}
Screen -> Firestore: addSpeechLog()
Screen -> FastApi: POST /api/notifications/send HCW-08
```

### 16.6 SEQ-E: Cron Job 5 — invite expiry

```
Cron -> Firestore: query invites status=pending
loop expires in <= 6h
  alt inviteType=teacher
    Cron -> NotificationService: TCH-02 + PAR-06
  else inviteType=hcw
    Cron -> NotificationService: HCW-11 + PAR-06
  end
  Cron -> Firestore: inviteExpirySent=true
end
```

### 16.7 SEQ-F: OneSignal push tap (Phase 7)

```
OneSignal -> Device: push notification
User -> Device: tap
Device -> Flutter NotificationService: click listener
NotificationService -> GoRouter: push(navigationRoute)
GoRouter -> TargetScreen: e.g. /hcw/child/{id}?tab=observations
```

---

## 17. Swim Lane Diagrams

### 17.1 Purpose
Show **which role owns each step** in cross-functional workflows.

### 17.2 Swim lane SL1: End-to-end screening collaboration

| Step | HCW | Parent | Teacher | System |
|------|-----|--------|---------|--------|
| 1 | Register/login | | | Firebase Auth |
| 2 | New screening | | | Risk API |
| 3 | Share handover code | | | 24h timer starts |
| 4 | | Claim profile | | HCW-02 |
| 5 | | Home screening | | HCW-05 |
| 6 | | Invite teacher | | TCH-01 |
| 7 | | | Accept invite | PAR-04 |
| 8 | | | Submit observation | PAR-07, HCW-04 |
| 9 | Clinical Assistant | | | Referral draft |
| 10 | Finalize referral | View PAR-08 | View if shared | PDF upload |
| 11 | | Speech games | Speech games | HCW-08 |

### 17.3 Swim lane SL2: HCW lifecycle management

| Step | HCW | Parent | System |
|------|-----|--------|--------|
| 1 | Creates unclaimed child | | handoverCode |
| 2 | | Claims child | parentId set |
| 3 | Self-unlink OR parent removes | | hcwIds remove |
| 4 | | Sees no HCW card | |
| 5 | | Invite HCW by email | HCW-11 |
| 6 | Accept at /hcw/invites | | hcwIds add, PAR-04 |
| 7 | Delete unclaimed profile only | | delete_child_tree |

### 17.4 Swim lane SL3: Notification decision

| Step | Trigger source | NotificationService | Firestore | OneSignal | User |
|------|----------------|---------------------|-----------|-----------|------|
| 1 | Cron/invite/Flutter | | | | |
| 2 | | send() called | | | |
| 3 | | | write item | | |
| 4 | | check prefs | | | |
| 5 | | | | REST push | |
| 6 | | | | | receive |
| 7 | | | | | tap → navigate |

### 17.5 Swim lane SL4: Risk escalation

| Step | Teacher | Parent | HCW | Backend |
|------|---------|--------|-----|---------|
| 1 | Submit observation | | | aggregate risk |
| 2 | | | | compare old vs new level |
| 3 | | Receive PAR-04 high | Receive HCW-05 high | if changed |
| 4 | Receive TCH-03 | | | optional |

---

## 18. Diagram Index & Suggested Filenames

Use this table when generating diagram source files.

| # | Diagram type | Suggested filename | Primary section |
|---|--------------|-------------------|-----------------|
| 1 | High-level architecture | `diagrams/01-high-level-architecture.puml` | §1 |
| 2 | Component (Flutter) | `diagrams/02-component-flutter.puml` | §2 |
| 3 | Component (Backend) | `diagrams/03-component-backend.puml` | §2 |
| 4 | ER diagram | `diagrams/04-er-firestore.mmd` | §3 |
| 5 | Class diagram (domain) | `diagrams/05-class-domain.puml` | §4 |
| 6 | Class diagram (services) | `diagrams/06-class-services.puml` | §4 |
| 7 | Activity: HCW screening | `diagrams/07-activity-hcw-screening.puml` | §5.2 |
| 8 | Activity: Parent claim | `diagrams/08-activity-parent-claim.puml` | §5.3 |
| 9 | Activity: Referral AI | `diagrams/09-activity-referral-ai.puml` | §5.4 |
| 10 | Activity: Speech game | `diagrams/10-activity-speech.puml` | §5.5 |
| 11 | Decision: Risk bands | `diagrams/11-decision-risk.mmd` | §6.2 |
| 12 | Decision: Handover validation | `diagrams/12-decision-handover.mmd` | §6.3 |
| 13 | Decision: Push send | `diagrams/13-decision-push.mmd` | §6.5 |
| 14 | Design sequence: Auth | `diagrams/14-seq-design-auth.puml` | §7.2 |
| 15 | Design sequence: Invite HCW | `diagrams/15-seq-design-invite-hcw.puml` | §7.6 |
| 16 | Collaboration: Referral | `diagrams/16-collab-referral.puml` | §8.3 |
| 17 | Event trace: Child lifecycle | `diagrams/17-event-trace-lifecycle.mmd` | §9.2 |
| 18 | DFD Level 0 | `diagrams/18-dfd-level0.mmd` | §10 |
| 19 | DFD Level 1 | `diagrams/19-dfd-level1.mmd` | §11 |
| 20 | Deployment | `diagrams/20-deployment.puml` | §12 |
| 21 | Database schema | `diagrams/21-database-schema.mmd` | §13 |
| 22 | State: Child linkage | `diagrams/22-state-child.puml` | §14.2 |
| 23 | State: Referral | `diagrams/23-state-referral.puml` | §14.5 |
| 24 | State: Invite | `diagrams/24-state-invite.puml` | §14.4 |
| 25 | Petri: Notifications | `diagrams/25-petri-notifications.puml` | §15.2 |
| 26 | Sequence: claim-profile | `diagrams/26-seq-runtime-claim.puml` | §16.3 |
| 27 | Sequence: referral chat | `diagrams/27-seq-runtime-referral.puml` | §16.4 |
| 28 | Sequence: speech ASR | `diagrams/28-seq-runtime-speech.puml` | §16.5 |
| 29 | Sequence: push tap | `diagrams/29-seq-runtime-push.puml` | §16.7 |
| 30 | Swim lane: E2E | `diagrams/30-swimlane-e2e.mmd` | §17.2 |
| 31 | Swim lane: HCW lifecycle | `diagrams/31-swimlane-hcw.mmd` | §17.3 |

---

## Appendix: Notification Type Catalog (for diagram annotations)

Include on notification-related diagrams.

| Type | Trigger | Recipient | Push? |
|------|---------|-----------|-------|
| HCW-01 | Cron: handover expires ≤2h | HCW | Yes (high) |
| HCW-02 | Parent claims profile | HCW | Yes |
| HCW-03 | Teacher linked | HCW | Yes |
| HCW-04 | Teacher observation | HCW | Yes |
| HCW-05 | Home screening OR risk change | HCW | Yes (high if risk) |
| HCW-06 | Cron: follow-up overdue 90d | HCW | Yes |
| HCW-08 | Speech session | HCW | Yes |
| HCW-09 | Parent removed HCW | HCW | Yes |
| HCW-11 | Parent invites HCW | HCW | Yes |
| PAR-04 | Risk change OR teacher/HCW linked | Parent | Yes (high if risk) |
| PAR-06 | Cron: invite expiring | Parent | Yes |
| PAR-07 | Teacher observation | Parent | Yes |
| PAR-08 | Referral finalized / teacher speech | Parent | Yes |
| PAR-09 | Cron: home screening reminder | Parent | Yes |
| PAR-10 | Unlink events | Parent | In-app only |
| TCH-01 | Teacher invite sent | Teacher | Yes |
| TCH-02 | Cron: invite expiring | Teacher | Yes |
| TCH-03 | Child risk changed | Teacher | Yes |
| TCH-04 | HCW note shared | Teacher | Yes |
| TCH-06 | Parent removed teacher | Teacher | Yes |
| TCH-07 | Cron: observation gap 14d | Teacher | Yes |

**Unified path:** All backend triggers → `NotificationService.send()` → Firestore + optional OneSignal.

---

## Appendix: API Endpoint Catalog (for sequence/DFD labels)

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| GET | /health | No | Health check |
| GET | /api/questionnaire/{role}/{bracket_id} | No | Questions |
| POST | /api/risk-score | JWT | Session score |
| POST | /api/risk-score/aggregate | JWT | Milestone aggregate |
| POST | /api/generate-referral-chat | JWT | AI chat |
| POST | /api/export-referral-pdf | JWT | PDF |
| POST | /api/export-referral-docx | JWT | DOCX |
| POST | /api/analyze-speech | JWT | Show and Tell |
| POST | /api/ling-six-analysis | JWT | Ling Six |
| GET | /api/speech-images | JWT | Image prompts |
| POST | /api/claim-profile | JWT | Parent claim |
| POST | /api/invite-teacher | JWT | Teacher invite |
| POST | /api/invite-hcw | JWT | HCW invite |
| POST | /api/respond-invite | JWT | Accept/decline |
| GET | /api/pending-invites | JWT | List invites |
| POST | /api/remove-hcw | JWT | Unlink HCW |
| POST | /api/hcw-delete-child | JWT | Delete unclaimed |
| POST | /api/remove-teacher | JWT | Unlink teacher |
| POST | /api/notifications/send | JWT | Generic notify |
| POST | /api/regenerate-handover-code | JWT | New code |
| GET | /api/age-bracket/{dob} | No | Bracket lookup |

---

*© 2026 HearTech — UCP FYP Group F25CS070. This specification is the source of truth for all project diagrams. When implementing PlantUML/Mermaid, copy section-by-section and render via plantuml.com, VS Code extensions, or mermaid.live.*
