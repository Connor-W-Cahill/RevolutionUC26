import * as admin from "firebase-admin";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {defineSecret} from "firebase-functions/params";
import Anthropic from "@anthropic-ai/sdk";
import * as crypto from "crypto";

admin.initializeApp();
const db = admin.firestore();

const anthropicApiKey = defineSecret("ANTHROPIC_API_KEY");

interface Reading {
  userID: string;
  heartRate: number;
  hrv: number;
  spO2: number;
  respiratoryRate: number;
  stressLevel: number;
  timestamp: admin.firestore.Timestamp;
}

interface Activity {
  userID: string;
  category: string;
  title: string;
  date: string;
  notes?: string;
  rating?: number;
}

interface Tip {
  id: string;
  title: string;
  body: string;
  category: string;
  createdAt: string;
}

/**
 * Generate AI tips for the authenticated user based on their recent readings
 * and activities. Fetches data server-side from Firestore — client just calls it.
 *
 * Returns: { tips: Tip[] }
 */
export const generateTips = onCall(
  {secrets: [anthropicApiKey]},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be logged in");
    }

    const userID = request.auth.uid;
    const tips = await generateTipsForUser(userID);
    return {tips};
  }
);

/**
 * Scheduled function: generate tips for all active users daily at 8am UTC.
 */
export const dailyTipsGeneration = onSchedule(
  {schedule: "0 8 * * *", secrets: [anthropicApiKey]},
  async () => {
    const usersSnap = await db.collection("users").get();
    const promises = usersSnap.docs.map((doc) =>
      generateTipsForUser(doc.id).catch((err) =>
        console.error(`Failed to generate tips for ${doc.id}:`, err)
      )
    );
    await Promise.all(promises);
  }
);

async function generateTipsForUser(userID: string): Promise<Tip[]> {
  const weekAgo = new Date();
  weekAgo.setDate(weekAgo.getDate() - 7);

  const readingsSnap = await db
    .collection("readings")
    .where("userID", "==", userID)
    .where("timestamp", ">=", admin.firestore.Timestamp.fromDate(weekAgo))
    .orderBy("timestamp", "desc")
    .limit(50)
    .get();

  const readings: Reading[] = readingsSnap.docs.map(
    (d) => d.data() as Reading
  );

  const activitiesSnap = await db
    .collection("activities")
    .where("userID", "==", userID)
    .where("date", ">=", admin.firestore.Timestamp.fromDate(weekAgo))
    .orderBy("date", "desc")
    .limit(50)
    .get();

  const activities: Activity[] = activitiesSnap.docs.map(
    (d) => d.data() as Activity
  );

  if (readings.length === 0) {
    const now = new Date().toISOString();
    const defaultTips: Tip[] = [
      {
        id: crypto.randomUUID(),
        title: "Get Started",
        body: "Take your first stress reading to get personalized tips!",
        category: "general",
        createdAt: now,
      },
    ];
    await saveTips(userID, defaultTips, readings, activities);
    return defaultTips;
  }

  const tips = await callAI(readings, activities);
  await saveTips(userID, tips, readings, activities);
  return tips;
}

async function callAI(
  readings: Reading[],
  activities: Activity[]
): Promise<Tip[]> {
  const client = new Anthropic();

  const readingSummary = readings.map((r) => ({
    heartRate: r.heartRate,
    hrv: r.hrv,
    spO2: r.spO2,
    respiratoryRate: r.respiratoryRate,
    stressLevel: r.stressLevel,
    time: r.timestamp.toDate().toISOString(),
  }));

  const activitySummary = activities.map((a) => ({
    category: a.category,
    title: a.title,
    date: a.date,
    notes: a.notes,
    rating: a.rating,
  }));

  const prompt = `You are a wellness advisor. Based on the user's recent stress/vitals readings and lifestyle activities, generate 3-5 actionable tips to help them manage their cortisol and stress levels.

Recent readings (newest first):
${JSON.stringify(readingSummary, null, 2)}

Recent activities:
${JSON.stringify(activitySummary, null, 2)}

Respond with ONLY a JSON array of tips, each with:
- "title": short title (3-6 words)
- "body": the tip (1-2 sentences, actionable)
- "category": one of "breathing", "exercise", "sleep", "nutrition", "mindfulness", "social", "general"

Example: [{"title": "Try 4-7-8 Breathing", "body": "Practice 4-7-8 breathing before bed to lower your evening stress levels.", "category": "breathing"}]`;

  const message = await client.messages.create({
    model: "claude-haiku-4-5-20251001",
    max_tokens: 1024,
    messages: [{role: "user", content: prompt}],
  });

  const text =
    message.content[0].type === "text" ? message.content[0].text : "";
  const jsonMatch = text.match(/\[[\s\S]*\]/);
  if (!jsonMatch) {
    return [{
      id: crypto.randomUUID(),
      title: "Breathe Deep",
      body: "Take a few deep breaths when feeling stressed.",
      category: "breathing",
      createdAt: new Date().toISOString(),
    }];
  }

  const now = new Date().toISOString();
  const raw = JSON.parse(jsonMatch[0]) as Array<{title: string; body: string; category: string}>;
  return raw.map((t) => ({
    id: crypto.randomUUID(),
    title: t.title,
    body: t.body,
    category: t.category,
    createdAt: now,
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
    basedOn: {
      readingCount: readings.length,
      activityCount: activities.length,
    },
  });
}
