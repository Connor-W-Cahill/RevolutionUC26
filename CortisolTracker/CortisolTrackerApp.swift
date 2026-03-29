import SwiftUI
import FirebaseCore

@main
struct CortisolTrackerApp: App {
    @State private var authViewModel: AuthViewModel

    init() {
        FirebaseApp.configure()
        _authViewModel = State(wrappedValue: AuthViewModel())
    }

    var body: some Scene {
        WindowGroup {
            if authViewModel.isAuthenticated {
                ContentView()
                    .environment(authViewModel)
            } else {
                LoginView(authViewModel: authViewModel)
            }
        }
    }
}
