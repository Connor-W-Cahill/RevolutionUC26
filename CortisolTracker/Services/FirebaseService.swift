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

    // MARK: - Friends

    func fetchFriends(friendIDs: [String]) async throws -> [Friend] {
        guard !friendIDs.isEmpty else { return [] }
        // Firestore `in` queries limited to 30 items
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
        // Create friendship doc (pending state)
        let friendshipData: [String: Any] = [
            "userA": userID,
            "userB": friendID,
            "status": "pending",
            "initiatedBy": userID,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        try await db.collection("friendships").addDocument(data: friendshipData)

        // Also update denormalized friendIDs cache on user doc
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

    // MARK: - AI Tips (callable function + Firestore cache)

    func generateTips() async throws -> [Tip] {
        let result = try await functions.httpsCallable("generateTips").call()
        guard let data = result.data as? [String: Any],
              let tipsData = data["tips"] as? [[String: Any]] else {
            // Fall back to cached tips
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

    func fetchFriendReadings(friendID: String, limit: Int = 1) async throws -> [CortisolReading] {
        let snapshot = try await db.collection("readings")
            .whereField("userID", isEqualTo: friendID)
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments()
        return try snapshot.documents.map { try $0.data(as: CortisolReading.self) }
    }
}
