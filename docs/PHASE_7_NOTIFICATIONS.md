# PHASE 7: Complete Notification System (HearTech — current scope)

**Goal:** All **28 typed notifications** (`HCW-01` … `TCH-08`) work end-to-end:

- **In-app centre** shows items with correct colors, read state, swipe actions, and navigation
- **Push** arrives on a **physical device** via **OneSignal** (when backend env vars are set)
- **APScheduler cron jobs** in `backend/cron_jobs.py` fire on schedule
- **Prefs** in `lib/features/settings/screens/notification_prefs_screen.dart` control optional pushes

**Important — current architecture (do not ignore):**

Notifications are sent through **three different backend paths** today:

| Path | File | Firestore in-app | OneSignal push | Used by |
|------|------|------------------|----------------|---------|
| `NotificationService.send()` | `backend/services/notification_service.py` | ✅ | ✅ (if env configured) | `POST /api/notifications/send` (Flutter `fastApi.sendNotification`) |
| `_fire_notification()` | `backend/routers/invites.py`, `profile.py` | ✅ | ❌ | Invites, claim profile, remove HCW/teacher |
| `_write_notification()` | `backend/cron_jobs.py` | ✅ | ❌ | All 5 cron jobs |

**Phase 7 completion = consolidate so every trigger uses `NotificationService.send()` once** (no duplicate OneSignal calls, no Firestore-only cron/invite paths).

---

## PART A — FastAPI notification service

**File:** `backend/services/notification_service.py` (already exists — extend/harden, don’t recreate)

**Class:** `NotificationService` with async method:

```python
async def send(
    uid: str,
    notif_type: str,
    title: str,
    body: str,
    data: dict = None,
    priority: str = "normal",
    navigation_route: str = None,
    related_child_id: str = None,
    related_invite_id: str = None,
    related_referral_id: str = None,
)
```

**Step 1 — Firestore write**

`/notifications/{uid}/items/{notifId}` with:

- `notifId`, `type`, `title`, `body`, `read: false`, `priority`
- `createdAt` (server time)
- `relatedChildId`, `relatedInviteId`, `relatedReferralId` (when provided)
- `navigationRoute` (GoRouter path string)

**Step 2 — Prefs check**

- Read `users/{uid}.notificationPrefs`
- Pref keys use **underscores**: `HCW_05`, `PAR_09`, etc. (`notif_type.replace("-", "_")`)
- If `priority != "high"` and pref exists and is `false` → **skip push only** (Firestore write already done)
- **Always-on (cannot disable push):** `HCW-05` and `PAR-04` when used as **risk-elevation alerts** — must be sent with `priority="high"`

**Step 3 — OneSignal REST API**

- URL: `https://onesignal.com/api/v1/notifications`
- Env vars: `ONESIGNAL_APP_ID`, `ONESIGNAL_REST_API_KEY` (backend `.env`)
- Body uses **`include_aliases: { "external_id": [uid] }`** (Firebase UID = OneSignal external id)
- `data`: `{ type, navigationRoute, ...extra }`
- `priority`: 10 if high, else 5

**Also expose:** `POST /api/notifications/send` in `backend/routers/notifications.py` (already exists — keep as the single Flutter entry point).

**Refactor required:** Replace `_fire_notification()` in `invites.py` / `profile.py` and `_write_notification()` in `cron_jobs.py` with `await NotificationService.send(...)`.

---

## PART B — All 28 notification triggers (as implemented in HearTech today)

Wire/migrate each trigger to `NotificationService.send()`.

**Navigation routes must match** `lib/core/router/app_router.dart` (`Routes.*`).

### HCW notifications (10)

