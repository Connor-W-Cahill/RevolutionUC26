import Foundation

struct SpikeEvent: Identifiable, Codable {
    var id: String
    var userID: String
    var readingID: String
    var timestamp: Date
    var stressLevel: Double
    var baselineMean: Double
    var baselineStdDev: Double
    var delta: Double
    var severity: SpikeSeverity
    var triggerReason: String

    enum SpikeSeverity: String, Codable {
        case mild = "mild"
        case moderate = "moderate"
        case high = "high"

        var displayName: String { rawValue.capitalized }

        var emoji: String {
            switch self {
            case .mild: return "⚡"
            case .moderate: return "⚠️"
            case .high: return "🚨"
            }
        }

        var color: String {
            switch self {
            case .mild: return "yellow"
            case .moderate: return "orange"
            case .high: return "red"
            }
        }

        var recommendations: [String] {
            ["breathing_90s", "short_walk_10m", "hydration"]
        }
    }
}
