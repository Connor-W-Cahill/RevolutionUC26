import SwiftUI
import FirebaseCore

@main
struct CortisolTrackerApp: App {
    @StateObject private var authViewModel = AuthViewModel()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            if authViewModel.isAuthenticated {
                ContentView()
                    .environmentObject(authViewModel)
            } else {
                LoginView(authViewModel: authViewModel)
            }
        }
    }
}
