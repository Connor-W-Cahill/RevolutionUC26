import Foundation

@MainActor
class TipsViewModel: ObservableObject {
    @Published var tips: [Tip] = []
    @Published var isLoading = false
    @Published var error: String?

    private let firebase = FirebaseService.shared
    private let tipsService = TipsService.shared

    func loadTips() async {
        guard let userID = firebase.currentUserID else { return }
        isLoading = true
        error = nil

        do {
            let readings = (try? await firebase.fetchReadings(userID: userID, limit: 20)) ?? []
            let activities = (try? await firebase.fetchActivities(userID: userID, for: Date())) ?? []
            tips = try await tipsService.fetchTips(userID: userID, recentReadings: readings, recentActivities: activities)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}
