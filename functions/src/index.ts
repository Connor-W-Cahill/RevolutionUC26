import * as admin from "firebase-admin";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";

admin.initializeApp();
const db = admin.firestore();

// ──────────────────────────────────────────
// Types
// ──────────────────────────────────────────

interface Tip {
  id: string;
  title: string;
  body: string;
  category: string;
  createdAt: string;
}

interface DayTrend {
  date: string;
  avgPulseRate: number | null;
  avgBreathingRate: number | null;
  readingCount: number;
}

// ──────────────────────────────────────────
// Tips (hardcoded pool)
// ──────────────────────────────────────────

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
  const shuffled = [...TIPS_POOL].sort(() => Math.random() - 0.5);
  return shuffled.slice(0, count).map((t, i) => ({
    ...t,
    id: `tip_${Date.now()}_${i}`,
    createdAt: now,
  }));
}

/**
 * Generate tips for the authenticated user.
 */
export const generateTips = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in");
  }

  const userID = request.auth.uid;
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

// ──────────────────────────────────────────
// Friend Management
// ──────────────────────────────────────────

function makeFriendshipID(uidA: string, uidB: string): string {
  return uidA < uidB ? `${uidA}_${uidB}` : `${uidB}_${uidA}`;
}

/**
 * Send a friend request to another user.
 * Input: { targetUserID: string }
 * Returns: { friendshipID: string, status: "pending" }
 */
export const sendFriendRequest = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in");
  }

  const senderID = request.auth.uid;
  const targetUserID = request.data?.targetUserID;

  if (!targetUserID || typeof targetUserID !== "string") {
    throw new HttpsError("invalid-argument", "targetUserID is required");
  }

  if (senderID === targetUserID) {
    throw new HttpsError("invalid-argument", "Cannot friend yourself");
  }

  // Check target user exists
  const targetDoc = await db.collection("users").doc(targetUserID).get();
  if (!targetDoc.exists) {
    throw new HttpsError("not-found", "User not found");
  }

  const friendshipID = makeFriendshipID(senderID, targetUserID);
  const friendshipRef = db.collection("friendships").doc(friendshipID);

  // Check if friendship already exists
  const existing = await friendshipRef.get();
  if (existing.exists) {
    const data = existing.data()!;
    if (data.status === "accepted") {
      throw new HttpsError("already-exists", "Already friends");
    }
    if (data.status === "pending") {
      throw new HttpsError("already-exists", "Friend request already pending");
    }
    // If declined, allow re-sending
  }

  const userA = senderID < targetUserID ? senderID : targetUserID;
  const userB = senderID < targetUserID ? targetUserID : senderID;
  const now = admin.firestore.FieldValue.serverTimestamp();

  await friendshipRef.set({
    userA,
    userB,
    status: "pending",
    initiatedBy: senderID,
    createdAt: now,
    updatedAt: now,
  });

  return {friendshipID, status: "pending"};
});

/**
 * Respond to a friend request (accept or decline).
 * Input: { friendshipID: string, action: "accept" | "decline" }
 * Returns: { status: "accepted" | "declined" }
 */
export const respondToFriendRequest = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in");
  }

  const userID = request.auth.uid;
  const friendshipID = request.data?.friendshipID;
  const action = request.data?.action;

  if (!friendshipID || typeof friendshipID !== "string") {
    throw new HttpsError("invalid-argument", "friendshipID is required");
  }
  if (action !== "accept" && action !== "decline") {
    throw new HttpsError("invalid-argument", "action must be 'accept' or 'decline'");
  }

  const friendshipRef = db.collection("friendships").doc(friendshipID);
  const friendshipDoc = await friendshipRef.get();

  if (!friendshipDoc.exists) {
    throw new HttpsError("not-found", "Friend request not found");
  }

  const data = friendshipDoc.data()!;

  // Only the non-initiator can respond
  if (data.initiatedBy === userID) {
    throw new HttpsError("permission-denied", "Cannot respond to your own request");
  }

  // Must be one of the two users
  if (data.userA !== userID && data.userB !== userID) {
    throw new HttpsError("permission-denied", "Not your friend request");
  }

  if (data.status !== "pending") {
    throw new HttpsError("failed-precondition", `Request is already ${data.status}`);
  }

  const newStatus = action === "accept" ? "accepted" : "declined";

  const batch = db.batch();
  batch.update(friendshipRef, {
    status: newStatus,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // If accepted, update both users' friendIDs arrays
  if (newStatus === "accepted") {
    const otherUserID = data.userA === userID ? data.userB : data.userA;
    batch.update(db.collection("users").doc(userID), {
      friendIDs: admin.firestore.FieldValue.arrayUnion(otherUserID),
    });
    batch.update(db.collection("users").doc(otherUserID), {
      friendIDs: admin.firestore.FieldValue.arrayUnion(userID),
    });
  }

  await batch.commit();

  return {status: newStatus};
});

