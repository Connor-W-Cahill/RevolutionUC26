import Foundation

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var latestReading: CortisolReading?
    @Published var todayReadings: [CortisolReading] = []
    @Published var latestSpike: SpikeEvent?
    @Published var streak: Streak?
    @Published var isLoading = false
    @Published var error: String?

    private let firebase = FirebaseService.shared

    var currentUserID: String? {
        firebase.currentUserID
    }

    func loadData() async {
        guard let userID = firebase.currentUserID else { return }
        isLoading = true
        error = nil

        do {
            async let fetchedReadings = firebase.fetchReadings(userID: userID, for: Date())
            async let fetchedSpikes = firebase.fetchSpikeEvents(userID: userID, limit: 1)
            async let fetchedStreak = firebase.fetchStreak(userID: userID)

            todayReadings = try await fetchedReadings
            latestReading = todayReadings.first

            let spikes = try await fetchedSpikes
            // Only surface spikes from the last 2 hours
            latestSpike = spikes.first.flatMap { spike in
                spike.timestamp > Date().addingTimeInterval(-7200) ? spike : nil
            }

            streak = try await fetchedStreak
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func saveReading(_ reading: CortisolReading) async {
        do {
            try await firebase.saveReading(reading)
            latestReading = reading
            todayReadings.insert(reading, at: 0)
        } catch {
            self.error = error.localizedDescription
        }
    }

    var averageStressToday: Double? {
        guard !todayReadings.isEmpty else { return nil }
        return todayReadings.map(\.stressLevel).reduce(0, +) / Double(todayReadings.count)
    }
}
