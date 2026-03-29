package com.revolutionuc.cortisoltracker.android

import com.google.firebase.Timestamp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.ktx.auth
import com.google.firebase.firestore.DocumentSnapshot
import com.google.firebase.firestore.FieldPath
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.Query
import com.google.firebase.firestore.ktx.firestore
import com.google.firebase.functions.FirebaseFunctions
import com.google.firebase.functions.ktx.functions
import com.google.firebase.ktx.Firebase
import java.security.SecureRandom
import java.util.Date
import java.util.UUID
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await

enum class ReadingSource { PRESAGE, MANUAL, IMPORTED, DEMO }

enum class StressCategory(val label: String, val emoji: String) {
    LOW("Low", "\uD83D\uDE0C"),
    MODERATE("Moderate", "\uD83D\uDE10"),
    HIGH("High", "\uD83D\uDE30"),
    VERY_HIGH("Very High", "\uD83E\uDD2F");

    val brandColor
        get() = when (this) {
            LOW -> DeepTeal
            MODERATE -> ColorPalette.Moderate
            HIGH -> ColorPalette.High
            VERY_HIGH -> ColorPalette.VeryHigh
        }
}

object ColorPalette {
    val Moderate = androidx.compose.ui.graphics.Color(0xFF9A7B00)
    val High = androidx.compose.ui.graphics.Color(0xFFC45F1A)
    val VeryHigh = androidx.compose.ui.graphics.Color(0xFFB8344E)
}

data class SharingDefaults(
    val latestStress: Boolean = true,
    val history: Boolean = false,
    val groupStats: Boolean = false
)

data class AppUser(
    val id: String,
    val displayName: String,
    val email: String,
    val photoUrl: String? = null,
    val friendIds: List<String> = emptyList(),
    val createdAt: Date = Date(),
    val sharingDefaults: SharingDefaults? = null,
    val timezone: String? = null
)

data class CortisolReading(
    val id: String = UUID.randomUUID().toString(),
    val userId: String,
    val timestamp: Date = Date(),
    val pulseRate: Double,
    val breathingRate: Double,
    val bloodPressureSystolic: Double? = null,
    val bloodPressureDiastolic: Double? = null,
    val source: ReadingSource? = null,
    val isSpikeCandidate: Boolean? = null,
    private val storedStressLevel: Double? = null,
    private val storedHrv: Double? = null,
    private val storedSpO2: Double? = null
) {
    val stressLevel: Double
        get() {
            storedStressLevel?.let { return it }
            val pulseStress = ((pulseRate - 60.0) / 40.0 * 50.0).coerceIn(0.0, 50.0)
            val breathingStress = ((breathingRate - 12.0) / 8.0 * 50.0).coerceIn(0.0, 50.0)
            return (pulseStress + breathingStress).coerceIn(0.0, 100.0)
        }

    val heartRate: Double get() = pulseRate
    val hrv: Double get() = storedHrv ?: maxOf(20.0, 120.0 - pulseRate)
    val spO2: Double get() = storedSpO2 ?: 98.0
    val respiratoryRate: Double get() = breathingRate
    val stressCategory: StressCategory
        get() = when {
            stressLevel < 25 -> StressCategory.LOW
            stressLevel < 50 -> StressCategory.MODERATE
            stressLevel < 75 -> StressCategory.HIGH
            else -> StressCategory.VERY_HIGH
        }

    fun toMap(): Map<String, Any?> = mapOf(
        "id" to id,
        "userID" to userId,
        "timestamp" to timestamp,
        "pulseRate" to pulseRate,
        "breathingRate" to breathingRate,
        "bloodPressureSystolic" to bloodPressureSystolic,
        "bloodPressureDiastolic" to bloodPressureDiastolic,
        "stressLevel" to stressLevel,
        "heartRate" to heartRate,
        "hrv" to hrv,
        "spO2" to spO2,
        "respiratoryRate" to respiratoryRate,
        "source" to source?.name?.lowercase(),
        "isSpikeCandidate" to isSpikeCandidate
    ).filterValues { it != null }
}

enum class ActivityCategory(val wireValue: String, val icon: String) {
    SLEEP("Sleep", "bed"),
    DIET("Diet", "restaurant"),
    EXERCISE("Exercise", "directions_run"),
    WORK("Work", "laptop"),
    SOCIAL("Social", "groups"),
    MEDITATION("Meditation", "self_improvement"),
    OTHER("Other", "more_horiz");

