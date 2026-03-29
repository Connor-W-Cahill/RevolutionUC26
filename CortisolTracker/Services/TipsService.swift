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

    /// Fetch AI-generated tips via Gemini API, falling back to static tips if unavailable.
    func fetchTips(userID: String, recentReadings: [CortisolReading], recentActivities: [Activity]) async throws -> [Tip] {
        let apiKey = Config.geminiAPIKey
        guard !apiKey.isEmpty else {
            return defaultTips(for: recentReadings)
        }

        do {
            return try await fetchGeminiTips(readings: recentReadings, activities: recentActivities, apiKey: apiKey)
        } catch {
            print("Gemini tips failed: \(error.localizedDescription). Using static fallback.")
            return defaultTips(for: recentReadings)
        }
    }

    // MARK: - Gemini API

    private func fetchGeminiTips(readings: [CortisolReading], activities: [Activity], apiKey: String) async throws -> [Tip] {
        let avgStress = readings.isEmpty ? 50.0 : readings.map(\.stressLevel).reduce(0, +) / Double(readings.count)
        let stressLabel = avgStress > 60 ? "high" : avgStress > 40 ? "moderate" : "low"
        let activitySummary = activities.prefix(5).map { "\($0.category.rawValue): \($0.title)" }.joined(separator: ", ")

        let prompt = """
        You are a wellness coach specializing in cortisol and stress management. Based on this user's data, generate exactly 5 short, personalized wellness tips.

        User's recent data:
        - Average stress/cortisol level: \(Int(avgStress))/100 (\(stressLabel))
        - Recent activities: \(activitySummary.isEmpty ? "none logged" : activitySummary)

        Return ONLY a valid JSON array with exactly 5 objects. No extra text, no markdown, no code fences:
        [
          {
            "title": "Short actionable title (max 8 words)",
            "body": "2-3 sentences with specific, practical advice tailored to their stress level.",
            "category": "one of: breathing, exercise, sleep, nutrition, mindfulness, social, general"
          }
        ]
        """

        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw TipsError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ],
            "generationConfig": [
                "temperature": 0.7,
                "maxOutputTokens": 1024
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw TipsError.apiError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            throw TipsError.invalidResponse
        }

        return try parseTipsJSON(from: text)
    }

    private func parseTipsJSON(from text: String) throws -> [Tip] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Extract JSON array from between first [ and last ]
        guard let startRange = trimmed.range(of: "["),
              let endRange = trimmed.range(of: "]", options: .backwards) else {
            throw TipsError.parseError
        }
        let jsonText = String(trimmed[startRange.lowerBound...endRange.upperBound])

        guard let jsonData = jsonText.data(using: .utf8),
              let rawArray = try JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
            throw TipsError.parseError
        }

        return rawArray.compactMap { obj in
            guard let title = obj["title"] as? String,
                  let body = obj["body"] as? String,
                  let categoryStr = obj["category"] as? String,
                  let category = TipCategory(rawValue: categoryStr) else { return nil }
            return Tip(title: title, body: body, category: category)
        }
    }

    // MARK: - Static Fallback

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

// MARK: - Errors

private enum TipsError: Error {
    case invalidURL
    case apiError(Int)
    case invalidResponse
    case parseError
}
