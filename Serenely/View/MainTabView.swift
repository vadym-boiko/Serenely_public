import SwiftUI
import UIKit

struct MainTabView: View {
    @EnvironmentObject var vm: TherapyChatViewModel
    @AppStorage("selected_tab") private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // ЧАТ
            NavigationStack { TherapyChatView().navigationTitle(L10n.t("app.title", "Serenely")) }
                .tabItem { Label(L10n.t("tab.chat", "Chat"), systemImage: "bubble.left.and.bubble.right") }
                .tag(0)

            // ЗАВДАННЯ
            NavigationStack { TasksView().navigationTitle(L10n.t("tasks.title", "Tasks")) }
                .tabItem { Label(L10n.t("tab.tasks", "Tasks"), systemImage: "checklist") }
                .tag(1)

            // ПОРТРЕТ
            NavigationStack { PortraitView().navigationTitle(L10n.t("portrait.title", "Portrait")) }
                .tabItem { Label(L10n.t("tab.portrait", "Portrait"), systemImage: "person.crop.circle") }
                .tag(2)
        }
        .tint(SerenelyTheme.accent)
        .onReceive(NotificationCenter.default.publisher(for: .navigateToTasks)) { _ in selectedTab = 1 }
        .onAppear {
            // Конфігурація вигляду таббару та одноразове прогрівання клавіатури,
            // щоб уникнути фрізу при першому фокусі інпуту
            configureTabAppearance()
            KeyboardWarmer.shared.prewarm()
        }
    }
}

// MARK: - Components
extension MainTabView {
    func configureTabAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.black.opacity(0.9))
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(SerenelyTheme.accent)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(SerenelyTheme.accent)]
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(SerenelyTheme.textSecondary)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(SerenelyTheme.textSecondary)]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    
}