    companion object {
        fun fromWire(value: String?): ActivityCategory =
            entries.firstOrNull { it.wireValue.equals(value, ignoreCase = true) } ?: OTHER
    }
}

data class ActivityEntry(
    val id: String = UUID.randomUUID().toString(),
    val userId: String,
    val date: Date = Date(),
    val category: ActivityCategory,
    val title: String,
    val notes: String? = null,
    val rating: Int? = null
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "id" to id,
        "userID" to userId,
        "date" to date,
        "category" to category.wireValue,
        "title" to title,
        "notes" to notes,
        "rating" to rating
    ).filterValues { it != null }
}

data class Tip(
    val id: String,
    val title: String,
    val body: String,
    val category: TipCategory,
    val createdAt: String,
    val suggestedTime: String? = null
)

enum class TipCategory(val wireValue: String, val label: String, val icon: String) {
    BREATHING("breathing", "Breathing", "air"),
    EXERCISE("exercise", "Exercise", "directions_run"),
    SLEEP("sleep", "Sleep", "dark_mode"),
    NUTRITION("nutrition", "Nutrition", "eco"),
    MINDFULNESS("mindfulness", "Mindfulness", "psychology"),
    SOCIAL("social", "Social", "group"),
    GENERAL("general", "General", "lightbulb");

    companion object {
        fun fromWire(value: String?): TipCategory =
            entries.firstOrNull { it.wireValue == value } ?: GENERAL
    }
}

data class Friend(
    val id: String,
    val displayName: String,
    val photoUrl: String? = null,
    val latestStressLevel: Double? = null,
    val latestReadingTime: Date? = null
) {
    val stressCategory: StressCategory?
        get() = latestStressLevel?.let {
            when {
                it < 25 -> StressCategory.LOW
                it < 50 -> StressCategory.MODERATE
                it < 75 -> StressCategory.HIGH
                else -> StressCategory.VERY_HIGH
            }
        }
}

data class SharePermissions(
    val latestStress: Boolean = true,
    val history: Boolean = false,
    val groupStats: Boolean = false
)

data class ShareRecord(
    val id: String,
    val ownerId: String,
    val viewerId: String,
    val status: String,
    val permissions: SharePermissions,
    val createdAt: Date? = null,
    val updatedAt: Date? = null
)

data class SpikeEvent(
    val id: String,
    val userId: String,
    val readingId: String,
    val timestamp: Date,
    val stressLevel: Double,
    val baselineMean: Double,
    val baselineStdDev: Double,
    val delta: Double,
    val severity: String,
    val triggerReason: String
)

data class Streak(
    val userId: String,
    val currentReadingStreak: Int,
    val bestReadingStreak: Int,
    val lastReadingDate: String,
    val currentActivityStreak: Int,
    val bestActivityStreak: Int,
    val lastActivityDate: String,
    val updatedAt: Date? = null
)

data class StressGroup(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val ownerId: String,
    val memberIds: List<String> = emptyList(),
    val createdAt: Date = Date(),
    val updatedAt: Date = Date(),
    val visibility: String = "private"
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "id" to id,
        "name" to name,
        "ownerID" to ownerId,
        "memberIDs" to memberIds,
        "createdAt" to createdAt,
        "updatedAt" to updatedAt,
        "visibility" to visibility
    )
}

data class GroupDailyStat(
    val id: String,
    val groupId: String,
    val date: String,
    val memberCount: Int,
    val activeMemberCount: Int,
    val avgStress: Double?,
    val minStress: Double?,
    val maxStress: Double?
)

data class DayTrend(
    val date: String,
    val avgPulseRate: Double?,
    val avgBreathingRate: Double?,
    val readingCount: Int
)

interface MeasurementProvider {
    suspend fun captureReading(userId: String): CortisolReading
}

class DemoMeasurementProvider(
    private val random: SecureRandom = SecureRandom()
) : MeasurementProvider {
    override suspend fun captureReading(userId: String): CortisolReading {
        val pulse = 62 + random.nextInt(35)
        val breathing = 12 + random.nextInt(10)
        val systolic = 108 + random.nextInt(22)
        return CortisolReading(
            userId = userId,
            pulseRate = pulse.toDouble(),
            breathingRate = breathing.toDouble(),
            bloodPressureSystolic = systolic.toDouble(),
            source = ReadingSource.DEMO
        )
    }
}

