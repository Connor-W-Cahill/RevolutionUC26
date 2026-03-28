import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions

class FirebaseService {
    static let shared = FirebaseService()
    private let db = Firestore.firestore()
    private let functions = Functions.functions()

    private init() {}

    // MARK: - Auth

    var currentUserID: String? {
        Auth.auth().currentUser?.uid
    }

    func signIn(email: String, password: String) async throws -> AppUser {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        return try await fetchUser(id: result.user.uid)
    }

    func signUp(email: String, password: String, displayName: String) async throws -> AppUser {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let user = AppUser(id: result.user.uid, displayName: displayName, email: email)
        try await saveUser(user)
        return user
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    // MARK: - Users

    func fetchUser(id: String) async throws -> AppUser {
        let doc = try await db.collection("users").document(id).getDocument()
        return try doc.data(as: AppUser.self)
    }

    func saveUser(_ user: AppUser) async throws {
        try db.collection("users").document(user.id).setData(from: user)
    }

    // MARK: - Cortisol Readings

    func saveReading(_ reading: CortisolReading) async throws {
        try db.collection("readings").document(reading.id).setData(from: reading)
    }

    func fetchReadings(userID: String, limit: Int = 50) async throws -> [CortisolReading] {
        let snapshot = try await db.collection("readings")
            .whereField("userID", isEqualTo: userID)
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments()
        return try snapshot.documents.map { try $0.data(as: CortisolReading.self) }
    }

    func fetchReadings(userID: String, for date: Date) async throws -> [CortisolReading] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!

        let snapshot = try await db.collection("readings")
            .whereField("userID", isEqualTo: userID)
            .whereField("timestamp", isGreaterThanOrEqualTo: start)
            .whereField("timestamp", isLessThan: end)
            .order(by: "timestamp", descending: true)
            .getDocuments()
        return try snapshot.documents.map { try $0.data(as: CortisolReading.self) }
    }

    /// Fetch daily average stress levels for a full calendar month.
    /// Returns a dictionary keyed by "YYYY-MM-DD".
    func fetchMonthlyReadingAverages(userID: String, year: Int, month: Int) async throws -> [String: Double] {
        var cal = Calendar.current
        cal.timeZone = TimeZone.current
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let startDate = cal.date(from: components),
              let endDate = cal.date(byAdding: .month, value: 1, to: startDate) else {
            return [:]
        }

        let snapshot = try await db.collection("readings")
            .whereField("userID", isEqualTo: userID)
            .whereField("timestamp", isGreaterThanOrEqualTo: startDate)
            .whereField("timestamp", isLessThan: endDate)
            .getDocuments()

        let readings = try snapshot.documents.map { try $0.data(as: CortisolReading.self) }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current

        var grouped: [String: [Double]] = [:]
        for reading in readings {
            let key = formatter.string(from: reading.timestamp)
            grouped[key, default: []].append(reading.stressLevel)
        }

        return grouped.mapValues { levels in
            levels.reduce(0, +) / Double(levels.count)
        }
    }

    // MARK: - Activities

    func saveActivity(_ activity: Activity) async throws {
        try db.collection("activities").document(activity.id).setData(from: activity)
    }

    func fetchActivities(userID: String, for date: Date) async throws -> [Activity] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!

