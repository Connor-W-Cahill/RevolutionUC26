import Foundation

struct Streak: Codable {
    var userID: String
    var currentReadingStreak: Int
    var bestReadingStreak: Int
    var lastReadingDate: String    // "YYYY-MM-DD"
    var currentActivityStreak: Int
    var bestActivityStreak: Int
    var lastActivityDate: String   // "YYYY-MM-DD"
    var updatedAt: Date?

    init(
        userID: String,
        currentReadingStreak: Int = 0,
        bestReadingStreak: Int = 0,
        lastReadingDate: String = "",
        currentActivityStreak: Int = 0,
        bestActivityStreak: Int = 0,
        lastActivityDate: String = ""
    ) {
        self.userID = userID
        self.currentReadingStreak = currentReadingStreak
        self.bestReadingStreak = bestReadingStreak
        self.lastReadingDate = lastReadingDate
        self.currentActivityStreak = currentActivityStreak
        self.bestActivityStreak = bestActivityStreak
        self.lastActivityDate = lastActivityDate
    }
}
