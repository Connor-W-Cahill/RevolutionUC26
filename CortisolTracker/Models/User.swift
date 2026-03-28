import Foundation

struct AppUser: Identifiable, Codable {
    var id: String
    var displayName: String
    var email: String
    var photoURL: String?
    var friendIDs: [String]
    var createdAt: Date

    init(id: String, displayName: String, email: String, photoURL: String? = nil, friendIDs: [String] = [], createdAt: Date = Date()) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.photoURL = photoURL
        self.friendIDs = friendIDs
        self.createdAt = createdAt
    }
}