class CortisolRepository(
    private val auth: FirebaseAuth,
    private val db: FirebaseFirestore,
    private val functions: FirebaseFunctions,
    private val measurementProvider: MeasurementProvider
) {
    private val appScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    val currentUserId: String?
        get() = auth.currentUser?.uid

    fun authState(): Flow<String?> = callbackFlow {
        val listener = FirebaseAuth.AuthStateListener { firebaseAuth ->
            trySend(firebaseAuth.currentUser?.uid)
        }
        auth.addAuthStateListener(listener)
        awaitClose { auth.removeAuthStateListener(listener) }
    }.flowOn(Dispatchers.IO)

    suspend fun signIn(email: String, password: String): AppUser {
        val result = auth.signInWithEmailAndPassword(email, password).await()
        return fetchUser(result.user?.uid ?: error("Missing user ID"))
            ?: error("Missing Firestore user profile")
    }

    suspend fun signUp(email: String, password: String, displayName: String): AppUser {
        val result = auth.createUserWithEmailAndPassword(email, password).await()
        val uid = result.user?.uid ?: error("Missing user ID")
        val user = AppUser(id = uid, displayName = displayName, email = email)
        saveUser(user)
        return user
    }

    suspend fun signOut() {
        auth.signOut()
    }

    suspend fun fetchUser(id: String): AppUser? {
        val doc = db.collection("users").document(id).get().await()
        if (!doc.exists()) return null
        return doc.toAppUser()
    }

    suspend fun saveUser(user: AppUser) {
        db.collection("users").document(user.id).set(user.toMap()).await()
    }

    suspend fun fetchReadingsForDate(userId: String, date: Date): List<CortisolReading> {
        val (start, end) = dayBounds(date)
        return db.collection("readings")
            .whereEqualTo("userID", userId)
            .whereGreaterThanOrEqualTo("timestamp", start)
            .whereLessThan("timestamp", end)
            .orderBy("timestamp", Query.Direction.DESCENDING)
            .get()
            .await()
            .documents
            .mapNotNull { it.toReading() }
    }

    suspend fun fetchLatestReadings(userId: String, limit: Int = 20): List<CortisolReading> =
        db.collection("readings")
            .whereEqualTo("userID", userId)
            .orderBy("timestamp", Query.Direction.DESCENDING)
            .limit(limit.toLong())
            .get()
            .await()
            .documents
            .mapNotNull { it.toReading() }

    suspend fun saveReading(reading: CortisolReading) {
        db.collection("readings").document(reading.id).set(reading.toMap()).await()
    }

    suspend fun captureMeasurement(userId: String): CortisolReading =
        measurementProvider.captureReading(userId)

    suspend fun fetchActivitiesForDate(userId: String, date: Date): List<ActivityEntry> {
        val (start, end) = dayBounds(date)
        return db.collection("activities")
            .whereEqualTo("userID", userId)
            .whereGreaterThanOrEqualTo("date", start)
            .whereLessThan("date", end)
            .orderBy("date", Query.Direction.DESCENDING)
            .get()
            .await()
            .documents
            .mapNotNull { it.toActivity() }
    }

    suspend fun saveActivity(activityEntry: ActivityEntry) {
        db.collection("activities").document(activityEntry.id).set(activityEntry.toMap()).await()
    }

    suspend fun fetchSpikeEvents(userId: String, limit: Int = 1): List<SpikeEvent> =
        db.collection("spikeEvents")
            .whereEqualTo("userID", userId)
            .orderBy("timestamp", Query.Direction.DESCENDING)
            .limit(limit.toLong())
            .get()
            .await()
            .documents
            .mapNotNull { it.toSpikeEvent() }

    suspend fun fetchStreak(userId: String): Streak? {
        val doc = db.collection("streaks").document(userId).get().await()
        return if (doc.exists()) doc.toStreak() else null
    }

    suspend fun fetchFriends(): List<Friend> {
        val userId = currentUserId ?: return emptyList()
        val user = fetchUser(userId) ?: return emptyList()
        if (user.friendIds.isEmpty()) return emptyList()

        val chunks = user.friendIds.chunked(30)
        val friends = mutableListOf<Friend>()
        for (chunk in chunks) {
            val snapshot = db.collection("users")
                .whereIn(FieldPath.documentId(), chunk)
                .get()
                .await()
            friends += snapshot.documents.mapNotNull { it.toFriend() }
        }

        return kotlinx.coroutines.coroutineScope {
            friends.map { friend ->
                async {
                    val latest = db.collection("readings")
                        .whereEqualTo("userID", friend.id)
                        .orderBy("timestamp", Query.Direction.DESCENDING)
                        .limit(1)
                        .get()
                        .await()
                        .documents
                        .firstOrNull()
                        ?.toReading()
                    friend.copy(
                        latestStressLevel = latest?.stressLevel,
                        latestReadingTime = latest?.timestamp
                    )
                }
            }.awaitAll()
        }
    }

    suspend fun searchUsers(query: String): List<Friend> {
        if (query.isBlank()) return emptyList()
        val snapshot = db.collection("users")
            .whereGreaterThanOrEqualTo("displayName", query)
            .whereLessThanOrEqualTo("displayName", "$query\uf8ff")
            .limit(20)
            .get()
            .await()
        val currentId = currentUserId
        return snapshot.documents
            .mapNotNull { it.toFriend() }
            .filter { it.id != currentId }
    }

    suspend fun sendFriendRequest(targetUserId: String) {
        functions
            .getHttpsCallable("sendFriendRequest")
            .call(mapOf("targetUserID" to targetUserId))
            .await()
    }

    suspend fun getFriendRequests(): Pair<List<Map<String, Any?>>, List<Map<String, Any?>>> {
        val result = functions.getHttpsCallable("getFriendRequests").call().await().data as? Map<*, *> ?: emptyMap<Any, Any>()
        val incoming = result["incoming"] as? List<Map<String, Any?>> ?: emptyList()
        val outgoing = result["outgoing"] as? List<Map<String, Any?>> ?: emptyList()
        return incoming to outgoing
    }

    suspend fun fetchTips(): List<Tip> {
        return try {
            val result = functions.getHttpsCallable("generateTips").call().await().data as? Map<*, *>
            val tipsData = result?.get("tips") as? List<Map<String, Any?>> ?: emptyList()
            tipsData.mapNotNull { it.toTip() }
        } catch (_: Exception) {
            fetchCachedTips()
        }
    }

    suspend fun fetchCachedTips(): List<Tip> {
        val userId = currentUserId ?: return emptyList()
        val doc = db.collection("aiTips").document(userId).get().await()
        val tips = doc.get("tips") as? List<Map<String, Any?>> ?: return emptyList()
        return tips.mapNotNull { it.toTip() }
    }

    suspend fun getWeeklyTrends(): List<DayTrend> {
        val result = functions.getHttpsCallable("getWeeklyTrends").call().await().data as? Map<*, *> ?: emptyMap<Any, Any>()
        val trends = result["trends"] as? List<Map<String, Any?>> ?: emptyList()
        return trends.map {
            DayTrend(
                date = it["date"] as? String ?: "",
                avgPulseRate = (it["avgPulseRate"] as? Number)?.toDouble(),
                avgBreathingRate = (it["avgBreathingRate"] as? Number)?.toDouble(),
                readingCount = (it["readingCount"] as? Number)?.toInt() ?: 0
            )
        }
    }

    suspend fun fetchGroups(): List<StressGroup> {
        val userId = currentUserId ?: return emptyList()
        return db.collection("groups")
            .whereArrayContains("memberIDs", userId)
            .get()
            .await()
            .documents
            .mapNotNull { it.toGroup() }
    }

    suspend fun createGroup(name: String): StressGroup {
        val ownerId = currentUserId ?: error("Not signed in")
        val group = StressGroup(name = name, ownerId = ownerId, memberIds = listOf(ownerId))
        db.collection("groups").document(group.id).set(group.toMap()).await()
        return group
    }

    suspend fun addGroupMember(group: StressGroup, memberId: String) {
        db.collection("groups").document(group.id).update(
            mapOf(
                "memberIDs" to FieldValue.arrayUnion(memberId),
                "updatedAt" to FieldValue.serverTimestamp()
            )
        ).await()
        functions.getHttpsCallable("recomputeGroupDailyStats").call(mapOf("groupID" to group.id)).await()
    }

    suspend fun fetchGroupDailyStats(groupId: String): List<GroupDailyStat> =
        db.collection("groupDailyStats")
            .whereEqualTo("groupID", groupId)
            .orderBy("date", Query.Direction.DESCENDING)
            .limit(14)
            .get()
            .await()
            .documents
            .mapNotNull { it.toGroupDailyStat() }

    suspend fun setShare(viewerId: String, permissions: SharePermissions) {
        val ownerId = currentUserId ?: return
        val docId = "${ownerId}_$viewerId"
        val payload = mapOf(
            "id" to docId,
            "ownerID" to ownerId,
            "viewerID" to viewerId,
            "status" to "active",
            "permissions" to mapOf(
                "latestStress" to permissions.latestStress,
                "history" to permissions.history,
                "groupStats" to permissions.groupStats
            ),
            "createdAt" to Date(),
            "updatedAt" to Date()
        )
        db.collection("shares").document(docId).set(payload).await()
    }

    suspend fun revokeShare(viewerId: String) {
        val ownerId = currentUserId ?: return
        db.collection("shares").document("${ownerId}_$viewerId").update(
            mapOf("status" to "revoked", "updatedAt" to FieldValue.serverTimestamp())
        ).await()
    }

    suspend fun fetchOutgoingShares(): Map<String, ShareRecord> {
        val ownerId = currentUserId ?: return emptyMap()
        return db.collection("shares")
            .whereEqualTo("ownerID", ownerId)
            .whereEqualTo("status", "active")
            .get()
            .await()
            .documents
            .mapNotNull { it.toShareRecord() }
            .associateBy { it.viewerId }
    }

    fun seedBackgroundRefresh() {
        appScope.launch {
            currentUserId?.let {
                runCatching { fetchTips() }
            }
        }
    }

    private fun dayBounds(date: Date): Pair<Date, Date> {
        val calendar = java.util.Calendar.getInstance().apply { time = date }
        calendar.set(java.util.Calendar.HOUR_OF_DAY, 0)
        calendar.set(java.util.Calendar.MINUTE, 0)
        calendar.set(java.util.Calendar.SECOND, 0)
        calendar.set(java.util.Calendar.MILLISECOND, 0)
        val start = calendar.time
        calendar.add(java.util.Calendar.DAY_OF_MONTH, 1)
        return start to calendar.time
    }
}

