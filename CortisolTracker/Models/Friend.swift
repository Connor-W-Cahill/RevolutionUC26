import Foundation

struct Friend: Identifiable, Codable {
    var id: String
    var displayName: String
    var photoURL: String?
    var latestStressLevel: Double?
    var latestReadingTime: Date?

    var stressCategory: StressCategory? {
        guard let level = latestStressLevel else { return nil }
        switch level {
        case 0..<25: return .low
        case 25..<50: return .moderate
        case 50..<75: return .high
        default: return .veryHigh
        }
    }
}
