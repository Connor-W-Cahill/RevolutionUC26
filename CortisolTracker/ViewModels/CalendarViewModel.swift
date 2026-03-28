import Foundation

@MainActor
class CalendarViewModel: ObservableObject {
    @Published var selectedDate = Date()
    @Published var readings: [CortisolReading] = []
    @Published var activities: [Activity] = []
    @Published var monthlyAverages: [String: Double] = [:]  // "YYYY-MM-DD" -> avgStress
    @Published var isLoading = false
    @Published var error: String?

    private let firebase = FirebaseService.shared
    private var loadedMonthKey: String = ""  // tracks which month's averages are loaded

    private var calendar: Calendar { Calendar.current }

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

        // Lazy-load monthly averages when the month changes
        let monthKey = monthKey(for: date)
        if monthKey != loadedMonthKey {
            await loadMonthlyAverages(for: date)
        }
    }

    func loadMonthlyAverages(for date: Date) async {
        guard let userID = firebase.currentUserID else { return }
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)

        do {
            monthlyAverages = try await firebase.fetchMonthlyReadingAverages(
                userID: userID, year: year, month: month
            )
            loadedMonthKey = monthKey(for: date)
        } catch {
            // Non-fatal: heatmap just shows no data
            print("Monthly averages load failed: \(error)")
        }
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

    private func monthKey(for date: Date) -> String {
        let y = calendar.component(.year, from: date)
        let m = calendar.component(.month, from: date)
        return "\(y)-\(m)"
    }
}
