# HearTech — Design & Poster Guide

Use this file to match your **exhibition poster**, slides, and print materials to the HearTech mobile app. All values come from the app’s design system in `lib/core/theme/app_theme.dart`.

For project content (features, team, demo script), see [`README.md`](README.md).

---

## Brand identity

| Element | Value |
|---------|--------|
| **App name** | HearTech |
| **Tagline** | Early Hearing, Better Futures |
| **Logo mark** | Ear / hearing icon (`Icons.hearing`) — no separate image file; use Material “hearing” icon or equivalent |
| **Logo treatment** | Teal ear icon inside a **white circle** on **pale teal** background (see splash screen) |
| **Tone** | Clean, friendly, clinical-but-accessible — paediatric healthcare, not corporate cold |

### Logo composition (match the splash screen)

```text
┌─────────────────────────────────────┐
│  Background: Pale Teal #E0F5F5      │
│                                     │
│         ┌─────────────┐             │
│         │ white circle│             │
│         │  👂 hearing │  Deep Teal  │
│         └─────────────┘             │
│                                     │
│           HearTech                  │  Nunito ExtraBold 32px, Deep Teal
│   Early Hearing, Better Futures     │  Nunito 14px, Text Secondary
└─────────────────────────────────────┘
```

**Circle shadow (optional):** Deep Teal at 15% opacity, blur ~30px, offset Y +8px.

---

## Color palette

### Primary brand colors

| Name | Hex | RGB | Use on poster |
|------|-----|-----|----------------|
| **Deep Teal** | `#007B7B` | 0, 123, 123 | Headings, logo, primary buttons, HCW accent |
| **Medium Teal** | `#00A3A3` | 0, 163, 163 | Parent role accent, gradients, secondary highlights |
| **Pale Teal** | `#E0F5F5` | 224, 245, 245 | Page/section backgrounds, input fills, soft panels |
| **Deep Teal Dark** | `#005F5F` | 0, 95, 95 | Hover states, footer bars, dark accents |

### Neutrals

| Name | Hex | RGB | Use on poster |
|------|-----|-----|----------------|
| **Background** | `#F4F8F9` | 244, 248, 249 | Main poster background (light, airy) |
| **White** | `#FFFFFF` | 255, 255, 255 | Content cards, logo circle |
| **Text Primary** | `#1A2E35` | 26, 46, 53 | Body text, section titles |
| **Text Secondary** | `#6B8E99` | 107, 142, 153 | Captions, subtitles, tagline |
| **Divider** | `#D0E8EC` | 208, 232, 236 | Lines between sections |

### Role accent colors (use on role cards / stakeholder diagram)

| Role | Color | Hex | Icon (Material-style) |
|------|-------|-----|------------------------|
| **Healthcare Worker** | Deep Teal | `#007B7B` | medical_services |
| **Parent** | Medium Teal | `#00A3A3` | family_restroom |
| **Teacher** | Purple | `#8E44AD` | school |

Role card pattern: white card + **10% tint** icon background + **15% tint** border in role color.

### Risk level colors (badges, charts, gauges)

| Level | Hex | Label example |
|-------|-----|----------------|
| **Low** | `#27AE60` | “Low Risk” — green pill, white text |
| **Medium** | `#E67E22` | “Medium Risk” — orange pill, white text |
| **High** | `#FF6B6B` | “High Risk” — coral pill, white text |

### Semantic / alert

| Name | Hex | Use |
|------|-----|-----|
| **Coral Red** | `#FF6B6B` | High risk, disclaimer headings, errors |
| **Disclaimer background** | `#FDECEA` | Soft red tint box (About screen disclaimer) |
| **Error** | `#E53935` | Strong error states |

### Gradient (avatars, optional poster accents)

```text
Linear gradient: Deep Teal (#007B7B) → Medium Teal (#00A3A3)
Direction: top-left to bottom-right
```

---

## Typography

