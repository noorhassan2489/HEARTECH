# HearTech — Full Manual Test Guide (Sequential)

Use this guide **top to bottom, in order**. Each phase builds on the previous one, like a real clinic → parent → classroom story. Do not skip ahead until the current step passes.

**How to use each step**

| Column | Meaning |
|--------|---------|
| **#** | Step number — follow in order |
| **Role** | Who should be logged in |
| **Screen** | Page you should see |
| **Action** | What to tap / type |
| **Expected** | What should happen |
| **Pass** | Mark ✓ when OK, ✗ when fail, note bugs in **Notes** column |

---

## Before you start (one-time setup)

### Environment checklist

- [ ] Flutter app running: `flutter run` (simulator or device)
- [ ] Backend running: `cd backend && source .venv/bin/activate && uvicorn main:app --host 127.0.0.1 --port 8000`
- [ ] Firestore rules + indexes deployed to `heartech-fyp`
- [ ] `ffmpeg` installed (`brew install ffmpeg`) for speech analysis
- [ ] **Physical device only:** set backend URL to your Mac LAN IP (not `127.0.0.1`)

### Test personas (create fresh accounts or use dedicated test emails)

| Persona | Email suggestion | Role |
|---------|------------------|------|
| Dr. Sara (HCW) | `hcw.test@heartech.local` | Healthcare Worker |
| Amna (Parent) | `parent.test@heartech.local` | Parent |
| Mr. Ali (Teacher) | `teacher.test@heartech.local` | Teacher |

### Test child (created during HCW flow)

| Field | Example value |
|-------|----------------|
| Name | **Ayesha** |
| DOB | Pick age **3–5 years** bracket (e.g. 2021-06-15) |
| Gender | Female |

Keep the **handover code** written down — parent needs it in Phase 3.

---

## Phase 0 — Cold start & shared auth (Steps 1–15)

### 0A — App launch

| # | Role | Screen | Action | Expected | Pass | Notes |
|---|------|--------|--------|----------|------|-------|
| 1 | None | **Splash** (`/splash`) | Launch app fresh (kill & reopen) | HearTech logo animates; auto-navigates to role select | | |
| 2 | None | **Role Selection** (`/role-select`) | Observe UI | Logo, title "HearTech", 3 role cards: HCW / Parent / Teacher | | |
| 3 | None | Role Selection | Tap **Healthcare Worker** | Navigates to HCW Login | | |
| 4 | None | Role Selection | Back → tap **Parent** | Navigates to Parent Login | | |
| 5 | None | Role Selection | Back → tap **Teacher** | Navigates to Teacher Login | | |

### 0B — HCW registration & login

| # | Role | Screen | Action | Expected | Pass | Notes |
|---|------|--------|--------|----------|------|-------|
| 6 | None | **HCW Login** (`/login/hcw`) | Tap "Create account" / register link | Opens HCW Registration | | |
| 7 | None | **HCW Registration** (`/register/hcw`) | Fill name, email, password, title, hospital, license; submit | Account created; lands on HCW Dashboard OR login prompt | | |
| 8 | HCW | **HCW Login** | Log in with HCW credentials | Redirects to `/hcw/dashboard` (not stuck on login) | | |
| 9 | HCW | HCW Dashboard | Try opening `/login/hcw` manually (if possible) | Redirected back to dashboard (logged-in guard) | | |
| 10 | HCW | HCW Dashboard | Sign out from Profile → log in again | Session restores; dashboard loads | | |

### 0C — Parent registration & login (do NOT claim child yet)

| # | Role | Screen | Action | Expected | Pass | Notes |
|---|------|--------|--------|----------|------|-------|
| 11 | None | Role Selection → Parent | Register new parent account | Parent account created | | |
| 12 | Parent | **Parent Login** (`/login/parent`) | Log in | Lands on Parent Dashboard | | |
| 13 | Parent | **Parent Dashboard** (`/parent/dashboard`) | Observe empty state | "Claim profile" / link child CTA visible (no children yet) | | |
| 14 | Parent | Parent Dashboard | Sign out | Returns to auth flow | | |

### 0D — Teacher registration & login

