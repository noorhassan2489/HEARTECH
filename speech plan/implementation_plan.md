# Phase 6: Speech and Sound Modules — Full End-to-End Implementation

Build Show and Tell and Ling Six speech games with real audio recording, FastAPI Whisper transcription, and Firestore persistence.

## Proposed Changes

### Backend — FastAPI Speech Endpoints

#### [MODIFY] [speech.py](file:///Users/noorhassan/HEARTECH%20FYP/HEARTECH/backend/routers/speech.py)
Complete rewrite of all three endpoints:

1. **POST `/api/analyze-speech`** — Accept multipart `.wav`, transcribe with Whisper (loaded at startup), fuzzy-match with `rapidfuzz`, phoneme analysis with `phonemizer`, return `transcript`, `matchScore`, `clarityRating`, `phonemesCorrect`, `phonemesMissed`, `feedbackMessage`. Also fires HCW-08 notification to linked HCWs.

2. **POST `/api/ling-six-analysis`** — Accept `{results: [{sound, round1heard, round2heard}], childId}`, score based on Round 2 heard count (6=Pass, 4-5=Watch, ≤3=Refer), frequency range estimation based on which sounds are missing, clinical explanation generation. Fires HCW-08.

3. **GET `/api/speech-images`** — Return Cloudinary image URLs organized by category from `heartech/show_and_tell/` folder. Hardcoded fallback word bank with placeholder Cloudinary URLs if folder is empty.

#### [MODIFY] [main.py](file:///Users/noorhassan/HEARTECH%20FYP/HEARTECH/backend/main.py)
- Load Whisper `base` model once at startup event, store as `app.state.whisper_model`
- Add `espeak-ng` to Dockerfile for phonemizer backend

#### [MODIFY] [Dockerfile](file:///Users/noorhassan/HEARTECH%20FYP/HEARTECH/backend/Dockerfile)
- Add `espeak-ng` system dependency for phonemizer
- Add `torch` CPU-only to avoid pulling GPU CUDA (smaller image)

#### [MODIFY] [requirements.txt](file:///Users/noorhassan/HEARTECH%20FYP/HEARTECH/backend/requirements.txt)
- Already has all needed packages (`openai-whisper`, `rapidfuzz`, `phonemizer`)
- Add `numpy` pinned version if needed for whisper compatibility

---

### Flutter — Speech Log Model

#### [MODIFY] [speech_log_model.dart](file:///Users/noorhassan/HEARTECH%20FYP/HEARTECH/lib/shared/models/speech_log_model.dart)
- Update `LingSixResult` to support two-round format: `round1heard`, `round2heard` fields (instead of single `heard`)
- Keep backward compatibility with existing `heard` field

---

### Flutter — Show and Tell Screen

#### [MODIFY] [show_and_tell_screen.dart](file:///Users/noorhassan/HEARTECH%20FYP/HEARTECH/lib/features/speech/screens/show_and_tell_screen.dart)
Major rewrite per Phase 6 spec:

- **Category filter chips** at top (Animals, Food, Objects, Body Parts, Transport) using `FilterChip` in horizontal scroll `Wrap`
- **Cloudinary image display** — 240×240 rounded rectangle with `CachedNetworkImage` shimmer placeholder + bounce animation on new image. "Next Word" shuffle button. **Word text NOT shown** (child says what they see)
- **Prompt text**: "What is this? Say it out loud!"
- **Microphone button** (80px circle):
  - Idle: Deep Teal fill, white mic icon
  - Recording: white fill, red mic icon, pulsing red ring (1.0→1.4 scale loop)
  - Permission dialog if denied
- **Recording**: `record` package with `AudioEncoder.wav`, elapsed time counter, auto-stop at 10 seconds
- **Post-recording**: upload `.wav` to FastAPI `/api/analyze-speech` via Dio multipart
- **Result card** slides up: match score (48sp), color-coded bar, clarity badge, "We heard: [transcript]", phonemes missed chips, feedback text
- **Two buttons**: "Try Another Word" / "Save and Continue"
- **On Save**: write to Firestore `speechLogs`, update `lastSpeechSessionDate`, fire HCW-08
- **Image caching**: Hive `images_box` with 24h TTL, fetch from `/api/speech-images`

---

### Flutter — Ling Six Screen

