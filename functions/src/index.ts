import * as admin from "firebase-admin";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {defineSecret} from "firebase-functions/params";
import Anthropic from "@anthropic-ai/sdk";
import * as crypto from "crypto";

admin.initializeApp();
const db = admin.firestore();

const anthropicApiKey = defineSecret("ANTHROPIC_API_KEY");

// ─── Types ─────────────────────────────────────────────────────────────────

interface Reading {
  userID: string;
  heartRate: number;
  hrv: number;
  spO2: number;
  respiratoryRate: number;
  stressLevel: number;
  timestamp: admin.firestore.Timestamp;
  source?: string;
}

// Fixed: date is Timestamp (stored by Swift/iOS client), not string
interface Activity {
  userID: string;
  category: string;
  title: string;
  date: admin.firestore.Timestamp;
  notes?: string;
  rating?: number;
}

interface Tip {
  id: string;
  title: string;
  body: string;
  category: string;
  createdAt: string;
  suggestedTime?: string;
}

// ─── Spike Detection ────────────────────────────────────────────────────────

async function detectSpike(readingID: string, reading: Reading): Promise<void> {
  const {userID, stressLevel, timestamp} = reading;
  const readingRef = db.collection("readings").doc(readingID);

  const sevenDaysAgo = new Date(timestamp.toDate().getTime() - 7 * 24 * 60 * 60 * 1000);
  const baselineSnap = await db
    .collection("readings")
    .where("userID", "==", userID)
    .where("timestamp", ">=", admin.firestore.Timestamp.fromDate(sevenDaysAgo))
    .where("timestamp", "<", timestamp)
    .orderBy("timestamp", "desc")
    .limit(50)
    .get();

  const priorReadings = baselineSnap.docs.map((d) => d.data() as Reading);

  if (priorReadings.length < 8) {
    await readingRef.update({isSpikeCandidate: false});
    return;
  }

  const levels = priorReadings.map((r) => r.stressLevel);
  const mean = levels.reduce((a, b) => a + b, 0) / levels.length;
  const variance = levels.reduce((a, b) => a + Math.pow(b - mean, 2), 0) / levels.length;
  const stdDev = Math.sqrt(variance);

  // Previous reading within last 2 hours
  const twoHoursAgo = new Date(timestamp.toDate().getTime() - 2 * 60 * 60 * 1000);
  const recentPrior = priorReadings.find((r) => r.timestamp.toDate() >= twoHoursAgo);
  const prevLevel = recentPrior?.stressLevel;

  const rule1 = stressLevel >= 75;
  const rule2 = stressLevel > mean + 1.5 * stdDev;
  const rule3 = prevLevel !== undefined && stressLevel - prevLevel >= 20;
  const isSpike = rule1 || rule2 || rule3;

  await readingRef.update({isSpikeCandidate: isSpike});
  if (!isSpike) return;

  let severity: "mild" | "moderate" | "high";
  if (rule1 && (rule2 || rule3)) {
    severity = "high";
  } else if (rule1 || rule3) {
    severity = "moderate";
  } else {
    severity = "mild";
  }

  const reasons: string[] = [];
  if (rule1) reasons.push("stress index reached high threshold (>=75)");
  if (rule2) reasons.push("significantly above your 7-day baseline");
  if (rule3 && prevLevel !== undefined) {
    reasons.push(`sharp rise of ${Math.round((stressLevel - prevLevel) * 10) / 10} points within 2 hours`);
  }

  const spikeRef = db.collection("spikeEvents").doc();
  await spikeRef.set({
    id: spikeRef.id,
    userID,
    readingID,
    timestamp,
    stressLevel,
    baselineMean: Math.round(mean * 10) / 10,
    baselineStdDev: Math.round(stdDev * 10) / 10,
    delta: prevLevel !== undefined ? Math.round((stressLevel - prevLevel) * 10) / 10 : 0,
    severity,
    triggerReason: reasons.join("; "),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

// ─── Streak Management ──────────────────────────────────────────────────────

function toDateStr(date: Date): string {
  return date.toISOString().split("T")[0];
}

async function updateStreak(
  userID: string,
  kind: "reading" | "activity",
  eventDate: Date
): Promise<void> {
  const streakRef = db.collection("streaks").doc(userID);
  const dateStr = toDateStr(eventDate);

  await db.runTransaction(async (tx) => {
    const doc = await tx.get(streakRef);
    const data = doc.exists
      ? doc.data()!
      : {
        userID,
        currentReadingStreak: 0,
        bestReadingStreak: 0,
        lastReadingDate: "",
        currentActivityStreak: 0,
        bestActivityStreak: 0,
        lastActivityDate: "",
      };

    const currentKey = kind === "reading" ? "currentReadingStreak" : "currentActivityStreak";
    const bestKey = kind === "reading" ? "bestReadingStreak" : "bestActivityStreak";
    const lastKey = kind === "reading" ? "lastReadingDate" : "lastActivityDate";

    const lastDate = (data[lastKey] as string) || "";
    if (lastDate === dateStr) return; // Already counted today

    const yesterday = toDateStr(new Date(eventDate.getTime() - 24 * 60 * 60 * 1000));
    let current = (data[currentKey] as number) || 0;
    let best = (data[bestKey] as number) || 0;

    current = lastDate === yesterday ? current + 1 : 1;
    if (current > best) best = current;

    tx.set(
      streakRef,
      {
        ...data,
        [currentKey]: current,
        [bestKey]: best,
        [lastKey]: dateStr,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true}
    );
  });
}

// ─── Firestore Triggers ─────────────────────────────────────────────────────

/**
 * On new reading: run spike detection + update reading streak.
 */
export const onReadingCreated = onDocumentCreated(
  "readings/{readingID}",
  async (event) => {
    const reading = event.data?.data() as Reading | undefined;
    if (!reading) return;

    await Promise.all([
      detectSpike(event.params.readingID, reading),
      updateStreak(reading.userID, "reading", reading.timestamp.toDate()),
    ]);
  }
);

/**
 * On new activity: update activity streak.
 */
export const onActivityCreated = onDocumentCreated(
  "activities/{activityID}",
  async (event) => {
    const activity = event.data?.data() as Activity | undefined;
    if (!activity) return;
    await updateStreak(activity.userID, "activity", activity.date.toDate());
  }
);

// ─── Group Daily Stats ──────────────────────────────────────────────────────

async function computeGroupStats(groupID: string, dateStr: string): Promise<void> {
  const groupDoc = await db.collection("groups").doc(groupID).get();
  if (!groupDoc.exists) return;

  const memberIDs: string[] = groupDoc.data()?.memberIDs ?? [];
  if (memberIDs.length === 0) return;

  const date = new Date(`${dateStr}T00:00:00.000Z`);
  const nextDay = new Date(date.getTime() + 24 * 60 * 60 * 1000);

  const stressValues: number[] = [];
  let activeMemberCount = 0;

  await Promise.all(
    memberIDs.map(async (memberID) => {
      const snap = await db
        .collection("readings")
        .where("userID", "==", memberID)
        .where("timestamp", ">=", admin.firestore.Timestamp.fromDate(date))
        .where("timestamp", "<", admin.firestore.Timestamp.fromDate(nextDay))
        .get();

      if (!snap.empty) {
        activeMemberCount++;
        snap.docs.forEach((d) => stressValues.push((d.data() as Reading).stressLevel));
      }
    })
  );

  const statsDocID = `${groupID}_${dateStr}`;
  await db.collection("groupDailyStats").doc(statsDocID).set({
    id: statsDocID,
    groupID,
    date: dateStr,
    memberCount: memberIDs.length,
    activeMemberCount,
    avgStress:
      stressValues.length > 0
        ? Math.round((stressValues.reduce((a, b) => a + b, 0) / stressValues.length) * 10) / 10
        : null,
    minStress: stressValues.length > 0 ? Math.min(...stressValues) : null,
    maxStress: stressValues.length > 0 ? Math.max(...stressValues) : null,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/**
 * Callable: recompute group daily stats for a given day.
 * Called by the iOS client after a group is mutated or on-demand.
 */
export const recomputeGroupDailyStats = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in");
  }

  const {groupID, date} = request.data as {groupID: string; date?: string};
  if (!groupID) throw new HttpsError("invalid-argument", "groupID required");

  await computeGroupStats(groupID, date ?? toDateStr(new Date()));
  return {success: true};
});

// ─── AI Tips Generation ─────────────────────────────────────────────────────

/**
 * Callable: generate AI wellness tips for the authenticated user.
 */
export const generateTips = onCall(
  {secrets: [anthropicApiKey]},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be logged in");
    }
    const tips = await generateTipsForUser(request.auth.uid);
    return {tips};
  }
);

/**
 * Scheduled: regenerate tips for all active users daily at 8am UTC.
 */
export const dailyTipsGeneration = onSchedule(
  {schedule: "0 8 * * *", secrets: [anthropicApiKey]},
  async () => {
    const usersSnap = await db.collection("users").get();
    await Promise.all(
      usersSnap.docs.map((doc) =>
        generateTipsForUser(doc.id).catch((err) =>
          console.error(`Failed tips for ${doc.id}:`, err)
        )
      )
    );
  }
);

async function generateTipsForUser(userID: string): Promise<Tip[]> {
  const weekAgo = new Date();
  weekAgo.setDate(weekAgo.getDate() - 7);
  const weekAgoTs = admin.firestore.Timestamp.fromDate(weekAgo);

  const [readingsSnap, activitiesSnap, spikesSnap] = await Promise.all([
    db
      .collection("readings")
      .where("userID", "==", userID)
      .where("timestamp", ">=", weekAgoTs)
      .orderBy("timestamp", "desc")
      .limit(50)
      .get(),
    db
      .collection("activities")
      .where("userID", "==", userID)
      .where("date", ">=", weekAgoTs)
      .orderBy("date", "desc")
      .limit(50)
      .get(),
    db
      .collection("spikeEvents")
      .where("userID", "==", userID)
      .where("timestamp", ">=", weekAgoTs)
      .orderBy("timestamp", "desc")
      .limit(5)
      .get(),
  ]);

  const readings = readingsSnap.docs.map((d) => d.data() as Reading);
  const activities = activitiesSnap.docs.map((d) => d.data() as Activity);
  const spikes = spikesSnap.docs.map((d) => d.data());

  if (readings.length === 0) {
    const defaultTip: Tip = {
      id: crypto.randomUUID(),
      title: "Get Started",
      body: "Take your first stress reading to receive personalized, data-driven wellness tips.",
      category: "general",
      createdAt: new Date().toISOString(),
    };
    await saveTips(userID, [defaultTip], readings, activities);
    return [defaultTip];
  }

  const tips = await callAI(readings, activities, spikes);
  await saveTips(userID, tips, readings, activities);
  return tips;
}

async function callAI(
  readings: Reading[],
  activities: Activity[],
  spikes: admin.firestore.DocumentData[]
): Promise<Tip[]> {
  const client = new Anthropic();

  const readingSummary = readings.slice(0, 20).map((r) => ({
    stress: r.stressLevel,
    hr: r.heartRate,
    hrv: r.hrv,
    time: r.timestamp.toDate().toISOString(),
  }));

  const activitySummary = activities.slice(0, 20).map((a) => ({
    category: a.category,
    title: a.title,
    // Handle both Timestamp and string for robustness
    date:
      a.date instanceof admin.firestore.Timestamp
        ? a.date.toDate().toISOString()
        : String(a.date),
    rating: a.rating,
  }));

  const spikeSummary = spikes.map((s) => ({
    severity: s.severity,
    stress: s.stressLevel,
    reason: s.triggerReason,
    time:
      s.timestamp instanceof admin.firestore.Timestamp
        ? s.timestamp.toDate().toISOString()
        : String(s.timestamp),
  }));

  // Compute time-of-day stress peaks from readings
  const hourBuckets: {[h: number]: number[]} = {};
  readings.forEach((r) => {
    const h = r.timestamp.toDate().getHours();
    if (!hourBuckets[h]) hourBuckets[h] = [];
    hourBuckets[h].push(r.stressLevel);
  });
  const peakHoursText = Object.entries(hourBuckets)
    .map(([h, vals]) => ({
      hour: Number(h),
      avg: vals.reduce((a, b) => a + b, 0) / vals.length,
    }))
    .sort((a, b) => b.avg - a.avg)
    .slice(0, 3)
    .map((x) => `${x.hour}:00 avg=${Math.round(x.avg)}`)
    .join(", ");

  const now = new Date();
  const prompt = `You are a concise wellness coach. Generate 3-5 personalized stress management tips.

Current time: ${now.toISOString()}
Stress readings (newest first, last 7 days): ${JSON.stringify(readingSummary)}
Activities this week: ${JSON.stringify(activitySummary)}
Stress spikes detected: ${JSON.stringify(spikeSummary)}
Stress peaks by hour of day: ${peakHoursText || "insufficient data"}

STRICT RULES:
1. Each tip body must be under 40 words.
2. Include a specific duration, frequency, or time in every tip (e.g., "for 90s", "3x daily", "at 7am").
3. At least one tip must reference an observed pattern (spike time, activity correlation, or peak hour).
4. If any spike was detected, make the FIRST tip an immediate (<5 min) coping technique.
5. Never use vague phrases like "be mindful" or "try relaxing" without a concrete action + duration.

Return ONLY a valid JSON array of 3-5 tip objects:
{
  "title": "3-6 word title",
  "body": "actionable tip, under 40 words",
  "category": "breathing|exercise|sleep|nutrition|mindfulness|social|general",
  "suggestedTime": "ISO datetime string (optional, for time-anchored tips)"
}`;

  const message = await client.messages.create({
    model: "claude-haiku-4-5-20251001",
    max_tokens: 1024,
    messages: [{role: "user", content: prompt}],
  });

  const text = message.content[0].type === "text" ? message.content[0].text : "";
  const jsonMatch = text.match(/\[[\s\S]*\]/);
  if (!jsonMatch) {
    return [
      {
        id: crypto.randomUUID(),
        title: "Box Breathing Reset",
        body: "Inhale 4s, hold 4s, exhale 4s, hold 4s. Repeat 4 cycles now to reset your stress response.",
        category: "breathing",
        createdAt: now.toISOString(),
      },
    ];
  }

  const nowStr = now.toISOString();
  const raw = JSON.parse(jsonMatch[0]) as Array<{
    title: string;
    body: string;
    category: string;
    suggestedTime?: string;
  }>;

  // Quality filter: discard tips with missing or trivially short content
  return raw
    .filter((t) => t.body?.length > 10 && t.title?.length > 3)
    .map((t) => ({
      id: crypto.randomUUID(),
      title: t.title,
      body: t.body,
      category: t.category ?? "general",
      createdAt: nowStr,
      ...(t.suggestedTime ? {suggestedTime: t.suggestedTime} : {}),
    }));
}

async function saveTips(
  userID: string,
  tips: Tip[],
  readings: Reading[],
  activities: Activity[]
): Promise<void> {
  await db.collection("aiTips").doc(userID).set({
    userID,
    tips,
    generatedAt: admin.firestore.FieldValue.serverTimestamp(),
    basedOn: {readingCount: readings.length, activityCount: activities.length},
  });
}
