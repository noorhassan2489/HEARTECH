# HearTech Manual QA Test Matrix

> **Full sequential walkthrough:** see [`FULL_MANUAL_TEST_GUIDE.md`](FULL_MANUAL_TEST_GUIDE.md) (~168 steps, every screen, real-world scenario order).

Fill in **Pass**, **Fail**, or **N/A** during device testing. Add notes for any failures.

**Legend:** ✅ = verified in recovery session (2026-05-31) via code review, automated checks, or live API/Firestore deploy — not a substitute for on-device testing.

| # | Area | Test case | Pass | Fail | Notes |
|---|------|-----------|------|------|-------|
| **PHASE 1 — Security & correctness** |
| 1.1 | Backend auth | Unauthenticated POST to `/api/risk-score` returns 401 | ✅ | | Live curl: HTTP 401 |
| 1.2 | Backend auth | Unauthenticated POST to `/api/risk-score/aggregate` returns 401 | ✅ | | Same JWT middleware |
| 1.3 | Backend auth | Caller not linked to child gets 403 on aggregate/speech/referral child ops | ✅ | | Referral chat now sends `childId` in payload |
| 1.4 | Firestore rules | Client cannot create notification documents | ✅ | | `allow create: if false` |
| 1.5 | Firestore rules | Only parent/teacher can update own invites | ✅ | | |
| 1.6 | Secrets | Backend OneSignal/Cloudinary read from env, not hardcoded | ✅ | | `backend/.env` present with Cloudinary vars |
| 1.7 | Handover | Regenerate handover code requires HCW JWT + hcwIds check | ✅ | | |
| 1.8 | Invites | Accept fires PAR-04; decline fires PAR-05 | ✅ | | |
| 1.9 | Risk score | Ling Six `frequencyFlag` uses pass/watch/refer in aggregate | ✅ | | |
| 1.10 | Risk score | Show & Tell Excellent scored same band as Good | ✅ | | |
| 1.11 | Speech API | Whisper unavailable returns fallback flag, not fake 70% score | ✅ | | |
| 1.12 | Ling Six save | Firestore log stores lowercase overallResult as frequencyFlag | ✅ | | |
| 1.13 | Router | Logged-in user redirected off login/register pages | ✅ | | |
| 1.14 | Router | `/speech/*` blocked for HCW; referral-generate/chat HCW-only | ✅ | | |
| 1.15 | Show & Tell | Save blocked when analysis unavailable/fallback | ✅ | | |
| 1.16 | Widget test | `flutter test` smoke test compiles | ✅ | | All tests passed 2026-05-31 |
| 1.17 | Invites read | Parent can read own pending invites (`parentUid` rule) | ✅ | | Rule fixed + deployed; error UI on stream failure |
| 1.18 | Referral auth | Referral chat/export include `childId` for access check | ✅ | | Fixed in chat + PDF/DOCX export |
| **PHASE 2 — Demo reliability** |
| 2.1 | Firestore indexes | Pending invites query works (teacherUid+status, childId+status) | ✅ | | Deployed to heartech-fyp 2026-05-31 |
| 2.2 | Notifications | Parent home screening sends HCW-05 (not HCW-07) | ✅ | | |
| 2.3 | Speech games | Single-child auto-select does not setState during build | ✅ | | |
| 2.4 | Error UI | Child profile root shows error if stream fails | ✅ | | |
| 2.5 | Error UI | Speech tab shows error if stream fails | ✅ | | |
| 2.6 | Error UI | HCW dashboard stats show error message | ✅ | | |
| 2.7 | Parent notes | Pull-to-refresh on notes tab | ✅ | | |
| 2.8 | Show & Tell images | API returns emoji fallback when Cloudinary empty | ✅ | | |
| 2.9 | Speech games | Teacher back navigates to `/teacher/speech-games` | ✅ | | |
| **PHASE 3 — Polish** |
| 3.1 | HCW overview | Risk breakdown chips from `child.riskBreakdown` | ✅ | | |
| 3.2 | HCW speech tab | Shows transcript, clarity, Ling flag, game type | ✅ | | |
| 3.3 | PAR-07 | Parent notification opens child profile Observations tab | ✅ | | `?tab=observations` |
| 3.4 | Teacher route | `/teacher/speech-games` exists and is role-guarded | ✅ | | |
| 3.5 | About screen | Uses HearTechTextStyles | ✅ | | |
| 3.6 | Logo asset | `HearTechLogo` loads SVG mark (no missing PNG) | ✅ | | `heartech-logo-mark.svg` via flutter_svg |
| 3.7 | Mic permission | Clear settings guidance when mic denied | ✅ | | |
| **Manual device flows (required on simulator/device)** |
| M.1 | HCW | New screening → create child → handover code | | | Run on device — backend at localhost:8000 |
| M.2 | Parent | Claim profile with code → home screening | | | |
| M.3 | Parent | Invite teacher → teacher accept/decline | | | Validates pending invite stream after rule fix |
| M.4 | Teacher | Submit observation → parent sees PAR-07 deep link | | | |
| M.5 | Speech | Show & Tell record → analyze → save (real Whisper) | | | Requires ffmpeg + backend running |
| M.6 | Speech | Ling Six complete → save → HCW sees speech log | | | |
| M.7 | Referral | HCW referral chat → export PDF/DOCX | | | Backend running; Cloudinary or local export fallback |
| M.8 | Push | OneSignal push received on device | | | Requires OneSignal keys in backend/.env |
| M.9 | Offline | App launches with no network (cached data) | | | |

---

## Recovery session verification (2026-05-31)

**Automated:**
- `flutter pub get` — OK
- `flutter analyze` — 0 errors, 9 info lints (null-aware style suggestions only)
- `flutter test` — 1/1 passed
- `python -c "import main"` (backend venv) — OK
- `GET /health` — HTTP 200
- `POST /api/risk-score` (no JWT) — HTTP 401
- `POST /api/generate-referral-chat` (no JWT) — HTTP 401

**Deployed:**
- Firestore rules + indexes to `heartech-fyp` — success

**Code fixes applied:**
- Invite read rule: `parentUid` (+ legacy `parentId` fallback)
- Invite screen: loading + error UI for pending invites stream
- Referral chat/export: `childId` in API payloads
- Logo: `HearTechLogo` uses SVG via `flutter_svg`
- IDE: `.vscode/settings.json` points Python to `backend/.venv`

---

## Deploy commands

**Firestore rules + indexes** (already deployed 2026-05-31; re-run after rule changes):

```bash
firebase deploy --only firestore:rules,firestore:indexes --project heartech-fyp
```

**Backend** — start from `backend/` with venv:

```bash
cd backend && source .venv/bin/activate && uvicorn main:app --host 127.0.0.1 --port 8000
```

**Backend env** — copy `backend/.env.example` to `backend/.env` and set:

- `GEMINI_API_KEY`, `REFERRAL_USE_LOCAL_MODEL`
- `ONESIGNAL_APP_ID`, `ONESIGNAL_REST_API_KEY`
- `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET`

**Flutter run** (simulator uses localhost backend):

```bash
flutter run
```

**Physical device:** change `AppConstants.fastApiBaseUrl` to your Mac's LAN IP (not `127.0.0.1`).

**Local speech analysis:** install ffmpeg (`brew install ffmpeg`) and restart backend.