| # | Role | Screen | Action | Expected | Pass | Notes |
|---|------|--------|--------|----------|------|-------|
| 15 | None | Role Selection → Teacher | Register + log in | Lands on Teacher Dashboard | | |
| 16 | Teacher | **Teacher Dashboard** (`/teacher/dashboard`) | Observe empty class | No children / empty class message | | |
| 17 | Teacher | Teacher Dashboard | Sign out | Auth flow works | | |

---

## Phase 1 — HCW: full clinical journey (Steps 18–55)

**Log in as Dr. Sara (HCW).** This phase creates Ayesha's profile and everything the parent/teacher will use later.

### 1A — HCW Dashboard & navigation

| # | Role | Screen | Action | Expected | Pass | Notes |
|---|------|--------|--------|----------|------|-------|
| 18 | HCW | **HCW Dashboard** (`/hcw/dashboard`) | Observe header | Greeting, date, avatar, notification bell | | |
| 19 | HCW | HCW Dashboard | Pull to refresh | Stats / patient list refreshes without crash | | |
| 20 | HCW | HCW Dashboard | Tap **New Screening** | Opens `/hcw/screening/new` | | |
| 21 | HCW | HCW Dashboard | Bottom nav → **Patients** | Opens `/hcw/patients` | | |
| 22 | HCW | **HCW Patients** | Observe list | Empty or existing patients; search if present | | |
| 23 | HCW | HCW Patients | Bottom nav → **Profile** | Opens `/hcw/profile` | | |
| 24 | HCW | **HCW Profile** (`/hcw/profile`) | Review fields | Email, title, hospital, license, verification badge | | |
| 25 | HCW | HCW Profile | Open **Notification Preferences** | Opens `/settings/notification-prefs` | | |
| 26 | HCW | **Notification Prefs** | Toggle a setting, save/back | Toggles persist after return | | |
| 27 | HCW | HCW Profile | Open **About HearTech** | Opens `/about` | | |
| 28 | HCW | **About** | Read content, go back | Logo, app info, disclaimer; back works | | |
| 29 | HCW | HCW Dashboard | Tap notification bell | Opens `/hcw/notifications` | | |
| 30 | HCW | **Notifications** | Observe (may be empty) | List loads; back to dashboard | | |

### 1B — New screening (anonymous → profile creation)

| # | Role | Screen | Action | Expected | Pass | Notes |
|---|------|--------|--------|----------|------|-------|
| 31 | HCW | **New Screening** — Step 1 | Enter child name **Ayesha**, DOB, gender | Age bracket auto-detected; can proceed | | |
| 32 | HCW | New Screening — Step 2 | Answer all questionnaire items (mix YES/PARTIAL/NO) | Progress bar advances; all questions answered | | |
| 33 | HCW | New Screening — Step 3 | Add clinical note (optional text) | Continue enabled | | |
| 34 | HCW | New Screening — Step 4 | Wait for processing | Loading animation; no crash | | |
| 35 | HCW | New Screening — Step 5 | View risk result | Risk level + score shown; flagged questions if medium/high | | |
| 36 | HCW | New Screening — Step 5 | Tap **Create Profile** (if medium/high) OR proceed for low | Moves to profile/handover step | | |
| 37 | HCW | New Screening — Step 6 | View **handover code** | 6-character code displayed; copy if available | | |
| 38 | HCW | New Screening | **Write down handover code:** ZUMALZ | — | | |

### 1C — HCW child profile (all tabs)

| # | Role | Screen | Action | Expected | Pass | Notes |
|---|------|--------|--------|----------|------|-------|
| 39 | HCW | Navigate to **Ayesha's profile** (`/hcw/child/:childId`) | Open from dashboard/patients | Profile loads with avatar, risk gauge, tabs | | |
| 40 | HCW | Child profile — **Overview** | Review content | Risk score, breakdown chips, medical flags, quick actions | | |
| 41 | HCW | Child profile — **Screenings** | View screening history | At least one screening entry from step 31–35 | | |
| 42 | HCW | Child profile — **Referrals** | View tab | Empty or draft list; no crash | | |
| 43 | HCW | Child profile — **Observations** | View tab | Empty (no teacher yet) or placeholder | | |
| 44 | HCW | Child profile — **Notes** | Add HCW note: "Initial screening complete" | Note saves; visible in list | | |
| 45 | HCW | Child profile — Notes | Toggle **Visible to Parent** ON; save another note | Parent-visible note created | | |
| 46 | HCW | Child profile — Notes | Toggle **Visible to Teacher** (if enabled) | Teacher visibility option works | | |
| 47 | HCW | Child profile — **Speech** | View tab | Empty or prior logs; no crash | | |

