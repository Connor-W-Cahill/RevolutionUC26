/**
 * Seed script — creates 5 test users in Firebase Auth + Firestore.
 * All passwords: root
 *
 * Usage:
 *   cd functions
 *   node seed.js
 *
 * Requires: GOOGLE_APPLICATION_CREDENTIALS env var pointing to a service account key,
 * OR run `firebase login` and use Application Default Credentials.
 */

const admin = require("firebase-admin");
const fs = require("fs");

// ── Init ──────────────────────────────────────────────────────────────────────
// Option A: pass a service account key path as the first argument
//   node seed.js /path/to/serviceAccountKey.json
// Option B: set GOOGLE_APPLICATION_CREDENTIALS env var to the key path
//   GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json node seed.js
//
// Get a key from: Firebase Console → Project Settings → Service Accounts
//                 → Generate new private key

const keyArg = process.argv[2];
if (keyArg) {
  const serviceAccount = JSON.parse(fs.readFileSync(keyArg, "utf8"));
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: "revolutionuc26",
  });
} else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  admin.initializeApp({ projectId: "revolutionuc26" });
} else {
  console.error("❌ No credentials found.");
  console.error("   Run: node seed.js /path/to/serviceAccountKey.json");
  console.error("   Or:  GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json node seed.js");
  console.error("\n   Get a key from: Firebase Console → Project Settings → Service Accounts");
  process.exit(1);
}

const auth = admin.auth();
const db = admin.firestore();

// ── Test users ────────────────────────────────────────────────────────────────

const TEST_USERS = [
  { displayName: "Alice Chen",    email: "alice@test.com" },
  { displayName: "Bob Martinez",  email: "bob@test.com" },
  { displayName: "Chloe Kim",     email: "chloe@test.com" },
  { displayName: "David Patel",   email: "david@test.com" },
  { displayName: "Emma Wilson",   email: "emma@test.com" },
];

const PASSWORD = "rootroot"; // Firebase requires ≥6 chars

// ── Helpers ───────────────────────────────────────────────────────────────────

function randomBetween(min, max) {
  return Math.random() * (max - min) + min;
}

function daysAgo(n) {
  const d = new Date();
  d.setDate(d.getDate() - n);
  return d;
}

function hoursAgo(n) {
  return new Date(Date.now() - n * 3600 * 1000);
}

/** Generate realistic readings spread over the last 7 days */
function generateReadings(userID) {
  const readings = [];
  for (let day = 6; day >= 0; day--) {
    const countForDay = Math.floor(randomBetween(1, 4)); // 1-3 per day
    for (let i = 0; i < countForDay; i++) {
      const pulseRate    = Math.round(randomBetween(58, 105));
      const breathingRate = Math.round(randomBetween(12, 22));
      const timestamp    = daysAgo(day);
      timestamp.setHours(Math.floor(randomBetween(7, 22)), Math.floor(randomBetween(0, 59)));

      readings.push({
        id: db.collection("readings").doc().id,
        userID,
        timestamp: admin.firestore.Timestamp.fromDate(timestamp),
        pulseRate,
        breathingRate,
        bloodPressureSystolic: Math.round(randomBetween(110, 145)),
        stressLevel: Math.round(randomBetween(10, 85)),
        hrv: Math.round(randomBetween(20, 80)),
        spO2: Math.round(randomBetween(95, 100)),
        respiratoryRate: breathingRate,
        source: "presage",
        isSpikeCandidate: pulseRate > 95,
      });
    }
  }
  return readings;
}

const ACTIVITY_TEMPLATES = [
  { category: "sleep",    title: "Night sleep",      notes: "7 hours, woke up once" },
  { category: "exercise", title: "Morning run",       notes: "3km, felt good" },
  { category: "diet",     title: "Healthy lunch",     notes: "Salad and chicken" },
  { category: "stressor", title: "Work deadline",     notes: "Presentation prep" },
  { category: "sleep",    title: "Power nap",         notes: "20 mins" },
  { category: "exercise", title: "Gym session",       notes: "Upper body" },
  { category: "diet",     title: "Skipped breakfast", notes: null },
  { category: "other",    title: "Meditation",        notes: "10 min guided" },
];

/** Generate 5 activities spread over the last 3 days */
function generateActivities(userID) {
  return ACTIVITY_TEMPLATES.slice(0, 5).map((tmpl, i) => {
    const date = daysAgo(i % 3);
    const dateStr = date.toISOString().split("T")[0];
    return {
      id: db.collection("activities").doc().id,
      userID,
      date: dateStr,
      category: tmpl.category,
      title: tmpl.title,
      notes: tmpl.notes,
      rating: Math.floor(randomBetween(2, 6)), // 2-5
    };
  });
}

// ── Main ──────────────────────────────────────────────────────────────────────

async function seed() {
  console.log("🌱 Seeding test users...\n");

  const uids = [];

  for (const u of TEST_USERS) {
    // Create or update Auth user
    let uid;
    try {
      const existing = await auth.getUserByEmail(u.email);
      uid = existing.uid;
      await auth.updateUser(uid, { password: PASSWORD, displayName: u.displayName });
      console.log(`  ✓ Updated existing auth user: ${u.email} (${uid})`);
    } catch {
      const created = await auth.createUser({
        email: u.email,
        password: PASSWORD,
        displayName: u.displayName,
      });
      uid = created.uid;
      console.log(`  ✓ Created auth user: ${u.email} (${uid})`);
    }
    uids.push({ ...u, uid });

    // Write Firestore user doc
    await db.collection("users").doc(uid).set({
      id: uid,
      displayName: u.displayName,
      email: u.email,
      friendIDs: [],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      timezone: "America/New_York",
    });
  }

  // Make all 5 users friends with each other
  console.log("\n  👥 Creating friendships...");
  for (let i = 0; i < uids.length; i++) {
    for (let j = i + 1; j < uids.length; j++) {
      const a = uids[i].uid < uids[j].uid ? uids[i].uid : uids[j].uid;
      const b = a === uids[i].uid ? uids[j].uid : uids[i].uid;
      const docID = `${a}_${b}`;
      await db.collection("friendships").doc(docID).set({
        userA: a, userB: b,
        status: "accepted",
        initiatedBy: a,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      // Update friendIDs on both users
      await db.collection("users").doc(a).update({ friendIDs: admin.firestore.FieldValue.arrayUnion(b) });
      await db.collection("users").doc(b).update({ friendIDs: admin.firestore.FieldValue.arrayUnion(a) });
    }
  }
  console.log(`  ✓ Created ${uids.length * (uids.length - 1) / 2} friendships`);

  // Write readings and activities for each user
  console.log("\n  📊 Writing readings and activities...");
  for (const { uid, displayName } of uids) {
    const readings   = generateReadings(uid);
    const activities = generateActivities(uid);

    const batch = db.batch();
    readings.forEach(r   => batch.set(db.collection("readings").doc(r.id),   r));
    activities.forEach(a => batch.set(db.collection("activities").doc(a.id), a));
    await batch.commit();

    console.log(`  ✓ ${displayName}: ${readings.length} readings, ${activities.length} activities`);
  }

  console.log("\n✅ Seed complete!\n");
  console.log("Test accounts (password: rootroot):");
  uids.forEach(u => console.log(`  ${u.email}`));
}

seed().catch(err => {
  console.error("❌ Seed failed:", err.message);
  process.exit(1);
});
