# Firestore Schema

## Collections

### `users/{userId}`
| Field | Type | Description |
|-------|------|-------------|
| displayName | string | User's display name |
| email | string | Email address |
| photoURL | string? | Profile photo URL |
| friendIDs | string[] | Array of friend UIDs (accepted only) |
| createdAt | timestamp | Account creation time |

### `readings/{readingId}`
| Field | Type | Description |
|-------|------|-------------|
| userID | string | Owner's UID |
| timestamp | timestamp | When the reading was taken |
| stressLevel | number | Stress index from Presage SDK |
| heartRate | number | BPM |
| hrv | number | Heart rate variability (ms) |
| spO2 | number | Blood oxygen % |
| respiratoryRate | number | Breaths per minute |

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
| tips | array | Array of `{ id, title, body, category, createdAt }` |
| generatedAt | timestamp | When tips were generated |
| basedOn | object | `{ readingCount, activityCount }` |

**Tip object shape:**
| Field | Type | Description |
|-------|------|-------------|
| id | string | UUID |
| title | string | Short title (3-6 words) |
| body | string | Actionable tip (1-2 sentences) |
| category | string | "breathing" \| "exercise" \| "sleep" \| "nutrition" \| "mindfulness" \| "social" \| "general" |
| createdAt | string | ISO timestamp |

## Indexes
See `firestore.indexes.json` — composite indexes on:
- `readings`: (userID ASC, timestamp DESC)
- `activities`: (userID ASC, date DESC)
- `friendships`: (status ASC, createdAt DESC)

## Security
- All collections require authentication
- Users can only read/write their own data
- Readings are visible to friends (accepted friendships)
- AI tips are read-only for clients (written by Cloud Functions)
- See `firestore.rules` for full rules

## Cloud Functions

### `generateTips` (callable)
No input needed — uses auth UID to fetch the user's data server-side.

**Response:** `{ tips: Tip[] }`

### `dailyTipsGeneration` (scheduled)
Runs at 8am UTC daily for all users.
