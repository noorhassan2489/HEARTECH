# Phase 6 Walkthrough — Speech and Sound Modules

## Files Created or Modified

| File | Action |
|------|--------|
| `backend/Dockerfile` | MODIFIED — added `espeak-ng`, pre-download Whisper model |
| `backend/main.py` | MODIFIED — load Whisper `base` model at startup |
| `backend/routers/speech.py` | REWRITTEN — 3 full endpoints |
| `lib/shared/models/speech_log_model.dart` | MODIFIED — LingSixResult now has round1heard/round2heard |
| `lib/features/speech/screens/show_and_tell_screen.dart` | REWRITTEN — full Phase 6 spec |
| `lib/features/speech/screens/ling_six_screen.dart` | REWRITTEN — full Phase 6 spec |
| `lib/features/speech/screens/speech_games_screen.dart` | REWRITTEN — child selection + game cards |
| `lib/services/fastapi_service.dart` | MODIFIED — added `getSpeechImages()` |
| `pubspec.yaml` | MODIFIED — added `cached_network_image`, `assets/sounds/` |
| `assets/sounds/README.md` | NEW — placeholder for Ling Six audio files |

## What Changed

### Backend
- **`/api/analyze-speech`**: Real Whisper transcription → rapidfuzz matching → phonemizer analysis → clarity rating → feedback message → HCW-08 notification
- **`/api/ling-six-analysis`**: Two-round scoring (Round 2 is definitive), frequency range estimation based on which sounds are missed, clinical explanation, HCW-08 notification
- **`/api/speech-images`**: Serves Cloudinary image URLs by category, falls back to emoji word bank
- **Whisper model** loaded once at startup, reused across requests

### Flutter
- **Show and Tell**: Category filter chips, Cloudinary/emoji image display (240×240), tap-to-record/tap-to-stop microphone with pulsing red ring, .wav recording via `record` package, auto-stop at 10s, elapsed timer, upload to FastAPI, result card with score/clarity/phonemes/feedback, save to Firestore
- **Ling Six**: 6 sound cards with `just_audio` playback, Heard It / No Response buttons, green/red left borders, progress dots, Round 1 (1m) → Round 2 (3m), `fl_chart` BarChart results, Pass/Watch/Refer badges, frequency estimate, save to Firestore
- **Speech Games Selection**: Child picker (auto-select if one child), two game cards with icons and action buttons

### Verification
- `flutter analyze` — **0 errors, 0 warnings** (only info-level style lints)

---

## YOUR ACTION ITEMS

### 1. LING SIX AUDIO FILES (6 files needed)

You need 6 short `.mp3` audio clips of the Ling Six sounds. Place them in:
```
assets/sounds/ling_m.mp3
assets/sounds/ling_ah.mp3
assets/sounds/ling_oo.mp3
assets/sounds/ling_ee.mp3
assets/sounds/ling_sh.mp3
assets/sounds/ling_s.mp3
```

**Where to get them (free):**
1. Go to https://freesound.org (free account required)
2. Search for each sound: "m sound speech", "ah vowel sound", etc.
3. Download short clips (1-3 seconds each), convert to MP3
4. **OR** record them yourself using your phone's voice recorder:
   - `/m/` — say "mmmmm" (hum) for 2 seconds
   - `/ah/` — say "ahhhhh" (like "father") for 2 seconds
   - `/oo/` — say "ooooo" (like "food") for 2 seconds
   - `/ee/` — say "eeee" (like "see") for 2 seconds
   - `/sh/` — say "shhhh" for 2 seconds
   - `/s/` — say "sssss" for 2 seconds
5. Save as `.mp3` with the exact filenames above
6. **Cost: FREE**

> The app will work without these files — it silently catches the missing asset error and simulates playback. But for a real demo, add them.

### 2. SHOW AND TELL IMAGES ON CLOUDINARY (optional — emoji fallback works)

The app works immediately with emoji illustrations. To use real images:

1. Log in to Cloudinary: https://console.cloudinary.com
2. Go to **Media Library** → Create folder `heartech/show_and_tell/`
3. Create subfolders: `animals/`, `food/`, `objects/`, `body/`, `transport/`
4. Upload illustrated images named after the word (e.g., `cat.png`, `dog.png`)
5. The `/api/speech-images` endpoint will automatically serve Cloudinary URLs
6. Add your `CLOUDINARY_URL` to `backend/.env`:
   ```
   CLOUDINARY_URL=cloudinary://API_KEY:API_SECRET@CLOUD_NAME
   ```
7. **Cost: FREE** (Cloudinary free tier)

### 3. WHISPER MODEL IN DOCKER

The Dockerfile now pre-downloads the Whisper `base` model at build time.

**If running locally (no Docker):**
```bash
pip install openai-whisper
# Whisper will auto-download the base model on first run (~140MB)
```

**If running with Docker:**
```bash
cd backend
docker build -t heartech-api .
docker run -p 8000:8080 heartech-api
```

### 4. ESPEAK-NG FOR PHONEMIZER

**macOS (for local development):**
```bash
brew install espeak
```

**Docker:** Already added to Dockerfile — no action needed.

> If espeak-ng is not installed, the endpoint still works — it just skips phoneme analysis and returns empty phonemes lists.

### 5. TERMINAL COMMANDS
```bash
cd "/Users/noorhassan/HEARTECH FYP/HEARTECH"
flutter pub get

# Start backend
cd backend
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000

# Run app
cd ..
flutter run
```

### 6. NO FIREBASE CONSOLE STEPS NEEDED
Firestore rules already allow `speechLogs` subcollection writes.

### 7. NO ONESIGNAL STEPS NEEDED
HCW-08 notifications use the existing NotificationService.

---

## HOW TO TEST

### Show and Tell
1. Log in as **Parent** → tap **Speech Games** from dashboard
2. If multiple children, tap to select one
3. Tap **Play** on the Show and Tell card
4. Tap category chips (Animals, Food, etc.) to switch word sets
5. Tap the **Next Word** button (skip icon) in the app bar to shuffle
6. Tap the **microphone button** → grant permission → speak the word
7. Watch the elapsed timer count up (auto-stops at 10 seconds)
8. Or tap the mic again to stop early
9. See the **result card** slide up with score, clarity badge, transcript, phonemes missed
10. Tap **Save and Continue** → verify snackbar "Result saved! ✓"
11. Check **Firestore Console** → `children/{childId}/speechLogs/` → new document with `game: "showAndTell"`

### Ling Six
1. From Speech Games → tap **Start Test** on Ling Six card
2. Read the intro, tap **Begin Test**
3. See the orange distance banner: "Child should be 1 metre away"
4. For each of the 6 sounds: tap **Play Sound** (if audio files exist), then tap **Heard It** or **No**
5. Watch progress dots fill green/red
6. When all 6 answered → tap **Complete Round 1**
7. Round break screen shows Round 1 results → tap **Start Round 2**
8. Banner changes to "3 metres away" — repeat all 6 sounds
9. When all answered → tap **Submit Results**
10. Results screen shows:
    - **Pass/Watch/Refer** badge
    - Bar chart (Round 1 vs Round 2, side by side)
    - Frequency range estimate
    - Flagged sounds with descriptions
    - Clinical explanation and recommendation
11. Tap **Save Result** → verify snackbar + pop back
12. Check **Firestore Console** → `children/{childId}/speechLogs/` → new document with `game: "lingSix"`

### HCW-08 Notification
After saving either game result, check the linked HCW's notification feed:
- **Firestore** → `notifications/{hcwUid}/items/` → new document with `type: "HCW-08"`
