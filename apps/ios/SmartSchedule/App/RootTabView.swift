import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                CaptureView()
            }
            .tabItem {
                Label("捕获", systemImage: "plus.circle.fill")
            }

            NavigationStack {
                InboxView()
            }
            .tabItem {
                Label("Inbox", systemImage: "tray.full")
            }

            NavigationStack {
                ReviewView()
            }
            .tabItem {
                Label("审核", systemImage: "checklist")
            }

            NavigationStack {
                CalendarHomeView()
            }
            .tabItem {
                Label("日程", systemImage: "calendar")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("设置", systemImage: "gearshape")
            }
        }
        .tint(.accentColor)
    }
}