/**
 * Get pending friend requests for the authenticated user.
 * Returns: { incoming: [...], outgoing: [...] }
 */
export const getFriendRequests = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in");
  }

  const userID = request.auth.uid;

  // Get all pending friendships where user is involved
  const asUserA = await db.collection("friendships")
    .where("userA", "==", userID)
    .where("status", "==", "pending")
    .get();

  const asUserB = await db.collection("friendships")
    .where("userB", "==", userID)
    .where("status", "==", "pending")
    .get();

  const incoming: Array<{friendshipID: string; fromUserID: string; createdAt: unknown}> = [];
  const outgoing: Array<{friendshipID: string; toUserID: string; createdAt: unknown}> = [];

  const processDoc = (doc: admin.firestore.QueryDocumentSnapshot) => {
    const d = doc.data();
    const otherUser = d.userA === userID ? d.userB : d.userA;
    if (d.initiatedBy === userID) {
      outgoing.push({friendshipID: doc.id, toUserID: otherUser, createdAt: d.createdAt});
    } else {
      incoming.push({friendshipID: doc.id, fromUserID: otherUser, createdAt: d.createdAt});
    }
  };

  asUserA.docs.forEach(processDoc);
  asUserB.docs.forEach(processDoc);

  return {incoming, outgoing};
});

// ──────────────────────────────────────────
// Weekly Trends
// ──────────────────────────────────────────

/**
 * Get weekly trend data for the authenticated user.
 * Returns daily averages for the last 7 days.
 * Returns: { trends: DayTrend[] }
 */
export const getWeeklyTrends = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in");
  }

  const userID = request.auth.uid;
  const now = new Date();
  const weekAgo = new Date(now);
  weekAgo.setDate(weekAgo.getDate() - 7);

  const readingsSnap = await db
    .collection("readings")
    .where("userID", "==", userID)
    .where("timestamp", ">=", admin.firestore.Timestamp.fromDate(weekAgo))
    .orderBy("timestamp", "desc")
    .get();

  // Group readings by date
  const byDate = new Map<string, Array<{pulseRate?: number; breathingRate?: number}>>();

  for (const doc of readingsSnap.docs) {
    const data = doc.data();
    const date = (data.timestamp as admin.firestore.Timestamp)
      .toDate()
      .toISOString()
      .split("T")[0];

    if (!byDate.has(date)) {
      byDate.set(date, []);
    }
    byDate.get(date)!.push({
      pulseRate: data.pulseRate,
      breathingRate: data.breathingRate,
    });
  }

  // Build trend for each of the last 7 days
  const trends: DayTrend[] = [];
  for (let i = 6; i >= 0; i--) {
    const d = new Date(now);
    d.setDate(d.getDate() - i);
    const dateStr = d.toISOString().split("T")[0];
    const dayReadings = byDate.get(dateStr) || [];

    if (dayReadings.length === 0) {
      trends.push({
        date: dateStr,
        avgPulseRate: null,
        avgBreathingRate: null,
        readingCount: 0,
      });
    } else {
      const pulseValues = dayReadings
        .map((r) => r.pulseRate)
        .filter((v): v is number => v != null);
      const breathingValues = dayReadings
        .map((r) => r.breathingRate)
        .filter((v): v is number => v != null);

      trends.push({
        date: dateStr,
        avgPulseRate: pulseValues.length > 0
          ? Math.round((pulseValues.reduce((a, b) => a + b, 0) / pulseValues.length) * 10) / 10
          : null,
        avgBreathingRate: breathingValues.length > 0
          ? Math.round((breathingValues.reduce((a, b) => a + b, 0) / breathingValues.length) * 10) / 10
          : null,
        readingCount: dayReadings.length,
      });
    }
  }

  return {trends};
});
