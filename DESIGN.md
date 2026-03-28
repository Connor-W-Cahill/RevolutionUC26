# Cortisol Tracker — Design System

## Design Philosophy
Calm, modern health app. Think: Oura Ring meets Apple Health. Soft gradients, generous white space, rounded elements. The app should feel *reassuring* — you're managing stress, not adding to it.

## Color Palette

### Primary
- **Deep Teal** `#1A6B5C` — primary actions, navigation highlights
- **Soft Teal** `#2D9F8F` — secondary actions, active states
- **Mint** `#A8E6CF` — positive indicators (low stress), success states

### Stress Spectrum (for cortisol visualization)
- **Low** `#A8E6CF` (mint green)
- **Moderate** `#FFD93D` (warm yellow)
- **Elevated** `#FF8C42` (soft orange)
- **High** `#E85D75` (rose red)

### Neutrals
- **Background** `#F8F9FA` — main app background
- **Card** `#FFFFFF` — card surfaces
- **Text Primary** `#1A1A2E` — headings, body text
- **Text Secondary** `#6B7280` — labels, captions
- **Divider** `#E5E7EB` — separators, borders

### Accents
- **Calm Blue** `#5B9BD5` — informational, HRV
- **Soft Purple** `#8B7EC8` — tips, AI-generated content
- **Warm Coral** `#F0A1A8` — heart rate

## Typography

Use iOS system fonts for performance and native feel:

| Role | Font | Size | Weight |
|------|------|------|--------|
| Large Title | SF Pro Display | 34pt | Bold |
| Title | SF Pro Display | 28pt | Semibold |
| Section Header | SF Pro Text | 20pt | Semibold |
| Body | SF Pro Text | 17pt | Regular |
| Caption | SF Pro Text | 13pt | Regular |
| Metric Value | SF Pro Rounded | 48pt | Bold |
| Metric Label | SF Pro Text | 13pt | Medium |

## Layout Patterns

### Spacing Scale
- `4pt` — tight (icon-to-label)
- `8pt` — compact (within cards)
- `12pt` — default (between elements)
- `16pt` — section padding
- `24pt` — between cards/sections
- `32pt` — major sections

### Cards
- Corner radius: `16pt`
- Padding: `16pt`
- Background: white
- Shadow: `0 2px 8px rgba(0,0,0,0.06)`
- No borders — rely on shadow + background contrast

### Navigation
- Tab bar with 4 tabs: Dashboard, Calendar, Friends, Tips
- Tab icons: SF Symbols (`heart.text.square`, `calendar`, `person.2`, `lightbulb`)
- Active tab: Deep Teal with filled icon
- Inactive: Text Secondary with outline icon

## Screen Designs

### 1. Dashboard (Home)
```
┌─────────────────────────────┐
│  Good morning, Alex     🔔  │
│                              │
│  ┌──────────────────────┐   │
│  │   Current Stress      │   │
│  │      ● 32             │   │
│  │    [radial gauge]     │   │
│  │     "Low — Nice!"     │   │
│  └──────────────────────┘   │
│                              │
│  Vitals                      │
│  ┌──────┐ ┌──────┐ ┌──────┐│
│  │ ♥    │ │ 🫁   │ │ 🩸   ││
│  │ 72   │ │ 16   │ │120/80││
│  │ BPM  │ │ br/m │ │ mmHg ││
│  └──────┘ └──────┘ └──────┘│
│                              │
│  [  Take Reading  ]         │
│                              │
│  Today's Log                 │
│  ┌──────────────────────┐   │
│  │ 😴 Sleep: 7.5h       │   │
│  │ 🥗 Diet: Good        │   │
│  │ 🏃 Exercise: 30min   │   │
│  └──────────────────────┘   │
└─────────────────────────────┘
```

**Key elements:**
- Greeting + notification bell top bar
- Hero card: stress index with radial/ring gauge, color-coded to stress spectrum
- Vitals row: 3 compact metric cards (Pulse Rate, Breathing Rate, Blood Pressure)
- CTA button: "Take Reading" — prominent, Deep Teal, rounded pill shape → opens Presage SmartSpectraView for camera scan
- Today's lifestyle log summary

**SDK Integration Note:**
- "Take Reading" presents the Presage `SmartSpectraView` (SDK-provided camera UI with countdown)
- SDK returns: `metrics.pulse.strict.value` (BPM), `metrics.breathing.strict.value` (breaths/min), `metrics.bloodPressure.phasic` (BP)
- Stress index is derived from these vitals (computed by us, not the SDK)
- The SDK camera view has its own UI — we style the pre/post scan screens, not the capture itself

### 2. Calendar
```
┌─────────────────────────────┐
│  March 2026            ◀ ▶  │
│  M  T  W  T  F  S  S       │
│  ·  ·  ·  ·  ·  ·  1       │
│  2  3  4  5  6  7  8       │
│  (each day: small dot       │
│   colored by avg stress)    │
│                              │
│  Selected: March 15          │
│  ┌──────────────────────┐   │
│  │ Avg Stress: 38       │   │
│  │ Readings: 3          │   │
│  │ ───────────────       │   │
│  │ 9:00am  — 32 (low)   │   │
│  │ 2:00pm  — 45 (mod)   │   │
│  │ 8:00pm  — 28 (low)   │   │
│  └──────────────────────┘   │
│                              │
│  Logged Activities           │
│  ┌──────────────────────┐   │
│  │ + Add entry           │   │
│  │ 😴 Slept 6h          │   │
│  │ ☕ 3 coffees          │   │
│  └──────────────────────┘   │
└─────────────────────────────┘
```

