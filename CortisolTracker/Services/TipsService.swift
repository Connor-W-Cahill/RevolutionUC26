import Foundation

struct Tip: Identifiable, Codable {
    var id: String
    var title: String
    var body: String
    var category: TipCategory
    var createdAt: String
    var suggestedTime: String?   // ISO datetime string for time-anchored tips

    init(id: String = UUID().uuidString, title: String, body: String,
         category: TipCategory, createdAt: String = "", suggestedTime: String? = nil) {
        self.id = id
        self.title = title
        self.body = body
        self.category = category
        self.createdAt = createdAt
        self.suggestedTime = suggestedTime
    }
}

enum TipCategory: String, Codable, CaseIterable {
    case breathing = "breathing"
    case exercise = "exercise"
    case sleep = "sleep"
    case nutrition = "nutrition"
    case mindfulness = "mindfulness"
    case social = "social"
    case general = "general"

    var displayName: String { rawValue.capitalized }

    var icon: String {
        switch self {
        case .breathing: return "wind"
        case .exercise: return "figure.run"
        case .sleep: return "moon.zzz"
        case .nutrition: return "leaf"
        case .mindfulness: return "brain.head.profile"
        case .social: return "person.2"
        case .general: return "lightbulb"
        }
    }
}

class TipsService {
    static let shared = TipsService()

    private init() {}

    /// Fetch AI-generated tips based on recent readings and activities.
    /// Calls Firebase Cloud Function that uses an LLM to generate personalized tips.
    func fetchTips(userID: String, recentReadings: [CortisolReading], recentActivities: [Activity]) async throws -> [Tip] {
        // TODO: Call Firebase Cloud Function endpoint for AI-generated tips
        // let url = URL(string: "https://us-central1-PROJECT.cloudfunctions.net/generateTips")!
        // var request = URLRequest(url: url)
        // request.httpMethod = "POST"
        // request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // let body = ["userID": userID, "readings": recentReadings, "activities": recentActivities]
        // request.httpBody = try JSONEncoder().encode(body)
        // let (data, _) = try await URLSession.shared.data(for: request)
        // return try JSONDecoder().decode([Tip].self, from: data)

        // Fallback static tips for demo
        return defaultTips(for: recentReadings)
    }

    private func defaultTips(for readings: [CortisolReading]) -> [Tip] {
        let avgStress = readings.isEmpty ? 50.0 : readings.map(\.stressLevel).reduce(0, +) / Double(readings.count)

        var tips: [Tip] = []

        if avgStress > 60 {
            tips.append(Tip(
                title: "Try Box Breathing",
                body: "Inhale for 4 seconds, hold for 4, exhale for 4, hold for 4. Repeat 4 times. This activates your parasympathetic nervous system and can lower cortisol quickly.",
                category: .breathing
            ))
            tips.append(Tip(
                title: "Take a 10-Minute Walk",
                body: "A short walk, especially outdoors, can significantly reduce stress hormones. Try to get some sunlight exposure.",
                category: .exercise
            ))
        }

        if avgStress > 40 {
            tips.append(Tip(
                title: "Limit Caffeine After 2 PM",
                body: "Caffeine stimulates cortisol production. Switching to herbal tea in the afternoon can help your body wind down naturally.",
                category: .nutrition
            ))
        }

        tips.append(Tip(
            title: "Prioritize 7-9 Hours of Sleep",
            body: "Sleep deprivation is one of the biggest cortisol elevators. Aim for consistent sleep and wake times.",
            category: .sleep
        ))

        tips.append(Tip(
            title: "5-Minute Mindfulness Check-In",
            body: "Close your eyes, focus on your breath, and do a body scan from head to toe. Notice tension without judging it.",
            category: .mindfulness
        ))

        tips.append(Tip(
            title: "Connect With a Friend",
            body: "Social connection releases oxytocin, which counteracts cortisol. Even a quick text or call can help.",
            category: .social
        ))

        return tips
    }
}