class AppGraph {
    private val auth = Firebase.auth
    private val db = Firebase.firestore
    private val functions = Firebase.functions
    val repository = CortisolRepository(auth, db, functions, DemoMeasurementProvider())
}

private fun AppUser.toMap(): Map<String, Any?> = mapOf(
    "id" to id,
    "displayName" to displayName,
    "email" to email,
    "photoURL" to photoUrl,
    "friendIDs" to friendIds,
    "createdAt" to createdAt,
    "sharingDefaults" to sharingDefaults?.let {
        mapOf(
            "latestStress" to it.latestStress,
            "history" to it.history,
            "groupStats" to it.groupStats
        )
    },
    "timezone" to timezone
).filterValues { it != null }

private fun DocumentSnapshot.toAppUser(): AppUser = AppUser(
    id = id,
    displayName = getString("displayName").orEmpty(),
    email = getString("email").orEmpty(),
    photoUrl = getString("photoURL"),
    friendIds = get("friendIDs") as? List<String> ?: emptyList(),
    createdAt = getTimestamp("createdAt")?.toDate() ?: Date(),
    sharingDefaults = (get("sharingDefaults") as? Map<*, *>)?.let {
        SharingDefaults(
            latestStress = it["latestStress"] as? Boolean ?: true,
            history = it["history"] as? Boolean ?: false,
            groupStats = it["groupStats"] as? Boolean ?: false
        )
    },
    timezone = getString("timezone")
)

