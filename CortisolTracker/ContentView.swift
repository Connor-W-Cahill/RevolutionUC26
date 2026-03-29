import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var dashboardVM = DashboardViewModel()
    @State private var calendarVM = CalendarViewModel()
    @State private var friendsVM = FriendsViewModel()
    @State private var tipsVM = TipsViewModel()

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .environment(dashboardVM)
                .tabItem {
                    Image(systemName: "heart.text.square")
                    Text("Dashboard")
                }
                .tag(0)

            CalendarView()
                .environment(calendarVM)
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Calendar")
                }
                .tag(1)

            FriendsView()
                .environment(friendsVM)
                .tabItem {
                    Image(systemName: "person.2")
                    Text("Friends")
                }
                .tag(2)

            TipsView()
                .environment(tipsVM)
                .tabItem {
                    Image(systemName: "lightbulb")
                    Text("Tips")
                }
                .tag(3)
        }
        .tint(AppTheme.deepTeal)
    }
}
