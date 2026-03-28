import Foundation

@MainActor
class CalendarViewModel: ObservableObject {
    @Published var selectedDate = Date()
    @Published var readings: [CortisolReading] = []
    @Published var activities: [Activity] = []
    @Published var isLoading = false
    @Published var error: String?

    private let firebase = FirebaseService.shared

    func loadData(for date: Date) async {
        guard let userID = firebase.currentUserID else { return }
        isLoading = true
        error = nil
        selectedDate = date

        do {
            async let fetchedReadings = firebase.fetchReadings(userID: userID, for: date)
            async let fetchedActivities = firebase.fetchActivities(userID: userID, for: date)
            readings = try await fetchedReadings
            activities = try await fetchedActivities
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func addActivity(category: ActivityCategory, title: String, notes: String?, rating: Int?) async {
        guard let userID = firebase.currentUserID else { return }

        let activity = Activity(
            userID: userID,
            date: selectedDate,
            category: category,
            title: title,
            notes: notes,
            rating: rating
        )

        do {
            try await firebase.saveActivity(activity)
            activities.insert(activity, at: 0)
        } catch {
            self.error = error.localizedDescription
        }
    }

    var averageStress: Double? {
        guard !readings.isEmpty else { return nil }
        return readings.map(\.stressLevel).reduce(0, +) / Double(readings.count)
    }
}
