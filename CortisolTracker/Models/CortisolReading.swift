import Foundation

struct CortisolReading: Identifiable, Codable {
    var id: String
    var userID: String
    var timestamp: Date
    var stressLevel: Double       // 0-100 scale from Presage SDK
    var heartRate: Double          // bpm
    var hrv: Double                // ms (heart rate variability)
    var spO2: Double               // percentage
    var respiratoryRate: Double    // breaths per minute

    var stressCategory: StressCategory {
        switch stressLevel {
        case 0..<25: return .low
        case 25..<50: return .moderate
        case 50..<75: return .high
        default: return .veryHigh
        }
    }

    init(id: String = UUID().uuidString, userID: String, timestamp: Date = Date(),
         stressLevel: Double, heartRate: Double, hrv: Double, spO2: Double, respiratoryRate: Double) {
        self.id = id
        self.userID = userID
        self.timestamp = timestamp
        self.stressLevel = stressLevel
        self.heartRate = heartRate
        self.hrv = hrv
        self.spO2 = spO2
        self.respiratoryRate = respiratoryRate
    }
}

enum StressCategory: String, Codable, CaseIterable {
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"
    case veryHigh = "Very High"

    var color: String {
        switch self {
        case .low: return "green"
        case .moderate: return "yellow"
        case .high: return "orange"
        case .veryHigh: return "red"
        }
    }

    var emoji: String {
        switch self {
        case .low: return "😌"
        case .moderate: return "😐"
        case .high: return "😰"
        case .veryHigh: return "🤯"
        }
    }
}
