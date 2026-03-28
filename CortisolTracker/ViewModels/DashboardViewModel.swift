import Foundation

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var latestReading: CortisolReading?
    @Published var todayReadings: [CortisolReading] = []
    @Published var isLoading = false
    @Published var error: String?

    private let firebase = FirebaseService.shared
    let presage = PresageService.shared

    func loadData() async {
        guard let userID = firebase.currentUserID else { return }
        isLoading = true
        error = nil

        do {
            todayReadings = try await firebase.fetchReadings(userID: userID, for: Date())
            latestReading = todayReadings.first
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func startScan() async {
        guard let userID = firebase.currentUserID else {
            error = "Please sign in to take a reading"
            return
        }

        do {
            let reading = try await presage.startScan(userID: userID)
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