| ID | Trigger (actual code location) | Title / body (current or intended) | Navigate to | Push |
|----|-------------------------------|-------------------------------------|-------------|------|
| **HCW-01** | `cron_jobs.py` Job 1 (hourly) — unclaimed child, code expires ≤2h | Handover Code Expiring… | `/hcw/child/{childId}` | Yes |
| **HCW-02** | `profile.py` `/api/claim-profile` success | Profile Claimed… | `/hcw/child/{childId}` | Yes |
| **HCW-03** | `invites.py` `/api/respond-invite` accept, `inviteType=teacher` | Teacher Linked… | `/hcw/child/{childId}` | Yes |
| **HCW-04** | **GAP:** not fired from Flutter today. Should fire when teacher submits observation → notify linked HCW(s) | New Teacher Observation… | `/hcw/child/{childId}?tab=observations` | Yes |
| **HCW-05** | **Two uses in app (same type code):** (1) `parent_home_screening_screen.dart` after home screening → HCW; (2) `teacher_observation_screen.dart` when **risk level changes** → HCW, `priority=high` | (1) Home Screening Completed / (2) Risk Level Elevated | `/hcw/child/{childId}` | Yes; (2) always-on |
| **HCW-06** | `cron_jobs.py` Job 2 (daily 08:00) — medium/high risk, last screening 90+ days ago | Follow-Up Overdue… | `/hcw/child/{childId}` or follow-up route | Yes; pref-toggleable |
| **HCW-07** | **GAP:** trigger helpers exist in `notifications.py` but **not wired**. Referral finalize uses **PAR-08** to parent instead | (Reserved / align or remove) | — | — |
| **HCW-08** | `speech_session_notifications.dart` after speech save (parent- or teacher-led → HCW) | Speech Session Completed… | `/hcw/child/{childId}` | Yes |
| **HCW-09** | `invites.py` `/api/remove-hcw` when **parent removes HCW** | Access Removed… | `/hcw/patients` | Yes |
| **HCW-10** | **GAP:** admin/license verification flow not fully wired | Account Verified… | `/hcw/dashboard` | Yes |

**New (post-handover) — parent re-links HCW:**

- **`POST /api/invite-hcw`** → currently writes Firestore via `_fire_notification` with `type: "invite"` (not a numbered type).
- **Phase 7:** either map to **TCH-01-style HCW invite** (recommend new doc type e.g. **`HCW-11`** or reuse **`TCH-01` pattern** with `inviteType=hcw`) and navigate to **`/hcw/invites`**.
- On accept: parent gets notification (currently mislabeled **PAR-04** “Healthcare Worker Linked”) — consider dedicated copy/type.

### Parent notifications (10)

| ID | Trigger | Notes | Navigate to |
|----|---------|-------|-------------|
| **PAR-01** | **GAP:** helper exists; not fired from HCW screening completion in Flutter | Was “in-app only” in old spec — decide: notify parent when HCW creates/links child, or drop | `/parent/child/{childId}` |
| **PAR-02** | `child_profile_screen.dart` HCW saves note with `isPublic=true` | New Note from HCW… | `/parent/child/{childId}` |
| **PAR-03** | **GAP:** no manual risk-override endpoint in app | **Remove from prompt** unless you add that feature | — |
| **PAR-04** | **Two uses:** (1) `teacher_observation_screen.dart` **risk level change** → parent, `priority=high`; (2) `invites.py` teacher **accepted** → parent | Always-on for (1); (2) is normal priority | `/parent/child/{childId}` |
| **PAR-05** | `invites.py` teacher **declined** | Invite Declined… | `/parent/child/{childId}` |
| **PAR-06** | `cron_jobs.py` Job 5 — teacher invite expiring ≤6h | Teacher Invite Expiring… | `/parent/invite-teacher/{childId}` |
| **PAR-07** | `teacher_observation_screen.dart` observation saved | New Classroom Observation… | `/parent/child/{childId}?tab=observations` |
| **PAR-08** | (1) `child_referrals_tab.dart` referral finalized; (2) `speech_session_notifications.dart` teacher-led speech → parent | Referral Available / Speech Session Complete | referral preview or child profile |
| **PAR-09** | (1) `cron_jobs.py` Job 4 home screening reminder; (2) **also misused** in `child_profile_teacher_screen.dart` for teacher note → parent | Fix (2): use a different type or in-app SnackBar only | `/parent/screening` |
| **PAR-10** | `invites.py` `/api/remove-teacher` and **HCW self-unlink** | Teacher/HCW Unlinked — **in-app Firestore only, no push** (keep) | `/parent/child/{childId}` |

### Teacher notifications (8)

