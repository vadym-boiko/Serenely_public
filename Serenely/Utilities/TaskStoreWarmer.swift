import Foundation

@MainActor
final class TaskStoreWarmer {
    static let shared = TaskStoreWarmer()
    private var warmed = false
    
    private init() {}
    
    func prewarm() {
        guard !warmed else { return }
        warmed = true
        
        let store = CoreDataStore.shared
        let existing = store.loadPendingTasks()
        // Перезаписуємо ті ж самі завдання, щоб прогріти шлях запису Core Data
        store.savePendingTasks(existing)
    }
}