### 1D — Follow-up screening

| # | Role | Screen | Action | Expected | Pass | Notes |
|---|------|--------|--------|----------|------|-------|
| 48 | HCW | Child profile Overview | Tap **Follow-up Screening** | Opens `/hcw/child/:childId/screening/follow-up` | | |
| 49 | HCW | **Follow-up Screening** | Complete shortened questionnaire | New screening saved; risk may update | | |
| 50 | HCW | Child profile — Screenings | Confirm second entry | Two screenings listed with dates | | |

### 1E — Referral clinical assistant (HCW only)

| # | Role | Screen | Action | Expected | Pass | Notes |
|---|------|--------|--------|----------|------|-------|
| 51 | HCW | Child profile | Tap **Clinical Assistant** / Referral chat | Opens `/referral-chat/:childId` | | |
| 52 | HCW | **Referral Chat** | Tap suggestion chip OR type "Generate referral letter" | Loading spinner; AI response appears (may take 1–3 min) | | |
| 53 | HCW | Referral Chat | Tap **Export PDF** | Share sheet opens with PDF file | | |
| 54 | HCW | Referral Chat | Tap **Export Word** | Share sheet opens with DOCX file | | |
| 55 | HCW | Child profile — Referrals | View tab | Draft referral appears with letter text | | |
| 56 | HCW | Referrals tab | **Do NOT finalize yet** (parent not linked) | Finalize blocked or warns "link parent first" | | |

**HCW phase complete.** Sign out or leave app running — switch to Parent.

---

## Phase 2 — Parent: claim, monitor, invite (Steps 57–95)

**Log in as Amna (Parent).**

### 2A — Claim child with handover code

| # | Role | Screen | Action | Expected | Pass | Notes |
|---|------|--------|--------|----------|------|-------|
| 57 | Parent | **Parent Dashboard** | Tap **Claim Profile** / link child | Opens `/parent/claim-profile` | | |
| 58 | Parent | **Claim Profile** | Enter handover code from Step 38 | Code accepted | | |
| 59 | Parent | Claim Profile | Confirm link | Success message; returns to dashboard | | |
| 60 | Parent | Parent Dashboard | Observe | **Ayesha** card visible with risk badge | | |
| 61 | Parent | Parent Dashboard | Bottom nav → **My Children** | Opens `/parent/children` | | |
| 62 | Parent | **My Children** | Tap Ayesha | Opens `/parent/child/:childId` | | |

### 2B — Parent child profile (all tabs)

| # | Role | Screen | Action | Expected | Pass | Notes |
|---|------|--------|--------|----------|------|-------|
| 63 | Parent | Child profile — **Overview** | Review | Risk info, HCW name, handover status claimed | | |
| 64 | Parent | Child profile — **Screenings** | View | HCW screenings visible (read-only) | | |
| 65 | Parent | Child profile — **Referrals** | View | HCW draft visible (read-only) or empty | | |
| 66 | Parent | Child profile — **Observations** | View | Empty until teacher submits | | |
| 67 | Parent | Child profile — **Notes** | View HCW notes | Notes marked public by HCW appear (**no flash/disappear**) | | |
| 68 | Parent | Child profile — Notes | Pull to refresh | Notes reload correctly | | |
| 69 | Parent | Child profile — **Speech** | View | Empty until speech games completed | | |

### 2C — Parent home screening

