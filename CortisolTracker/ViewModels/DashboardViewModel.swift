import Foundation

@Observable
class DashboardViewModel {
    var latestReading: CortisolReading?
    var todayReadings: [CortisolReading] = []
    var weeklyTrend: [(date: Date, avgStress: Double)] = []
    var latestSpike: SpikeEvent?
    var streak: Streak?
    var isLoading = false
    var error: String?

    private let firebase = FirebaseService.shared

    var currentUserID: String? {
        firebase.currentUserID
    }

    func loadData() async {
        guard let userID = firebase.currentUserID else { return }
        isLoading = true
        error = nil

        do {
            async let fetchedToday = firebase.fetchReadings(userID: userID, for: Date())
            async let fetchedRecent = firebase.fetchReadings(userID: userID, limit: 100)
            async let fetchedSpikes = firebase.fetchSpikeEvents(userID: userID, limit: 1)
            async let fetchedStreak = firebase.fetchStreak(userID: userID)

            todayReadings = try await fetchedToday
            latestReading = todayReadings.first

            let recentReadings = try await fetchedRecent
            weeklyTrend = computeWeeklyTrend(from: recentReadings)

            let spikes = try await fetchedSpikes
            latestSpike = spikes.first.flatMap { spike in
                spike.timestamp > Date().addingTimeInterval(-7200) ? spike : nil
            }

            streak = try await fetchedStreak
        } catch {
            let nsError = error as NSError
            // Silently ignore offline errors — Firestore cache handles it
            if !(nsError.domain == "FIRFirestoreErrorDomain" && nsError.code == 14) {
                self.error = error.localizedDescription
            }
        }

        isLoading = false
    }

    func saveReading(_ reading: CortisolReading) async {
        do {
            try await firebase.saveReading(reading)
            latestReading = reading
            todayReadings.insert(reading, at: 0)
            // Refresh trend with new data
            if let userID = firebase.currentUserID,
               let recent = try? await firebase.fetchReadings(userID: userID, limit: 100) {
                weeklyTrend = computeWeeklyTrend(from: recent)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    var averageStressToday: Double? {
        guard !todayReadings.isEmpty else { return nil }
        return todayReadings.map(\.stressLevel).reduce(0, +) / Double(todayReadings.count)
    }

    private func computeWeeklyTrend(from readings: [CortisolReading]) -> [(date: Date, avgStress: Double)] {
        let calendar = Calendar.current
        var grouped: [Date: [Double]] = [:]
        for reading in readings {
            let day = calendar.startOfDay(for: reading.timestamp)
            grouped[day, default: []].append(reading.stressLevel)
        }
        return grouped
            .map { (date: $0.key, avgStress: $0.value.reduce(0, +) / Double($0.value.count)) }
            .sorted { $0.date < $1.date }
            .suffix(7)
            .map { $0 }
    }
}
