import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView().tabItem { Label("Dashboard", systemImage: "speedometer") }
            BudgetView().tabItem { Label("Budget", systemImage: "chart.bar.fill") }
            TasksView().tabItem { Label("Tagesplan", systemImage: "checklist") }
            WishlistView().tabItem { Label("Wunschliste", systemImage: "gift.fill") }
            ChatGPTView().tabItem { Label("ChatGPT", systemImage: "message.fill") }
            FlipAssistantView().tabItem { Label("Flip-Assistant", systemImage: "arrow.triangle.2.circlepath.circle") }
        }
        .accentColor(.green)
    }
}