| # | Role | Screen | Action | Expected | Pass | Notes |
|---|------|--------|--------|----------|------|-------|
| 70 | Parent | Parent Dashboard or child profile | Tap **Home Screening** | Opens `/parent/screening` | | |
| 71 | Parent | **Home Screening** | Select Ayesha if prompted | Questionnaire loads for correct age bracket | | |
| 72 | Parent | Home Screening | Complete all questions | Risk score calculated via backend | | |
| 73 | Parent | Home Screening | Submit / finish | Success; aggregate risk may update on child profile | | |
| 74 | HCW | *(switch account)* HCW Notifications | Check for home screening alert | HCW receives notification (type HCW-05) | | |

### 2D — Invite teacher

| # | Role | Screen | Action | Expected | Pass | Notes |
|---|------|--------|--------|----------|------|-------|
| 75 | Parent | Child profile or dashboard | Tap **Invite Teacher** | Opens `/parent/invite-teacher/:childId` | | |
| 76 | Parent | **Invite Teacher** | Enter Mr. Ali's registered email | Invite sends; success snackbar | | |
| 77 | Parent | Invite Teacher | Observe **Pending Invitations** | Pending invite card with email + countdown | | |
| 78 | Parent | Invite Teacher | *(optional)* Cancel invite → re-send | Cancel works; can send fresh invite | | |

### 2E — Parent speech games hub

| # | Role | Screen | Action | Expected | Pass | Notes |
|---|------|--------|--------|----------|------|-------|
| 79 | Parent | Parent Dashboard | Bottom nav → **Speech Games** | Opens `/parent/speech-games` | | |
| 80 | Parent | **Speech Games Hub** | Select Ayesha (if multiple children) | Game cards enabled | | |
| 81 | Parent | Speech Games Hub | Observe game cards | **Show & Tell** and **Ling Six** visible | | |

**Parent setup complete.** Switch to Teacher for invite acceptance.

---

## Phase 3 — Teacher: invites, class, observations (Steps 82–110)

**Log in as Mr. Ali (Teacher).** Use the **same email** parent invited.

### 3A — Accept invite

| # | Role | Screen | Action | Expected | Pass | Notes |
|---|------|--------|--------|----------|------|-------|
| 82 | Teacher | **Teacher Dashboard** | Look for pending invite banner/card | Invite for Ayesha visible | | |
| 83 | Teacher | Teacher Dashboard | Tap **Pending Invites** OR nav to `/teacher/invites` | Opens **Pending Invites** screen | | |
| 84 | Teacher | **Pending Invites** | View invite details | Child name, parent name, expiry countdown | | |
| 85 | Teacher | Pending Invites | Tap **Accept** | Success; Ayesha added to class | | |
| 86 | Teacher | Teacher Dashboard | Observe | Ayesha appears in classroom grid/list | | |
| 87 | Parent | *(switch)* Parent Notifications | Check accept notification | Parent receives PAR-04 (teacher accepted) | | |

### 3B — Teacher navigation & class

| # | Role | Screen | Action | Expected | Pass | Notes |
|---|------|--------|--------|----------|------|-------|
| 88 | Teacher | Teacher Dashboard | Bottom nav → **My Class** | Opens `/teacher/my-class` | | |
| 89 | Teacher | **My Class** | Tap Ayesha | Opens `/teacher/child/:childId` | | |
| 90 | Teacher | Teacher Dashboard | Tap notification bell | Opens `/teacher/notifications` | | |
| 91 | Teacher | Teacher Dashboard | Bottom nav → **Profile** | Opens `/teacher/profile` | | |
| 92 | Teacher | **Teacher Profile** | Open Notification Prefs + About | Same as HCW; role-appropriate labels | | |

### 3C — Teacher child profile

| # | Role | Screen | Action | Expected | Pass | Notes |
|---|------|--------|--------|----------|------|-------|
| 93 | Teacher | **Teacher Child Profile** | Overview tab | Limited info: risk badge, HCW notes (if shared), no sensitive edit | | |
| 94 | Teacher | Teacher Child Profile — **Observations** | View | Empty or prior observations | | |
| 95 | Teacher | Teacher Child Profile | Tap **New Observation** | Opens `/teacher/observation?childId=...` | | |
| 96 | Teacher | **Teacher Observation** | Fill observation form; submit | Saved; returns to profile | | |
| 97 | Teacher | Teacher Child Profile — Observations | View list | **Your observation stays visible** (no flash/disappear) | | |
| 98 | Parent | *(switch)* Parent Notifications | Check observation alert | PAR-07 notification received | | |
| 99 | Parent | Parent Notifications | Tap notification | Opens child profile **Observations** tab (`?tab=observations`) | | |
| 100 | Parent | Child profile — Observations | View | Teacher observation visible | | |