private fun DocumentSnapshot.toReading(): CortisolReading? {
    val userId = getString("userID") ?: return null
    val pulse = getDouble("pulseRate") ?: getDouble("heartRate") ?: return null
    val breathing = getDouble("breathingRate") ?: getDouble("respiratoryRate") ?: return null
    return CortisolReading(
        id = getString("id") ?: id,
        userId = userId,
        timestamp = getTimestamp("timestamp")?.toDate() ?: Date(),
        pulseRate = pulse,
        breathingRate = breathing,
        bloodPressureSystolic = getDouble("bloodPressureSystolic"),
        bloodPressureDiastolic = getDouble("bloodPressureDiastolic"),
        source = getString("source")?.uppercase()?.let { runCatching { ReadingSource.valueOf(it) }.getOrNull() },
        isSpikeCandidate = getBoolean("isSpikeCandidate"),
        storedStressLevel = getDouble("stressLevel"),
        storedHrv = getDouble("hrv"),
        storedSpO2 = getDouble("spO2")
    )
}

private fun DocumentSnapshot.toActivity(): ActivityEntry? {
    val userId = getString("userID") ?: return null
    return ActivityEntry(
        id = getString("id") ?: id,
        userId = userId,
        date = getTimestamp("date")?.toDate() ?: Date(),
        category = ActivityCategory.fromWire(getString("category")),
        title = getString("title").orEmpty(),
        notes = getString("notes"),
        rating = getLong("rating")?.toInt()
    )
}

