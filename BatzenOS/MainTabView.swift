import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView().tabItem {
                Label("Dashboard", systemImage: "house")
            }
            BudgetView().tabItem {
                Label("Budget", systemImage: "chart.pie")
            }
            WishlistView().tabItem {
                Label("Wunschliste", systemImage: "heart")
            }
            TasksView().tabItem {
                Label("Aufgaben", systemImage: "checkmark.square")
            }
            FlipAssistantView().tabItem {
                Label("Flip KI", systemImage: "bitcoinsign.circle")
            }
            ChatGPTView().tabItem {
                Label("Chat", systemImage: "message")
            }
        }
    }
}