### 3D — Decline invite scenario (optional second child)

| # | Role | Screen | Action | Expected | Pass | Notes |
|---|------|--------|--------|----------|------|-------|
| 101 | Parent | Invite another teacher (different email) | Send invite | Pending on parent side | | |
| 102 | Teacher | Pending Invites | Tap **Decline** | Invite declined | | |
| 103 | Parent | Notifications | Check | PAR-05 decline notification | | |

---

## Phase 4 — Speech exercises (Steps 104–125)

**Requires mic permission + backend + ffmpeg.**

### 4A — Show & Tell (Parent)

| # | Role | Screen | Action | Expected | Pass | Notes |
|---|------|--------|--------|----------|------|-------|
| 104 | Parent | Speech Games Hub | Tap **Show & Tell** | Opens `/speech/show-and-tell/:childId` | | |
| 105 | Parent | **Show & Tell** | Grant microphone permission | Recording UI enabled | | |
| 106 | Parent | Show & Tell | Deny mic → observe | Clear message to enable mic in Settings | | |
| 107 | Parent | Show & Tell | Pick category / image prompt | Game content loads (photo or emoji fallback) | | |
| 108 | Parent | Show & Tell | Record short clip → Analyze | Transcript + clarity score returned | | |
| 109 | Parent | Show & Tell | Save session | Success; returns to hub or shows saved state | | |
| 110 | Parent | Show & Tell | *(edge)* If backend/Whisper down | Save **blocked** with clear error (no fake score saved) | | |

### 4B — Ling Six (Parent)

| # | Role | Screen | Action | Expected | Pass | Notes |
|---|------|--------|--------|----------|------|-------|
| 111 | Parent | Speech Games Hub | Tap **Ling Six** | Opens `/speech/ling-six/:childId` | | |
| 112 | Parent | **Ling Six** | Play each frequency sound | Audio plays for /m/, /oo/, /ee/, /ah/, /sh/, /s/ | | |
| 113 | Parent | Ling Six | Mark responses per sound | Progress through all 6 | | |
| 114 | Parent | Ling Six | Complete test → view result | Overall pass/watch/refer result shown | | |
| 115 | Parent | Ling Six | Save log | Success message | | |

### 4C — Teacher speech games

| # | Role | Screen | Action | Expected | Pass | Notes |
|---|------|--------|--------|----------|------|-------|
| 116 | Teacher | Teacher Dashboard | Navigate to speech games (`/teacher/speech-games`) | Hub opens with Ayesha selected (single child) | | |
| 117 | Teacher | Speech Games Hub | Complete Show & Tell OR Ling Six for Ayesha | Session saves under teacher as conductor | | |
| 118 | Teacher | Speech Games Hub | Tap back | Returns to `/teacher/speech-games` route (not wrong dashboard) | | |

### 4D — Verify speech logs (HCW + Parent)

| # | Role | Screen | Action | Expected | Pass | Notes |
|---|------|--------|--------|----------|------|-------|
| 119 | HCW | Ayesha profile — **Speech** tab | Refresh | Show & Tell + Ling Six entries with transcript, clarity, game type | | |
| 120 | Parent | Ayesha profile — **Speech** tab | View | Same sessions visible | | |
| 121 | Teacher | Teacher child profile — **Speech** tab | View | Sessions visible (limited detail OK) | | |

---

## Phase 5 — Referral finalize & share (Steps 122–135)

**Switch back to HCW.**

