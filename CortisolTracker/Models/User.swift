import Foundation

struct SharingDefaults: Codable {
    var latestStress: Bool
    var history: Bool
    var groupStats: Bool

    init(latestStress: Bool = true, history: Bool = false, groupStats: Bool = false) {
        self.latestStress = latestStress
        self.history = history
        self.groupStats = groupStats
    }
}

struct AppUser: Identifiable, Codable {
    var id: String
    var displayName: String
    var email: String
    var photoURL: String?
    var friendIDs: [String]
    var createdAt: Date
    var sharingDefaults: SharingDefaults?
    var timezone: String?

    init(
        id: String,
        displayName: String,
        email: String,
        photoURL: String? = nil,
        friendIDs: [String] = [],
        createdAt: Date = Date(),
        sharingDefaults: SharingDefaults? = nil,
        timezone: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.photoURL = photoURL
        self.friendIDs = friendIDs
        self.createdAt = createdAt
        self.sharingDefaults = sharingDefaults
        self.timezone = timezone ?? TimeZone.current.identifier
    }
}
