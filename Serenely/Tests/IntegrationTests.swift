import Foundation
import XCTest

// MARK: - Інтеграційні тести

class IntegrationTests: XCTestCase {
    
    var store: CoreDataStore!
    var tasksViewModel: TasksViewModel!
    var chatViewModel: TherapyChatViewModel!
    
    override func setUp() {
        super.setUp()
        
        // Використовуємо реальний CoreDataStore з тестовим контекстом
        store = CoreDataStore()
        tasksViewModel = TasksViewModel(store: store)
        chatViewModel = TherapyChatViewModel(store: store)
    }
    
    override func tearDown() {
        // Очищуємо дані після кожного тесту
        store.clearPortrait()
        store.clearPendingTasks()
        
        store = nil
        tasksViewModel = nil
        chatViewModel = nil
        super.tearDown()
    }
    
    // MARK: - Тести синхронізації між ViewModels
    
    func testTasksSynchronization() {
        // Додаємо завдання через TasksViewModel
        tasksViewModel.addQuick(title: "Завдання з TasksViewModel")
        tasksViewModel.addQuick(title: "Інше завдання")
        
        // Перевіряємо, що завдання збережено
        let savedTasks = store.loadPendingTasks()
        XCTAssertEqual(savedTasks.count, 2)
        
        // Оновлюємо TasksViewModel
        tasksViewModel.refreshTasks()
        XCTAssertEqual(tasksViewModel.tasks.count, 2)
    }
    
    func testPortraitSynchronization() {
        // Оновлюємо портрет через ChatViewModel
        let newPortrait = UserPortrait(
            summary: "Тестовий портрет для синхронізації",
            focusAreas: ["фокус1", "фокус2"],
            helpfulStrategies: ["стратегія1"],
            lastUpdated: Date(),
            taskStats: TaskStats(totalSuggested: 5, completed: 3, skipped: 1, usefulnessHigh: 2, usefulnessMedium: 1, usefulnessLow: 0),
            preferenceWeights: ["tone_supportive": 0.8]
        )
        
        store.savePortrait(newPortrait)
        
        // Перевіряємо, що портрет збережено
        let savedPortrait = store.loadPortrait()
        XCTAssertEqual(savedPortrait.summary, "Тестовий портрет для синхронізації")
        XCTAssertEqual(savedPortrait.focusAreas.count, 2)
        XCTAssertEqual(savedPortrait.preferenceWeights["tone_supportive"], 0.8)
    }
    
    // MARK: - Тести повного циклу обробки завдань
    
    func testCompleteTaskProcessingCycle() {
        // 1. Створюємо завдання
        let task = ActionTask(
            title: "Повний цикл тестування",
            details: "Деталі для повного циклу",
            status: .pending,
            usefulness: .notSet
        )
        
        // 2. Зберігаємо через TasksViewModel
        tasksViewModel.tasks = [task]
        tasksViewModel.persist()
        
        // 3. Перевіряємо збереження
        let savedTasks = store.loadPendingTasks()
        XCTAssertEqual(savedTasks.count, 1)
        XCTAssertEqual(savedTasks[0].title, "Повний цикл тестування")
        
        // 4. Оновлюємо статус
        if let index = tasksViewModel.tasks.firstIndex(where: { $0.id == task.id }) {
            tasksViewModel.setStatus(.done, at: index)
            tasksViewModel.setUsefulness(.high, at: index)
        }
        
        // 5. Перевіряємо оновлення
        let updatedTasks = store.loadPendingTasks()
        XCTAssertEqual(updatedTasks[0].status, .done)
        XCTAssertEqual(updatedTasks[0].usefulness, .high)
    }
    
    // MARK: - Тести обробки помилок
    
    func testErrorHandling() {
        // Тестуємо обробку невалідних індексів
        tasksViewModel.addQuick(title: "Єдине завдання")
        
        // Спробуємо змінити неіснуючий індекс
        tasksViewModel.setStatus(.done, at: 10)
        tasksViewModel.setUsefulness(.high, at: 10)
        
        // Перевіряємо, що завдання не змінилося
        XCTAssertEqual(tasksViewModel.tasks[0].status, .notSet)
        XCTAssertEqual(tasksViewModel.tasks[0].usefulness, .notSet)
    }
    
