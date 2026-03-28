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
            // Try callable first, fall back to cached, then static
            tips = try await firebase.generateTips()
        } catch {
            // Callable failed — try cached tips from Firestore
            do {
                tips = try await firebase.fetchCachedTips()
            } catch {
                // Last resort — use local static tips
                let readings = (try? await firebase.fetchReadings(userID: userID, limit: 20)) ?? []
                tips = try await tipsService.fetchTips(userID: userID, recentReadings: readings, recentActivities: [])
            }
        }

        isLoading = false
    }
}