        let snapshot = try await db.collection("activities")
            .whereField("userID", isEqualTo: userID)
            .whereField("date", isGreaterThanOrEqualTo: start)
            .whereField("date", isLessThan: end)
            .order(by: "date", descending: true)
            .getDocuments()
        return try snapshot.documents.map { try $0.data(as: Activity.self) }
    }

    // MARK: - Spike Events

    func fetchSpikeEvents(userID: String, limit: Int = 10) async throws -> [SpikeEvent] {
        let snapshot = try await db.collection("spikeEvents")
            .whereField("userID", isEqualTo: userID)
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments()
        return try snapshot.documents.map { try $0.data(as: SpikeEvent.self) }
    }

    // MARK: - Streaks

    func fetchStreak(userID: String) async throws -> Streak? {
        let doc = try await db.collection("streaks").document(userID).getDocument()
        guard doc.exists else { return nil }
        return try doc.data(as: Streak.self)
    }

    // MARK: - Friends

    func fetchFriends(friendIDs: [String]) async throws -> [Friend] {
        guard !friendIDs.isEmpty else { return [] }
        let chunks = stride(from: 0, to: friendIDs.count, by: 30).map {
            Array(friendIDs[$0..<min($0 + 30, friendIDs.count)])
        }
        var friends: [Friend] = []
        for chunk in chunks {
            let snapshot = try await db.collection("users")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()
            let users = try snapshot.documents.map { try $0.data(as: Friend.self) }
            friends.append(contentsOf: users)
        }
        return friends
    }

    func addFriend(userID: String, friendID: String) async throws {
        let friendshipData: [String: Any] = [
            "userA": userID,
            "userB": friendID,
            "status": "pending",
            "initiatedBy": userID,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        try await db.collection("friendships").addDocument(data: friendshipData)

        try await db.collection("users").document(userID).updateData([
            "friendIDs": FieldValue.arrayUnion([friendID])
        ])
    }

    func searchUsers(query: String) async throws -> [Friend] {
        let snapshot = try await db.collection("users")
            .whereField("displayName", isGreaterThanOrEqualTo: query)
            .whereField("displayName", isLessThanOrEqualTo: query + "\u{f8ff}")
            .limit(to: 20)
            .getDocuments()
        return try snapshot.documents.map { try $0.data(as: Friend.self) }
    }

    func fetchFriendReadings(friendID: String, limit: Int = 1) async throws -> [CortisolReading] {
        let snapshot = try await db.collection("readings")
            .whereField("userID", isEqualTo: friendID)
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments()
        return try snapshot.documents.map { try $0.data(as: CortisolReading.self) }
    }

    // MARK: - Shares

    func setShare(viewerID: String, permissions: Share.SharePermissions) async throws {
        guard let ownerID = currentUserID else { return }
        let shareID = "\(ownerID)_\(viewerID)"
        let share = Share(ownerID: ownerID, viewerID: viewerID, permissions: permissions)
        try db.collection("shares").document(shareID).setData(from: share)
    }

    func revokeShare(viewerID: String) async throws {
        guard let ownerID = currentUserID else { return }
        let shareID = "\(ownerID)_\(viewerID)"
        try await db.collection("shares").document(shareID).updateData([
            "status": "revoked",
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    func fetchShare(ownerID: String, viewerID: String) async throws -> Share? {
        let shareID = "\(ownerID)_\(viewerID)"
        let doc = try await db.collection("shares").document(shareID).getDocument()
        guard doc.exists else { return nil }
        return try doc.data(as: Share.self)
    }

    /// Fetch all shares the current user has set up (outgoing).
    func fetchMyShares() async throws -> [Share] {
        guard let userID = currentUserID else { return [] }
        let snapshot = try await db.collection("shares")
            .whereField("ownerID", isEqualTo: userID)
            .whereField("status", isEqualTo: "active")
            .getDocuments()
        return try snapshot.documents.map { try $0.data(as: Share.self) }
    }

    // MARK: - Groups

    func createGroup(name: String) async throws -> StressGroup {
        guard let ownerID = currentUserID else {
            throw NSError(domain: "FirebaseService", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Not signed in"])
        }
        var group = StressGroup(name: name, ownerID: ownerID, memberIDs: [ownerID])
        let docRef = db.collection("groups").document(group.id)
        try docRef.setData(from: group)
        group.id = docRef.documentID
        return group
    }

    func fetchGroups(userID: String) async throws -> [StressGroup] {
        let snapshot = try await db.collection("groups")
            .whereField("memberIDs", arrayContains: userID)
            .getDocuments()
        return try snapshot.documents.map { try $0.data(as: StressGroup.self) }
    }

    func addGroupMember(groupID: String, memberID: String) async throws {
        try await db.collection("groups").document(groupID).updateData([
            "memberIDs": FieldValue.arrayUnion([memberID]),
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    func removeGroupMember(groupID: String, memberID: String) async throws {
        try await db.collection("groups").document(groupID).updateData([
            "memberIDs": FieldValue.arrayRemove([memberID]),
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    func fetchGroupDailyStats(groupID: String, limit: Int = 14) async throws -> [GroupDailyStat] {
        let snapshot = try await db.collection("groupDailyStats")
            .whereField("groupID", isEqualTo: groupID)
            .order(by: "date", descending: true)
            .limit(to: limit)
            .getDocuments()
        return try snapshot.documents.map { try $0.data(as: GroupDailyStat.self) }
    }

    func recomputeGroupDailyStats(groupID: String) async throws {
        _ = try await functions.httpsCallable("recomputeGroupDailyStats").call(["groupID": groupID])
    }

    // MARK: - AI Tips

    func generateTips() async throws -> [Tip] {
        let result = try await functions.httpsCallable("generateTips").call()
        guard let data = result.data as? [String: Any],
              let tipsData = data["tips"] as? [[String: Any]] else {
            return try await fetchCachedTips()
        }
        let jsonData = try JSONSerialization.data(withJSONObject: tipsData)
        return try JSONDecoder().decode([Tip].self, from: jsonData)
    }

    func fetchCachedTips() async throws -> [Tip] {
        guard let userID = currentUserID else { return [] }
        let doc = try await db.collection("aiTips").document(userID).getDocument()
        guard let data = doc.data(), let tipsArray = data["tips"] as? [[String: Any]] else { return [] }
        let jsonData = try JSONSerialization.data(withJSONObject: tipsArray)
        return try JSONDecoder().decode([Tip].self, from: jsonData)
    }
}
