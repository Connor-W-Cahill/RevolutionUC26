import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "heart.text.square.fill" : "heart.text.square")
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
                    Image(systemName: selectedTab == 2 ? "person.2.fill" : "person.2")
                    Text("Friends")
                }
                .tag(2)

            TipsView()
                .tabItem {
                    Image(systemName: selectedTab == 3 ? "lightbulb.fill" : "lightbulb")
                    Text("Tips")
                }
                .tag(3)
        }
        .tint(Color(hex: "1A6B5C"))
    }
}