#### [MODIFY] [ling_six_screen.dart](file:///Users/noorhassan/HEARTECH%20FYP/HEARTECH/lib/features/speech/screens/ling_six_screen.dart)
Major rewrite per Phase 6 spec:

- **6 sounds**: m (250-500Hz), ah (500-1000Hz), oo (500-1000Hz), ee (1000-3000Hz), sh (2000-4000Hz), s (4000-8000Hz)
- **Sound cards** (ListView): large symbol, frequency range, "Play Sound" using `just_audio` from `assets/sounds/ling_{sound}.mp3`, animated sound wave ripple during playback
- **Response buttons**: "Heard It" (green) / "No Response" (grey) per sound, green/red left border on selection
- **Progress indicator**: 6 circles, green/grey, "X of 6 sounds completed"
- **Round management**: Round 1 (1m) → Round 2 (3m), clear responses between rounds
- **On Submit**: call `/api/ling-six-analysis` with `{sound, round1heard, round2heard}` format
- **Results screen**: Pass/Watch/Refer badge, `fl_chart` BarChart (Round 1 vs Round 2 side-by-side bars), frequency range estimate, flagged sounds, clinical explanation, recommendation
- **On Save**: write to Firestore `speechLogs`, fire HCW-08

---

### Flutter — Speech Game Selection Screen

#### [MODIFY] [speech_games_screen.dart](file:///Users/noorhassan/HEARTECH%20FYP/HEARTECH/lib/features/speech/screens/speech_games_screen.dart)
Rewrite per Phase 6 spec:

- "Speech Exercises" heading
- Child selection first if multiple children (tap to select, auto-select if only one)
- Two large game cards with illustrations:
  - **Show and Tell**: microphone icon, description, "Play" primary button
  - **Ling Six**: sound wave icon, description, "Start Test" secondary button

---

### Flutter — Dependencies & Assets

#### [MODIFY] [pubspec.yaml](file:///Users/noorhassan/HEARTECH%20FYP/HEARTECH/pubspec.yaml)
- Add `cached_network_image` dependency for Cloudinary image loading with shimmer
- Add `assets/sounds/` to asset bundle

#### [NEW] `assets/sounds/` directory
- 6 Ling Six audio files: `ling_m.mp3`, `ling_ah.mp3`, `ling_oo.mp3`, `ling_ee.mp3`, `ling_sh.mp3`, `ling_s.mp3`

---

### Flutter — FastAPI Service

#### [MODIFY] [fastapi_service.dart](file:///Users/noorhassan/HEARTECH%20FYP/HEARTECH/lib/services/fastapi_service.dart)
- Add `getSpeechImages()` method for `GET /api/speech-images`
- Update `analyzeLingSix()` to send `round1heard`/`round2heard` per sound

---

## Open Questions

> [!IMPORTANT]
> **Cloudinary Show & Tell Images**: The spec says images are hosted on Cloudinary in `heartech/show_and_tell/` folder. For initial setup, I'll hardcode a fallback word bank with emoji icons (like the current implementation) so the app works immediately without requiring you to upload 50+ images first. The `/api/speech-images` endpoint will serve these fallback URLs. You can upload real illustrated images to Cloudinary later and the system will automatically use them via the API. **Does this approach work for you?**

> [!NOTE]
> **Phonemizer dependency**: The `phonemizer` Python package requires `espeak-ng` as a system dependency. This will be added to the Dockerfile. When running FastAPI locally (not in Docker), you'll need to install espeak-ng on your machine (`brew install espeak` on macOS). If phonemizer fails, the endpoint will still work but skip phoneme analysis and return an empty phonemes list.

## Verification Plan

### Automated Tests
1. `flutter analyze` — no errors
2. Backend starts: `cd backend && uvicorn main:app --host 0.0.0.0 --port 8000`
3. Health check: `curl http://localhost:8000/health`

### Manual Verification
1. **Show and Tell**:
   - Navigate to Speech Games → select child → Show and Tell
   - Tap category chips to filter
   - Tap microphone → grant permission → speak → see results
   - Verify result card shows match score, clarity, phonemes missed
   - Tap "Save and Continue" → verify speechLog in Firestore
2. **Ling Six**:
   - Navigate to Speech Games → select child → Ling Six
   - Play each sound → mark heard/not heard
   - Complete Round 1 → move to Round 2
   - Submit → verify results screen with chart and badges
   - Save → verify speechLog in Firestore
3. **HCW-08 notification**: Check linked HCW's notification feed after saving
