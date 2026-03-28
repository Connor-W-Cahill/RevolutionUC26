import Foundation

// Named StressGroup to avoid collision with SwiftUI's Group view
struct StressGroup: Identifiable, Codable {
    var id: String
    var name: String
    var ownerID: String
    var memberIDs: [String]
    var createdAt: Date
    var updatedAt: Date
    var visibility: String

    init(
        id: String = UUID().uuidString,
        name: String,
        ownerID: String,
        memberIDs: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        visibility: String = "private"
    ) {
        self.id = id
        self.name = name
        self.ownerID = ownerID
        self.memberIDs = memberIDs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.visibility = visibility
    }
}

struct GroupDailyStat: Identifiable, Codable {
    var id: String           // groupID_YYYY-MM-DD
    var groupID: String
    var date: String         // "YYYY-MM-DD"
    var memberCount: Int
    var activeMemberCount: Int
    var avgStress: Double?
    var minStress: Double?
    var maxStress: Double?

    var stressCategory: StressCategory? {
        guard let avg = avgStress else { return nil }
        switch avg {
        case 0..<25: return .low
        case 25..<50: return .moderate
        case 50..<75: return .high
        default: return .veryHigh
        }
    }
}