| # | Role | Screen | Action | Expected | Pass | Notes |
|---|------|--------|--------|----------|------|-------|
| 122 | HCW | Ayesha profile — Referrals | Open draft from Phase 1 | Letter text + export options visible | | |
| 123 | HCW | Referrals tab | Tap **Finalize** / share with parent | Confirmation dialog | | |
| 124 | HCW | Referrals tab | Confirm finalize | Referral marked finalized; PDF URL saved if export ran | | |
| 125 | Parent | *(switch)* Notifications | Check | PAR-08 referral available notification | | |
| 126 | Parent | Child profile — Referrals | View finalized referral | Read-only card; tap to preview | | |
| 127 | Parent | **Referral Preview** (`/referral-preview/:childId/:referralId`) | Open PDF / letter | PDF viewer or letter text displays | | |
| 128 | HCW | Referrals tab | Toggle **Share with teacher** (if present) | Teacher can see referral on their profile | | |
| 129 | Teacher | Teacher child profile | Check referrals section | Shared referral visible (read-only) | | |

---

## Phase 6 — Notifications deep dive (Steps 130–140)

Test each notification type you triggered in earlier phases:

| # | Role | Screen | Action | Expected | Pass | Notes |
|---|------|--------|--------|----------|------|-------|
| 130 | HCW | `/hcw/notifications` | Tap home screening alert (HCW-05) | Navigates to relevant child/profile | | |
| 131 | Parent | `/parent/notifications` | Tap teacher accepted (PAR-04) | Opens sensible destination | | |
| 132 | Parent | Notifications | Tap teacher observation (PAR-07) | Opens Observations tab | | |
| 133 | Parent | Notifications | Tap referral (PAR-08) | Opens referral preview or referrals tab | | |
| 134 | Any | Notifications | Swipe to dismiss one item | Item removed; does not reappear on refresh | | |
| 135 | Any | Notifications | Tap unread item | Marked read; badge count decreases | | |
| 136 | Any | Notification Prefs | Disable a category → trigger that event | Respects preference (if implemented server-side) | | |

---

## Phase 7 — Role guards & security (Steps 137–150)

| # | Role | Screen | Action | Expected | Pass | Notes |
|---|------|--------|--------|----------|------|-------|
| 137 | Parent | Try opening HCW dashboard URL | Navigate to `/hcw/dashboard` | Redirected to parent dashboard | | |
| 138 | Teacher | Try opening `/referral-chat/:childId` | As teacher | Redirected away (HCW-only) | | |
| 139 | HCW | Try opening `/speech/show-and-tell/:childId` | As HCW | Redirected away (parent/teacher only) | | |
| 140 | Parent | Try opening `/teacher/dashboard` | As parent | Redirected to parent dashboard | | |
| 141 | None | Kill backend server | Run home screening | Graceful error (not silent hang forever) | | |
| 142 | None | Turn off Wi‑Fi mid-session | Browse cached child profile | Offline: cached data or clear error message | | |

---

## Phase 8 — Profile & settings (all roles) (Steps 143–155)

Repeat for **HCW, Parent, Teacher** where applicable:

| # | Role | Screen | Action | Expected | Pass | Notes |
|---|------|--------|--------|----------|------|-------|
| 143 | Each | Profile screen | Edit profile fields (if editable) | Saves to Firestore | | |
| 144 | HCW | HCW Profile | Upload / view license document | Cloudinary upload works | | |
| 145 | Each | Profile | Change profile photo | Photo updates on dashboard avatar | | |
| 146 | Each | Notification Prefs | Toggle all switches | UI reflects state | | |
| 147 | Each | About | Read disclaimer | Medical disclaimer visible | | |
| 148 | Each | Profile | Sign out | Returns to splash/role select; cannot access protected routes | | |
| 149 | Each | After sign out | Press back | Does not return to authenticated screen | | |

---

## Phase 9 — HCW patients list & edge cases (Steps 156–165)

| # | Role | Screen | Action | Expected | Pass | Notes |
|---|------|--------|--------|----------|------|-------|
| 150 | HCW | **HCW Patients** | Search/filter (if UI present) | Filters Ayesha correctly | | |
| 151 | HCW | HCW Patients | Tap patient row | Opens correct child profile | | |
| 152 | HCW | HCW Dashboard | Stats cards | Patient count, risk breakdown match reality | | |
| 153 | Parent | Parent Dashboard | Multiple children (add 2nd via another code) | Both cards show; speech hub prompts selection | | |
| 154 | Teacher | Teacher Dashboard | Observation streak / tips card | Tip rotates; no crash | | |
| 155 | Teacher | My Class | Remove self from class (if option exists) | Teacher unlinked; child removed from class | | |

