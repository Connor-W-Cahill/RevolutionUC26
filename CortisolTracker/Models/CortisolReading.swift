import Foundation

enum ReadingSource: String, Codable {
    case presage = "presage"
    case manual = "manual"
    case imported = "imported"
}

struct CortisolReading: Identifiable, Codable {
    var id: String
    var userID: String
    var timestamp: Date
    var pulseRate: Double
    var breathingRate: Double
    var bloodPressureSystolic: Double?
    var bloodPressureDiastolic: Double?
    var source: ReadingSource?
    var isSpikeCandidate: Bool?

    private var storedStressLevel: Double?
    private var storedHRV: Double?
    private var storedSpO2: Double?

    var stressLevel: Double {
        if let storedStressLevel {
            return storedStressLevel
        }
        let pulseStress = max(0, min(100, (pulseRate - 60) / 40 * 50))
        let breathingStress = max(0, min(100, (breathingRate - 12) / 8 * 50))
        return min(100, pulseStress + breathingStress)
    }

    var heartRate: Double { pulseRate }
    var hrv: Double { storedHRV ?? max(20, 120 - pulseRate) }
    var spO2: Double { storedSpO2 ?? 98 }
    var respiratoryRate: Double { breathingRate }

    var stressCategory: StressCategory {
        switch stressLevel {
        case 0..<25: return .low
        case 25..<50: return .moderate
        case 50..<75: return .high
        default: return .veryHigh
        }
    }

    init(
        id: String = UUID().uuidString,
        userID: String,
        timestamp: Date = Date(),
        pulseRate: Double,
        breathingRate: Double,
        bloodPressureSystolic: Double? = nil,
        bloodPressureDiastolic: Double? = nil,
        source: ReadingSource? = nil,
        isSpikeCandidate: Bool? = nil,
        stressLevel: Double? = nil,
        hrv: Double? = nil,
        spO2: Double? = nil
    ) {
        self.id = id
        self.userID = userID
        self.timestamp = timestamp
        self.pulseRate = pulseRate
        self.breathingRate = breathingRate
        self.bloodPressureSystolic = bloodPressureSystolic
        self.bloodPressureDiastolic = bloodPressureDiastolic
        self.source = source
        self.isSpikeCandidate = isSpikeCandidate
        self.storedStressLevel = stressLevel
        self.storedHRV = hrv
        self.storedSpO2 = spO2
    }

    init(
        id: String = UUID().uuidString,
        userID: String,
        timestamp: Date = Date(),
        stressLevel: Double,
        heartRate: Double,
        hrv: Double,
        spO2: Double,
        respiratoryRate: Double,
        source: ReadingSource? = nil,
        isSpikeCandidate: Bool? = nil
    ) {
        self.init(
            id: id,
            userID: userID,
            timestamp: timestamp,
            pulseRate: heartRate,
            breathingRate: respiratoryRate,
            source: source,
            isSpikeCandidate: isSpikeCandidate,
            stressLevel: stressLevel,
            hrv: hrv,
            spO2: spO2
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userID
        case timestamp
        case pulseRate
        case breathingRate
        case bloodPressureSystolic
        case bloodPressureDiastolic
        case stressLevel
        case heartRate
        case hrv
        case spO2
        case respiratoryRate
        case source
        case isSpikeCandidate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userID = try container.decode(String.self, forKey: .userID)
        timestamp = try container.decode(Date.self, forKey: .timestamp)

        let legacyHeartRate = try container.decodeIfPresent(Double.self, forKey: .heartRate)
        let legacyRespiratoryRate = try container.decodeIfPresent(Double.self, forKey: .respiratoryRate)

        pulseRate = try container.decodeIfPresent(Double.self, forKey: .pulseRate) ?? legacyHeartRate ?? 0
        breathingRate = try container.decodeIfPresent(Double.self, forKey: .breathingRate) ?? legacyRespiratoryRate ?? 0
        bloodPressureSystolic = try container.decodeIfPresent(Double.self, forKey: .bloodPressureSystolic)
        bloodPressureDiastolic = try container.decodeIfPresent(Double.self, forKey: .bloodPressureDiastolic)
        source = try container.decodeIfPresent(ReadingSource.self, forKey: .source)
        isSpikeCandidate = try container.decodeIfPresent(Bool.self, forKey: .isSpikeCandidate)
        storedStressLevel = try container.decodeIfPresent(Double.self, forKey: .stressLevel)
        storedHRV = try container.decodeIfPresent(Double.self, forKey: .hrv)
        storedSpO2 = try container.decodeIfPresent(Double.self, forKey: .spO2)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userID, forKey: .userID)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(pulseRate, forKey: .pulseRate)
        try container.encode(breathingRate, forKey: .breathingRate)
        try container.encodeIfPresent(bloodPressureSystolic, forKey: .bloodPressureSystolic)
        try container.encodeIfPresent(bloodPressureDiastolic, forKey: .bloodPressureDiastolic)
        try container.encode(stressLevel, forKey: .stressLevel)
        try container.encode(heartRate, forKey: .heartRate)
        try container.encode(hrv, forKey: .hrv)
        try container.encode(spO2, forKey: .spO2)
        try container.encode(respiratoryRate, forKey: .respiratoryRate)
        try container.encodeIfPresent(source, forKey: .source)
        try container.encodeIfPresent(isSpikeCandidate, forKey: .isSpikeCandidate)
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
