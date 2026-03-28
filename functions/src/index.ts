import * as admin from "firebase-admin";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";

admin.initializeApp();
const db = admin.firestore();

interface Tip {
  id: string;
  title: string;
  body: string;
  category: string;
  createdAt: string;
}

// Hardcoded wellness tips — grouped by category for variety
const TIPS_POOL: Omit<Tip, "id" | "createdAt">[] = [
  {title: "Box Breathing", body: "Try 4-4-4-4 box breathing: inhale 4s, hold 4s, exhale 4s, hold 4s. Repeat 4 times to activate your parasympathetic nervous system.", category: "breathing"},
  {title: "4-7-8 Technique", body: "Before bed, try 4-7-8 breathing: inhale 4s, hold 7s, exhale 8s. This can lower your resting heart rate.", category: "breathing"},
  {title: "Take a Walk", body: "A 10-minute walk outside can reduce cortisol by up to 14%. Even a short break from screens helps.", category: "exercise"},
  {title: "Stretch Break", body: "Stand up and do 2 minutes of gentle stretching. Focus on neck, shoulders, and hip flexors to release tension.", category: "exercise"},
  {title: "Sleep Schedule", body: "Try to go to bed and wake up at the same time every day. Consistent sleep is one of the best cortisol regulators.", category: "sleep"},
  {title: "Screen Curfew", body: "Put screens away 30 minutes before bed. Blue light suppresses melatonin and keeps cortisol elevated.", category: "sleep"},
  {title: "Hydrate First", body: "Start your day with a glass of water before coffee. Dehydration elevates cortisol.", category: "nutrition"},
  {title: "Limit Caffeine", body: "Try cutting off caffeine by 2pm. Late caffeine can elevate cortisol for up to 6 hours.", category: "nutrition"},
  {title: "5-Minute Meditation", body: "Spend 5 minutes focusing on your breath. Even brief meditation sessions measurably lower stress hormones.", category: "mindfulness"},
  {title: "Body Scan", body: "Do a quick body scan: notice tension in your jaw, shoulders, and hands. Consciously relax each area.", category: "mindfulness"},
  {title: "Connect with Someone", body: "Send a message or call a friend. Social connection triggers oxytocin release, which counteracts cortisol.", category: "social"},
  {title: "Gratitude Check", body: "Write down 3 things you're grateful for today. Gratitude journaling has been shown to lower cortisol levels.", category: "mindfulness"},
];

function selectTips(count: number): Tip[] {
  const now = new Date().toISOString();
  // Shuffle and pick
  const shuffled = [...TIPS_POOL].sort(() => Math.random() - 0.5);
  return shuffled.slice(0, count).map((t, i) => ({
    ...t,
    id: `tip_${Date.now()}_${i}`,
    createdAt: now,
  }));
}

/**
 * Generate tips for the authenticated user.
 * Currently returns hardcoded wellness tips (AI integration planned for later).
 */
export const generateTips = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in");
  }

  const userID = request.auth.uid;

  // Check if user has any readings to personalize tip count
  const readingsSnap = await db
    .collection("readings")
    .where("userID", "==", userID)
    .limit(1)
    .get();

  const hasReadings = !readingsSnap.empty;
  const tips = hasReadings
    ? selectTips(4)
    : [{
        id: `tip_${Date.now()}_0`,
        title: "Get Started",
        body: "Take your first reading to start tracking your stress levels!",
        category: "general",
        createdAt: new Date().toISOString(),
      }];

  await db.collection("aiTips").doc(userID).set({
    userID,
    tips,
    generatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {tips};
});

/**
 * Scheduled: refresh tips for all users daily at 8am UTC.
 */
export const dailyTipsGeneration = onSchedule(
  {schedule: "0 8 * * *"},
  async () => {
    const usersSnap = await db.collection("users").get();
    const promises = usersSnap.docs.map(async (doc) => {
      const tips = selectTips(4);
      await db.collection("aiTips").doc(doc.id).set({
        userID: doc.id,
        tips,
        generatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
    await Promise.all(promises);
  }
);