| ID | Trigger | Navigate to |
|----|---------|-------------|
| **TCH-01** | `invites.py` `/api/invite-teacher` | `/teacher/invites` |
| **TCH-02** | `cron_jobs.py` Job 5 — pending teacher invite ≤6h | `/teacher/invites` |
| **TCH-03** | **GAP:** not fired when linked child risk changes | `/teacher/child/{childId}` |
| **TCH-04** | `child_profile_screen.dart` HCW note with `isTeacherVisible=true` | `/teacher/child/{childId}` |
| **TCH-05** | **In-app SnackBar only** after teacher observation (no push) — keep | — |
| **TCH-06** | `invites.py` `/api/remove-teacher` (parent removed teacher) | `/teacher/dashboard` |
| **TCH-07** | `cron_jobs.py` Job 3 — no observation 14+ days | `/teacher/child/{childId}` |
| **TCH-08** | **GAP for speech:** prefs mention “parent completed speech” but parent-led speech **does not notify teachers** (by design — privacy). TCH-08 trigger helper = access removed, not speech | `/teacher/dashboard` |

**Removed from original prompt (not in app):**

- `PAR-03` manual HCW risk override endpoint
- `notification_centre_screen.dart` / `notification_preferences_screen.dart` (wrong filenames)
- `scheduler.py` (use **`backend/cron_jobs.py`**, started from `main.py` `@app.on_event("startup")`)
- `sticky_headers` date grouping (not implemented; optional enhancement)
- Cron field `handoverCode.expiryWarningSent` (not in Firestore model today — add or accept duplicate hourly alerts until fixed)
- Job 2 logic “14 days high / 30 days medium” — **current code uses 90 days** for medium/high; align spec to code or fix code

---

## PART C — APScheduler cron jobs

**File:** `backend/cron_jobs.py` (not `scheduler.py`)

**Scheduler:** `BackgroundScheduler`, started in `setup_cron_jobs()` from `main.py` startup.

| Job | Schedule | Notification | Gap to fix |
|-----|----------|--------------|------------|
| 1 | Every 1h | HCW-01 | Migrate to `NotificationService.send`; add dedupe flag on `handoverCode` |
| 2 | Daily 08:00 | HCW-06 | Currently 90-day rule; migrate to `NotificationService.send`; set `nextScreeningReminderSent` dedupe |
| 3 | Daily 09:00 | TCH-07 | Migrate to `NotificationService.send`; set `observationReminderSent` dedupe |
| 4 | Daily 10:00 | PAR-09 | Migrate to `NotificationService.send`; respect prefs |
| 5 | Every 1h | TCH-02 + **PAR-06** to parent | Extend to **HCW invites** (`inviteType=hcw`) expiring ≤6h |

**Physical device testing:** backend must run with `--host 0.0.0.0`; Flutter uses `--dart-define=FASTAPI_BASE_URL=http://<MAC_IP>:8000` for API/cron-triggered pushes.

---

## PART D — In-app notification centre (Flutter)

**File:** `lib/features/notifications/screens/notifications_screen.dart` (not `notification_centre_screen.dart`)

**Routes:**

- HCW: `/hcw/notifications` → `NotificationsScreen(role: 'hcw')`
- Parent: `/parent/notifications`
- Teacher: `/teacher/notifications`

**Already implemented:**

- Stream from Firestore `/notifications/{uid}/items/`
- Unread = pale teal card background; read = white
- Left border color via `NotificationModel.colorKey` in `lib/shared/models/notification_model.dart`
- Mark all read, tap → mark read + `context.push(navigationRoute)`
- Swipe right = mark read; swipe left = delete + Undo SnackBar
- `BellIconWithBadge` on dashboards → role notifications route

**Color map (use `notification_model.dart` — source of truth):**

- **Teal:** HCW-02, HCW-07, HCW-08, PAR-01, PAR-02, PAR-03, PAR-07, PAR-08, TCH-04, TCH-08
- **Red:** HCW-05, HCW-09, PAR-04, PAR-06, TCH-03, TCH-06
- **Orange:** HCW-01, HCW-06, PAR-09, PAR-10, TCH-02, TCH-07
- **Green:** HCW-10, PAR-05, TCH-05
- **Purple:** HCW-03, HCW-04, TCH-01

**Optional enhancements (not required for “complete”):** Today/Yesterday/Earlier sticky headers; hide “Mark all read” when count=0.

**Deep links to verify:**

- PAR-07 → `?tab=observations` fallback already in `notifications_screen.dart`
- PAR-08 referral → `Routes.referralPreviewFor(...)`
- HCW invite → `/hcw/invites`

