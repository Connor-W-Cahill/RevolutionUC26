import Foundation

struct CortisolReading: Identifiable, Codable {
    var id: String
    var userID: String
    var timestamp: Date
    var pulseRate: Double            // bpm from Presage SDK
    var breathingRate: Double        // breaths per minute from Presage SDK
    var bloodPressureSystolic: Double?  // mmHg from phasic BP if available
    var bloodPressureDiastolic: Double? // mmHg if available

    /// Derived stress estimate based on pulse and breathing rate.
    /// Higher pulse + higher breathing = higher stress. Simple heuristic for hackathon.
    var stressLevel: Double {
        // Resting pulse ~60-80, stressed ~90+. Resting breathing ~12-16, stressed ~20+.
        let pulseStress = max(0, min(100, (pulseRate - 60) / 40 * 50))
        let breathingStress = max(0, min(100, (breathingRate - 12) / 8 * 50))
        return min(100, pulseStress + breathingStress)
    }

    var stressCategory: StressCategory {
        switch stressLevel {
        case 0..<25: return .low
        case 25..<50: return .moderate
        case 50..<75: return .high
        default: return .veryHigh
        }
    }

    init(id: String = UUID().uuidString, userID: String, timestamp: Date = Date(),
         pulseRate: Double, breathingRate: Double,
         bloodPressureSystolic: Double? = nil, bloodPressureDiastolic: Double? = nil) {
        self.id = id
        self.userID = userID
        self.timestamp = timestamp
        self.pulseRate = pulseRate
        self.breathingRate = breathingRate
        self.bloodPressureSystolic = bloodPressureSystolic
        self.bloodPressureDiastolic = bloodPressureDiastolic
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
