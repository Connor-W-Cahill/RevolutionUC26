# Firestore Schema

## Collections

### `users/{userId}`
| Field | Type | Description |
|-------|------|-------------|
| displayName | string | User's display name |
| email | string | Email address |
| photoURL | string? | Profile photo URL |
| friendIDs | string[] | Accepted friend UIDs (denormalized cache) |
| createdAt | timestamp | Account creation time |

### `readings/{readingId}`
Data from Presage SmartSpectra SDK measurements.

| Field | Type | Description |
|-------|------|-------------|
| userID | string | Owner's UID |
| timestamp | timestamp | When the reading was taken |
| pulseRate | number | Pulse rate BPM (from `metrics.pulse.strict.value`) |
| breathingRate | number | Breathing rate BPM (from `metrics.breathing.strict.value`) |
| bloodPressurePhasic | number? | Phasic blood pressure (from `metrics.bloodPressure.phasic`) |
| breathingAmplitude | number? | Breathing amplitude |
| inhaleExhaleRatio | number? | Inhale/exhale ratio |
| apneaDetected | boolean? | Whether apnea was detected |

**Note:** The Presage SDK does not provide a direct "stress" or "cortisol" metric. We derive stress indicators from pulse rate, breathing patterns, and HRV-proxy data. The frontend can compute a stress score from these raw values.

### `activities/{activityId}`
| Field | Type | Description |
|-------|------|-------------|
| userID | string | Owner's UID |
| date | string | ISO date (YYYY-MM-DD) |
| category | string | e.g. "sleep", "diet", "exercise", "stressor", "other" |
| title | string | Short description |
| notes | string? | Additional details |
| rating | number? | User rating (1-5) |

### `friendships/{friendshipId}`
Document ID format: `{smallerUID}_{largerUID}` (lexicographic order)

| Field | Type | Description |
|-------|------|-------------|
| userA | string | Lexicographically smaller UID |
| userB | string | Lexicographically larger UID |
| status | string | "pending" \| "accepted" \| "declined" |
| initiatedBy | string | UID of who sent the request |
| createdAt | timestamp | When request was sent |
| updatedAt | timestamp | Last status change |

### `aiTips/{userID}`
One doc per user, overwritten on each generation.

| Field | Type | Description |
|-------|------|-------------|
| userID | string | Owner's UID |
| tips | array | Array of Tip objects |
| generatedAt | timestamp | When tips were generated |

**Tip object:**
| Field | Type | Description |
|-------|------|-------------|
| id | string | Unique tip ID |
| title | string | Short title |
| body | string | Actionable tip (1-2 sentences) |
| category | string | "breathing" \| "exercise" \| "sleep" \| "nutrition" \| "mindfulness" \| "social" \| "general" |
| createdAt | string | ISO timestamp |

## Indexes
See `firestore.indexes.json`:
- `readings`: (userID ASC, timestamp DESC)
- `activities`: (userID ASC, date DESC)
- `friendships`: (status ASC, createdAt DESC)

## Cloud Functions

### `generateTips` (callable)
No input params — uses auth UID. Returns `{ tips: Tip[] }`.
Currently returns hardcoded wellness tips (AI integration planned later).

### `dailyTipsGeneration` (scheduled)
Runs at 8am UTC daily. Refreshes tips for all users.

## Presage SDK Metrics Mapping
```
metrics.pulse.strict.value       → readings.pulseRate
metrics.breathing.strict.value   → readings.breathingRate
metrics.bloodPressure.phasic     → readings.bloodPressurePhasic
metrics.breathing.amplitude      → readings.breathingAmplitude
metrics.breathing.inhaleExhaleRatio → readings.inhaleExhaleRatio
metrics.breathing.apnea          → readings.apneaDetected
```
