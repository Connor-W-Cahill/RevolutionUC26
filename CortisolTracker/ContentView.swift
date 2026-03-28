import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Image(systemName: "heart.text.square")
                    Text("Dashboard")
                }
                .tag(0)

            CalendarView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Calendar")
                }
                .tag(1)

            FriendsView()
                .tabItem {
                    Image(systemName: "person.2")
                    Text("Friends")
                }
                .tag(2)

            TipsView()
                .tabItem {
                    Image(systemName: "lightbulb")
                    Text("Tips")
                }
                .tag(3)
        }
        .tint(.deepTeal)
    }
}