---

## Phase 10 — Push notifications (optional) (Steps 166–168)

Requires OneSignal keys in `backend/.env` and real device (not simulator):

| # | Role | Screen | Action | Expected | Pass | Notes |
|---|------|--------|--------|----------|------|-------|
| 166 | Parent | Device home screen | Trigger event (e.g. teacher observation) while app backgrounded | OS push banner appears | | |
| 167 | Any | Tap push notification | App opens to correct screen | Deep link works | | |
| 168 | Any | Notification Prefs | Disable push | No OS banner for disabled types | | |

---

## Final sign-off

| Area | Total steps | Passed | Failed | Blocker notes |
|------|-------------|--------|--------|---------------|
| Auth & launch (0) | 17 | | | |
| HCW journey (1) | 39 | | | |
| Parent journey (2) | 25 | | | |
| Teacher journey (3) | 22 | | | |
| Speech (4) | 18 | | | |
| Referrals (5) | 8 | | | |
| Notifications (6) | 7 | | | |
| Security (7) | 6 | | | |
| Settings (8) | 7 | | | |
| Edge cases (9) | 6 | | | |
| Push (10) | 3 | | | |
| **TOTAL** | **~168** | | | |

---

## Quick reference — every screen in the app

| Route | Screen | Roles |
|-------|--------|-------|
| `/splash` | Splash | All |
| `/role-select` | Role Selection | All |
| `/login/hcw` | HCW Login | — |
| `/login/parent` | Parent Login | — |
| `/login/teacher` | Teacher Login | — |
| `/register/hcw` | HCW Registration | — |
| `/register/parent` | Parent Registration | — |
| `/register/teacher` | Teacher Registration | — |
| `/hcw/dashboard` | HCW Dashboard | HCW |
| `/hcw/patients` | HCW Patients | HCW |
| `/hcw/notifications` | Notifications | HCW |
| `/hcw/profile` | HCW Profile | HCW |
| `/hcw/screening/new` | New Screening | HCW |
| `/hcw/child/:id` | Child Profile (6 tabs) | HCW |
| `/hcw/child/:id/screening/follow-up` | Follow-up Screening | HCW |
| `/referral-chat/:childId` | Referral Chat | HCW |
| `/referral-preview/:childId/:referralId` | Referral Preview | HCW, Parent |
| `/parent/dashboard` | Parent Dashboard | Parent |
| `/parent/children` | My Children | Parent |
| `/parent/child/:id` | Child Profile (6 tabs) | Parent |
| `/parent/claim-profile` | Claim Profile | Parent |
| `/parent/screening` | Home Screening | Parent |
| `/parent/invite-teacher/:childId` | Invite Teacher | Parent |
| `/parent/speech-games` | Speech Games Hub | Parent |
| `/parent/notifications` | Notifications | Parent |
| `/parent/profile` | Parent Profile | Parent |
| `/teacher/dashboard` | Teacher Dashboard | Teacher |
| `/teacher/my-class` | My Class | Teacher |
| `/teacher/child/:id` | Teacher Child Profile | Teacher |
| `/teacher/observation` | New Observation | Teacher |
| `/teacher/invites` | Pending Invites | Teacher |
| `/teacher/speech-games` | Speech Games Hub | Teacher |
| `/teacher/notifications` | Notifications | Teacher |
| `/teacher/profile` | Teacher Profile | Teacher |
| `/speech/show-and-tell/:childId` | Show & Tell | Parent, Teacher |
| `/speech/ling-six/:childId` | Ling Six | Parent, Teacher |
| `/settings/notification-prefs` | Notification Preferences | All |
| `/about` | About HearTech | All |

---

## Bug report template (copy per failure)

```
Step #: ___
Role: ___
Screen: ___
Action taken: ___
Expected: ___
Actual: ___
Screenshot/log: ___
Severity: Blocker / Major / Minor
```

---

*Last updated: recovery session 2026-05-31. Run backend + Firestore before starting Phase 1.*