---

## PART E — Notification preferences

**File:** `lib/features/settings/screens/notification_prefs_screen.dart`

**Route:** `/settings/notification-prefs` (from each role’s profile settings)

**Storage:** `users/{uid}.notificationPrefs.{HCW_06: bool, ...}`

**Already implemented:** role-specific sections (HCW / parent / teacher), Always On chips for **HCW-05** and **PAR-04**, immediate Firestore toggle on change.

**Add to prefs (missing today):**

- Parent: **HCW invite accepted/declined** (if you add typed notifications for `/api/invite-hcw`)
- HCW: **New patient invite** (parent → HCW)
- HCW: **HCW-09** already listed as “HCW Access Removed”

---

## PART F — OneSignal Flutter setup

**Package:** `onesignal_flutter`

**App ID:** `AppConstants.oneSignalAppId` (`lib/core/constants/app_constants.dart`, overridable via `--dart-define=ONESIGNAL_APP_ID=...`)

**Current state:**

- `lib/services/notification_service.dart` — `initialize()`, `onLogin(uid, role)`, `onLogout()`
- `lib/services/firebase_auth_service.dart` — `registerOneSignal()` on login/register; `signOut()` calls `onLogout()`
- **`lib/main.dart` — `NotificationService.initialize()` is still COMMENTED OUT** → enable for push on device

**Required for push on physical device:**

1. Uncomment `await NotificationService.initialize()` in `main.dart`
2. Set backend `.env`: `ONESIGNAL_APP_ID`, `ONESIGNAL_REST_API_KEY`
3. OneSignal dashboard: enable **External ID** / alias targeting for Firebase UIDs
4. After login, confirm `OneSignal.login(uid)` + tag `role` (already in `registerOneSignal`)

**Add (not in app yet):** push tap handler in `main.dart` or router:

```dart
OneSignal.Notifications.addClickListener((event) {
  final route = event.notification.additionalData?['navigationRoute'];
  if (route != null && route.isNotEmpty) {
    // use GoRouter — e.g. ref.read(routerProvider).go(route)
  }
});
```

Use **`NotificationService.onLogin` / `onLogout`** (not raw `OneSignal.login` scattered outside `FirebaseAuthService`).

---

## PART G — Invite flows (teacher + HCW)

| Flow | API | Parent UI | Invitee UI | Accept API |
|------|-----|-----------|------------|------------|
| Teacher | `POST /api/invite-teacher` | `/parent/invite-teacher/:childId` | `/teacher/invites` | `POST /api/respond-invite` + `teacherUid` |
| HCW (new) | `POST /api/invite-hcw` | `/parent/invite-hcw/:childId` | `/hcw/invites` (`PendingInvitesScreen(role: 'hcw')`) | `POST /api/respond-invite` + `hcwUid` |

Ensure invite expiry cron + push covers **both** `inviteType: teacher` and `inviteType: hcw`.

---

## WHEN DONE — deliverables

1. **List every file modified** (expect at minimum):
   `notification_service.py`, `cron_jobs.py`, `invites.py`, `profile.py`, `main.dart`, any gap fixes in Flutter trigger files

2. **Your action items:**
   - Uncomment OneSignal init in `main.dart`
   - Set backend OneSignal env vars
   - Full app restart (not hot reload) after router/OneSignal changes
   - Test on **physical device** with backend on LAN IP
   - Optional: `firebase deploy --only firestore:rules,firestore:indexes` if invite/HCW queries fail

3. **Verification checklist (28 types):**
   - [ ] Each type creates Firestore item under correct uid
   - [ ] Push received on phone when pref enabled
   - [ ] Push skipped for PAR-10 / in-app-only types
   - [ ] HCW-05 / PAR-04 high-priority risk alerts ignore prefs
   - [ ] Tap push opens correct GoRouter path
   - [ ] Cron jobs log in backend terminal without errors

4. **Known inconsistencies to resolve during Phase 7 (document in PR):**
   - Same type codes reused for different events (HCW-05, PAR-04, PAR-08, PAR-09)
   - `_fire_notification` / cron bypass OneSignal
   - HCW invite uses raw `type: "invite"`
   - `notifications.py` trigger helpers mostly unused — either wire or delete

**Say:** `PHASE 7 COMPLETE — READY FOR REVIEW`