private fun DocumentSnapshot.toFriend(): Friend? {
    val displayName = getString("displayName") ?: return null
    return Friend(
        id = id,
        displayName = displayName,
        photoUrl = getString("photoURL")
    )
}

private fun DocumentSnapshot.toSpikeEvent(): SpikeEvent? {
    val userId = getString("userID") ?: return null
    return SpikeEvent(
        id = getString("id") ?: id,
        userId = userId,
        readingId = getString("readingID").orEmpty(),
        timestamp = getTimestamp("timestamp")?.toDate() ?: Date(),
        stressLevel = getDouble("stressLevel") ?: 0.0,
        baselineMean = getDouble("baselineMean") ?: 0.0,
        baselineStdDev = getDouble("baselineStdDev") ?: 0.0,
        delta = getDouble("delta") ?: 0.0,
        severity = getString("severity").orEmpty(),
        triggerReason = getString("triggerReason").orEmpty()
    )
}

private fun DocumentSnapshot.toStreak(): Streak = Streak(
    userId = getString("userID").orEmpty(),
    currentReadingStreak = getLong("currentReadingStreak")?.toInt() ?: 0,
    bestReadingStreak = getLong("bestReadingStreak")?.toInt() ?: 0,
    lastReadingDate = getString("lastReadingDate").orEmpty(),
    currentActivityStreak = getLong("currentActivityStreak")?.toInt() ?: 0,
    bestActivityStreak = getLong("bestActivityStreak")?.toInt() ?: 0,
    lastActivityDate = getString("lastActivityDate").orEmpty(),
    updatedAt = getTimestamp("updatedAt")?.toDate()
)

private fun Map<String, Any?>.toTip(): Tip? {
    val title = this["title"] as? String ?: return null
    val category = TipCategory.fromWire(this["category"] as? String)
    return Tip(
        id = this["id"] as? String ?: UUID.randomUUID().toString(),
        title = title,
        body = this["body"] as? String ?: "",
        category = category,
        createdAt = this["createdAt"] as? String ?: "",
        suggestedTime = this["suggestedTime"] as? String
    )
}

private fun DocumentSnapshot.toGroup(): StressGroup? {
    val ownerId = getString("ownerID") ?: return null
    return StressGroup(
        id = getString("id") ?: id,
        name = getString("name").orEmpty(),
        ownerId = ownerId,
        memberIds = get("memberIDs") as? List<String> ?: emptyList(),
        createdAt = getTimestamp("createdAt")?.toDate() ?: Date(),
        updatedAt = getTimestamp("updatedAt")?.toDate() ?: Date(),
        visibility = getString("visibility") ?: "private"
    )
}

private fun DocumentSnapshot.toGroupDailyStat(): GroupDailyStat? {
    val groupId = getString("groupID") ?: return null
    return GroupDailyStat(
        id = getString("id") ?: id,
        groupId = groupId,
        date = getString("date").orEmpty(),
        memberCount = getLong("memberCount")?.toInt() ?: 0,
        activeMemberCount = getLong("activeMemberCount")?.toInt() ?: 0,
        avgStress = getDouble("avgStress"),
        minStress = getDouble("minStress"),
        maxStress = getDouble("maxStress")
    )
}

private fun DocumentSnapshot.toShareRecord(): ShareRecord? {
    val ownerId = getString("ownerID") ?: return null
    val viewerId = getString("viewerID") ?: return null
    val permissionsMap = get("permissions") as? Map<*, *> ?: emptyMap<String, Any>()
    return ShareRecord(
        id = getString("id") ?: id,
        ownerId = ownerId,
        viewerId = viewerId,
        status = getString("status").orEmpty(),
        permissions = SharePermissions(
            latestStress = permissionsMap["latestStress"] as? Boolean ?: true,
            history = permissionsMap["history"] as? Boolean ?: false,
            groupStats = permissionsMap["groupStats"] as? Boolean ?: false
        ),
        createdAt = getTimestamp("createdAt")?.toDate(),
        updatedAt = getTimestamp("updatedAt")?.toDate()
    )
}