    func testEmptyDataHandling() {
        // Тестуємо роботу з порожніми даними
        let emptyTasks = store.loadPendingTasks()
        XCTAssertTrue(emptyTasks.isEmpty)
        
        let emptyPortrait = store.loadPortrait()
        XCTAssertEqual(emptyPortrait.summary, UserPortrait.empty.summary)
    }
    
    // MARK: - Тести продуктивності
    
    func testPerformanceWithManyTasks() {
        // Тестуємо продуктивність з великою кількістю завдань
        let taskCount = 1000
        
        measure {
            // Створюємо багато завдань
            var tasks: [ActionTask] = []
            for i in 0..<taskCount {
                tasks.append(ActionTask(title: "Завдання \(i)"))
            }
            
            // Зберігаємо
            store.savePendingTasks(tasks)
            
            // Завантажуємо
            let loadedTasks = store.loadPendingTasks()
            XCTAssertEqual(loadedTasks.count, taskCount)
        }
    }
    
    func testPerformanceWithComplexPortrait() {
        // Тестуємо продуктивність зі складним портретом
        measure {
            let complexPortrait = UserPortrait(
                summary: "Дуже довгий підсумок " + String(repeating: "з багатьма деталями ", count: 100),
                focusAreas: (0..<50).map { "Фокус \($0)" },
                helpfulStrategies: (0..<30).map { "Стратегія \($0)" },
                lastUpdated: Date(),
                taskStats: TaskStats(
                    totalSuggested: 1000,
                    completed: 500,
                    skipped: 200,
                    usefulnessHigh: 300,
                    usefulnessMedium: 150,
                    usefulnessLow: 50
                ),
                preferenceWeights: (0..<100).reduce(into: [String: Double]()) { dict, i in
                    dict["preference_\(i)"] = Double(i) / 100.0
                }
            )
            
            // Зберігаємо та завантажуємо
            store.savePortrait(complexPortrait)
            let loadedPortrait = store.loadPortrait()
            
            XCTAssertEqual(loadedPortrait.focusAreas.count, 50)
            XCTAssertEqual(loadedPortrait.helpfulStrategies.count, 30)
            XCTAssertEqual(loadedPortrait.preferenceWeights.count, 100)
        }
    }
    
    // MARK: - Тести цілісності даних
    
    func testDataIntegrity() {
        // Тестуємо, що дані не втрачаються при операціях
        let originalTasks = [
            ActionTask(title: "Завдання 1", details: "Деталі 1", status: .pending, usefulness: .notSet),
            ActionTask(title: "Завдання 2", details: "Деталі 2", status: .done, usefulness: .high),
            ActionTask(title: "Завдання 3", details: nil, status: .skipped, usefulness: .low)
        ]
        
        // Зберігаємо
        store.savePendingTasks(originalTasks)
        
        // Завантажуємо
        let loadedTasks = store.loadPendingTasks()
        
        // Перевіряємо цілісність
        XCTAssertEqual(loadedTasks.count, originalTasks.count)
        
        for (original, loaded) in zip(originalTasks, loadedTasks) {
            XCTAssertEqual(original.id, loaded.id)
            XCTAssertEqual(original.title, loaded.title)
            XCTAssertEqual(original.details, loaded.details)
            XCTAssertEqual(original.status, loaded.status)
            XCTAssertEqual(original.usefulness, loaded.usefulness)
        }
    }
    
    func testConcurrentAccess() {
        // Тестуємо одночасний доступ до даних
        let expectation = XCTestExpectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = 10
        
        for i in 0..<10 {
            DispatchQueue.global().async {
                let task = ActionTask(title: "Concurrent task \(i)")
                self.store.savePendingTasks([task])
                let loaded = self.store.loadPendingTasks()
                XCTAssertFalse(loaded.isEmpty)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}
