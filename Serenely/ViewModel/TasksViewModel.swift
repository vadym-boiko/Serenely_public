import Foundation
import Combine

extension Notification.Name {
    static let tasksDidUpdate = Notification.Name("tasksDidUpdate")
}

@MainActor
final class TasksViewModel: ObservableObject {
    @Published var tasks: [ActionTask] = []
    private let store: PortraitStoring
    private var cancellables = Set<AnyCancellable>()

    init(store: PortraitStoring = CoreDataStore.shared) {
        self.store = store
        self.tasks = store.loadPendingTasks()
        
        // Підписуємося на оновлення завдань з інших частин додатку
        NotificationCenter.default.publisher(for: .tasksDidUpdate)
            .sink { [weak self] _ in
                self?.refreshTasks()
            }
            .store(in: &cancellables)
    }
    
    func refreshTasks() {
        tasks = store.loadPendingTasks()
    }

    func setStatus(_ status: TaskStatus, at index: Int) {
        guard tasks.indices.contains(index) else { return }
        tasks[index].status = status
        persist()
    }

    func setUsefulness(_ u: TaskUsefulness, at index: Int) {
        guard tasks.indices.contains(index) else { return }
        tasks[index].usefulness = u
        persist()
    }

    func delete(at offsets: IndexSet) {
        tasks.remove(atOffsets: offsets)
        persist()
    }

    func addQuick(title: String) {
        tasks.append(ActionTask(title: title))
        persist()
    }

    func persist() {
        store.savePendingTasks(tasks)
        // Повідомляємо інші частини додатку про оновлення
        NotificationCenter.default.post(name: .tasksDidUpdate, object: nil)
    }
}
