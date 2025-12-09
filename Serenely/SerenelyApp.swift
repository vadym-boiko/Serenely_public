import SwiftUI

@main
struct SerenelyApp: App {
    @StateObject var chatVM = TherapyChatViewModel()
    @StateObject var locale = LocalizationManager()
    @State private var showLaunch = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showLaunch {
                    LaunchView {
                        withAnimation(.easeInOut(duration: 0.25)) { showLaunch = false }
                    }
                } else {
                    MainTabView()
                }
            }
            .environmentObject(chatVM)
            .environmentObject(locale)
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
            .preferredColorScheme(.dark)
            .id(locale.language)
            .onAppear {
                KeyboardWarmer.shared.prewarm()
                TaskStoreWarmer.shared.prewarm()
            }
        }
    }
}