**Font family:** [Nunito](https://fonts.google.com/specimen/Nunito) (Google Fonts) — rounded, friendly, matches the app exactly.

Download for Canva, PowerPoint, Figma, or InDesign if offline.

| Style | Weight | Size | Color | App usage | Poster usage |
|-------|--------|------|-------|-----------|--------------|
| **Display** | ExtraBold (800) | 32px | Deep Teal | Splash hero | Main poster title “HearTech” |
| **Screen title** | Bold (700) | 24px | Deep Teal or Text Primary | Page titles | Section headers |
| **Section header** | SemiBold (600) | 18px | Text Primary | Card titles | Subsection titles |
| **Body** | Regular (400) | 14px | Text Primary | Paragraphs | Main body copy (line-height ~1.5) |
| **Subtitle** | SemiBold (600) | 14px | Text Secondary | Secondary labels | Role subtitles |
| **Caption** | Light (300) | 12px | Text Secondary | Meta text | Footer, credits, version |
| **Button** | Bold (700) | 16px | White on teal | CTAs | “Scan QR for demo” badges |
| **Big number** | ExtraBold (800) | 48px | Risk color or Deep Teal | Risk score | Stat callouts (e.g. “0–12 years”) |
| **Handover code** | ExtraBold (800) | 28px | Text Primary | Codes | Optional; letter-spacing +4px |

**Do not use:** serif fonts, sharp geometric sans (Helvetica-only), or heavy all-caps blocks except short labels.

---

## UI components (mirror on poster)

### Content cards

| Property | Value |
|----------|--------|
| Background | White `#FFFFFF` |
| Corner radius | **20px** |
| Padding | 16–20px |
| Shadow | Deep Teal **8%** opacity, blur **16px**, offset **(0, 4px)** |
| Optional border | Role color at **15%** opacity, 1.5px |

### Buttons (primary)

| Property | Value |
|----------|--------|
| Fill | Deep Teal `#007B7B` |
| Text | White, Nunito Bold 16px |
| Height | 56px (or proportional on print) |
| Corner radius | **16px** |
| Style | Flat — no heavy 3D shadow |

### Buttons (secondary / outline)

| Property | Value |
|----------|--------|
| Fill | Transparent or white |
| Border | Deep Teal 1.5px |
| Text | Deep Teal |

### Risk badges (pills)

| Property | Value |
|----------|--------|
| Shape | Fully rounded pill (radius 50px) |
| Fill | Low / Medium / High color (solid) |
| Text | White, Nunito Bold 13–14px |
| Example | “High Risk”, “Medium Risk”, “Low Risk” |

### Disclaimer box

| Property | Value |
|----------|--------|
| Background | `#FDECEA` |
| Corner radius | 20px |
| Title | “Important Disclaimer”, Coral Red, Bold 16px |
| Body | Text Primary, 14px |
| Icon | Warning amber / coral |

### Icons

- Style: **Outlined / rounded** Material icons (same family as Flutter Material)
- Primary icon color: Deep Teal
- Role icons: use each role’s accent color
- Icon-in-box: 28px icon inside 14px padding, **16px** rounded square, **10%** role tint background

---

## Spacing and layout

| Token | Value | Use |
|-------|-------|-----|
| Screen padding | 16–24px | Poster outer margin |
| Card padding | 16–20px | Inside white boxes |
| Section spacing | 24px | Gap between major blocks |
| Card gap | 16px | Between stacked cards |
| Small radius | 8px | Chips, small tags |

**App screen feel:** light background, white floating cards, generous whitespace — avoid dense text walls on the poster.

---

## Poster layout (visual recipe)

Recommended **A1 / A0 academic poster** structure using this design system:

```text
┌──────────────────────────────────────────────────────────────────┐
│  HEADER — Pale Teal or Background #F4F8F9                        │
│  [Logo circle] HearTech | Early Hearing, Better Futures          │
│  UCP · F25CS070 · Supervisor · Team names          (Caption 12px)│
├─────────────────────────────┬────────────────────────────────────┤
│  PROBLEM (white card)       │  ARCHITECTURE (white card)         │
│  Body 14px                  │  Diagram + tech stack              │
├─────────────────────────────┤                                    │
│  SOLUTION (white card)      │  SCREENSHOTS (2×2 grid)            │
│  3 numbered steps           │  Rounded corners 20px              │
├─────────────────────────────┴────────────────────────────────────┤
│  THREE ROLES — 3 cards in a row                                  │
│  HCW (Deep Teal) | Parent (Medium Teal) | Teacher (Purple)       │
├──────────────────────────────────────────────────────────────────┤
│  AI HIGHLIGHTS (white card)  │  QR CODE + DEMO (teal CTA box)    │
├──────────────────────────────────────────────────────────────────┤
│  DISCLAIMER — #FDECEA box, full width, small text                │
└──────────────────────────────────────────────────────────────────┘
```

### Background options (pick one)

1. **Full Background `#F4F8F9`** — safest, matches most app screens  
2. **Header band Pale Teal `#E0F5F5`** + body Background — matches splash  
3. **Footer bar Deep Teal `#007B7F`** with white text for credits only  

### Screenshot framing

- Add **20px white border** or place screenshots inside white cards with shadow  
- Optional: thin Deep Teal bottom caption bar per screenshot  

---

## Canva / Figma quick setup

### Canva

1. Custom size: A1 (594 × 841 mm) or your university template  
2. **Brand kit → add colors:** paste hex values from the palette table above  
3. **Text → add font:** search “Nunito”; if unavailable use **Quicksand** or **Varela Round** as fallback (similar rounded feel)  
4. **Elements → search:** “ear”, “medical cross”, “family”, “school” — pick **line/outline** style in teal/purple  
5. Use **rounded rectangle** corners: 20 for cards, 16 for buttons, 50 for pills  

### Figma

1. Create color styles: `Brand/Deep Teal`, `Brand/Medium Teal`, etc.  
2. Text styles: match the typography table  
3. Effect style `Card Shadow`: `#007B7B` 8%, Y=4, blur=16  
4. Component: `Role Card` with icon slot + border variant per role  

### PowerPoint / Google Slides

- Slide master background: `#F4F8F9`  
- Insert → Google Font Nunito (Slides) or download Nunito TTF  
- Shape → rounded rect → set corner radius manually to match  

---

## Logo

Use **`assets/images/poster/heartech-logo-mark-app.png`** in-app via the `HearTechLogo` widget — the transparent teal mark with the ear motif. Do not substitute unrelated medical clipart.

---

## Do’s and don’ts

### Do

- Use **teal as the dominant brand color** (60–70% of accent usage)  
- Keep **white cards on light background** for readability at a distance  
- Use **role colors consistently**: HCW = deep teal, Parent = medium teal, Teacher = purple  
- Show **risk colors** only for risk-related content (badges, gauges)  
- Include the **disclaimer** in the soft red box — matches app and viva expectations  

### Don’t

- Don’t use red/orange/green as generic decoration (reserve for risk levels)  
- Don’t use dark backgrounds for the whole poster (app is light-themed)  
- Don’t use a different logo or unrelated medical clipart  
- Don’t claim “diagnosis” — use “screening” and “decision-support” (see README)  
- Don’t mix multiple font families  

---

## Copy snippets (styled like the app)

**Title block**

```text
HearTech
Early Hearing, Better Futures
```

**Role card titles**

```text
Healthcare Worker     → Screen children for hearing risks
Parent                → Monitor your child's hearing health
Teacher               → Observe classroom hearing behaviours
```

**Disclaimer (short, for poster footer)**

```text
HearTech is NOT a medical diagnostic tool. Risk assessments are for screening
and decision-support only. Always consult a qualified audiologist, ENT
specialist, or paediatrician for formal assessment.
```

---

## Print checklist

- [ ] Nunito (or approved fallback) loaded  
- [ ] All hex colors from this guide (no eyedropper from screenshots)  
- [ ] Logo: hearing icon + white circle + teal  
- [ ] Card radius 20px, shadows subtle (teal-tinted, not black)  
- [ ] Role colors correct on stakeholder diagram  
- [ ] Disclaimer box `#FDECEA` with coral heading  
- [ ] Team: Noor Hassan, Haroon Ashar, Abdul Mateen · Mr. Ihtisham-Ul-Haq · F25CS070  
- [ ] QR code links to demo video or repo  
- [ ] 4–6 app screenshots in white card frames  

---

## Source files in repo

| File | Contents |
|------|----------|
| `lib/core/theme/app_theme.dart` | Colors, text styles, theme, shadows, radii |
| `lib/core/theme/app_animations.dart` | Motion timing (optional for video/demo) |
| `lib/features/auth/screens/splash_screen.dart` | Logo + tagline layout |
| `lib/features/auth/screens/role_selection_screen.dart` | Role card pattern |
| `lib/shared/widgets/risk_badge.dart` | Risk pill styling |
| `lib/features/about/screens/about_screen.dart` | Disclaimer box styling |

---

*© 2025 HearTech — University of Central Punjab, Group F25CS070*