**Key elements:**
- Monthly grid calendar — each day has a small colored dot (stress spectrum)
- Tap day → detail card slides up with readings + activities
- "Add entry" button for lifestyle logging
- Smooth transition between months

### 3. Friends
```
┌─────────────────────────────┐
│  Friends                 +   │
│                              │
│  ┌──────────────────────┐   │
│  │ 👤 Sarah   ● Low     │   │
│  │    Last: 28 · 2h ago  │   │
│  └──────────────────────┘   │
│  ┌──────────────────────┐   │
│  │ 👤 Marcus  ● Moderate│   │
│  │    Last: 42 · 30m ago │   │
│  └──────────────────────┘   │
│                              │
│  Leaderboard (weekly avg)    │
│  🥇 You — 31                │
│  🥈 Sarah — 33              │
│  🥉 Marcus — 41             │
└─────────────────────────────┘
```

**Key elements:**
- Friend cards: avatar, name, current stress level (color-coded dot), last reading time
- Weekly leaderboard (lowest avg stress wins) — gamification, keeps it fun
- "+" button to add friends (share code / QR)
- Privacy-conscious: only share stress level, not full vitals

### 4. Tips
```
┌─────────────────────────────┐
│  Your Tips              🔄   │
│                              │
│  Based on your patterns:     │
│                              │
│  ┌──────────────────────┐   │
│  │ 💡                    │   │
│  │ Your stress peaks     │   │
│  │ around 2pm on         │   │
│  │ weekdays. Try a 10min │   │
│  │ walk after lunch.     │   │
│  └──────────────────────┘   │
│                              │
│  ┌──────────────────────┐   │
│  │ 🌙                    │   │
│  │ On nights you sleep   │   │
│  │ 7+ hours, your        │   │
│  │ morning cortisol is   │   │
│  │ 23% lower.            │   │
│  └──────────────────────┘   │
│                              │
│  Quick Actions               │
│  ┌─────┐ ┌─────┐ ┌─────┐   │
│  │ 🧘  │ │ 🫁  │ │ 📝  │   │
│  │Calm │ │Brth │ │Jrnl │   │
│  └─────┘ └─────┘ └─────┘   │
└─────────────────────────────┘
```

**Key elements:**
- AI-generated tip cards with Soft Purple accent
- Each tip is personalized based on user's data patterns
- Quick action buttons: guided breathing, meditation timer, journal prompt
- Refresh button to get new tips

### 5. Scan Flow (Camera Reading)
```
┌─────────────────────────────┐
│           ← Back             │
│                              │
│   Get ready to scan          │
│                              │
│   Hold your phone steady     │
│   and look at the camera     │
│                              │
│   ┌──────────────────────┐  │
│   │                      │  │
│   │   [SmartSpectraView] │  │
│   │   (SDK camera UI)    │  │
│   │                      │  │
│   └──────────────────────┘  │
│                              │
│   Scanning... 18s remaining  │
│   ━━━━━━━━━━━░░░░░░░░░░░░  │
│                              │
└─────────────────────────────┘

        ↓ After scan ↓

┌─────────────────────────────┐
│          Your Results        │
│                              │
│   ┌──────────────────────┐  │
│   │   Stress Index        │  │
│   │      ● 32             │  │
│   │    [radial gauge]     │  │
│   │     "Low — Nice!"     │  │
│   └──────────────────────┘  │
│                              │
│   ┌──────┐ ┌──────┐ ┌──────┐│
│   │ 72   │ │ 16   │ │120/80││
│   │ BPM  │ │ br/m │ │ mmHg ││
│   └──────┘ └──────┘ └──────┘│
│                              │
│   [    Save Reading    ]     │
│   [    Scan Again      ]     │
│                              │
└─────────────────────────────┘
```

**Key elements:**
- Pre-scan: brief instruction text, then SDK's SmartSpectraView takes over
- During scan: progress bar + countdown timer below the camera view
- Post-scan: results card with computed stress index + all vitals
- "Save Reading" (primary) persists to Firebase, "Scan Again" (secondary) restarts
- Back button returns to Dashboard without saving

## Component Styles

### Buttons
- **Primary**: Deep Teal bg, white text, 12pt corner radius, 48pt height, full-width or pill
- **Secondary**: White bg, Deep Teal border + text, same shape
- **Ghost**: No bg/border, Soft Teal text

### Input Fields
- 12pt corner radius
- Light gray border `#E5E7EB`
- 16pt padding
- Focus: Deep Teal border, subtle teal shadow

### Stress Gauge (Hero Component)
- Radial ring/arc gauge
- Ring color follows stress spectrum gradient
- Large metric number in center (SF Pro Rounded, 48pt, Bold)
- Text label below: "Low", "Moderate", "Elevated", "High"
- Subtle animated fill on load

### Metric Cards
- 80pt × 80pt compact squares (or flexible width in HStack)
- Icon top (SF Symbol, colored), value center (bold), label bottom (caption)
- Light background tinted to metric color at ~5% opacity

## Animations & Transitions
- Tab switches: crossfade (0.2s)
- Card appearances: fade-up (0.3s, spring)
- Gauge fill: animated ring draw (0.8s, ease-out)
- Pull to refresh on Dashboard
- Calendar day selection: gentle scale + highlight

## Dark Mode
Support iOS dark mode:
- Background: `#0D1117`
- Card: `#1C1C1E`
- Text Primary: `#F0F0F0`
- Keep stress spectrum colors the same (they're already vivid enough)
- Teal stays the same — it works on both

## Accessibility
- All interactive elements: minimum 44pt tap target
- Color is never the only indicator — pair with text labels/icons
- VoiceOver labels on all custom components
- Dynamic Type support
