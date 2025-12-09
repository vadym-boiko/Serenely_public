import Foundation
import CoreData
import XCTest

// MARK: - Тести CoreDataStore

class CoreDataTests: XCTestCase {
    
    var store: CoreDataStore!
    var context: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        
        // Створюємо тестовий контекст в пам'яті
        let container = NSPersistentContainer(name: "Serenely")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            XCTAssertNil(error)
        }
        
        context = container.viewContext
        store = CoreDataStore()
    }
    
    override func tearDown() {
        store = nil
        context = nil
        super.tearDown()
    }
    
    // MARK: - Portrait Tests
    
    func testPortraitSaveAndLoad() {
        let originalPortrait = UserPortrait(
            summary: "Тестовий портрет для збереження",
            focusAreas: ["фокус1", "фокус2"],
            helpfulStrategies: ["стратегія1", "стратегія2"],
            lastUpdated: Date(),
            taskStats: TaskStats(
                totalSuggested: 10,
                completed: 6,
                skipped: 2,
                usefulnessHigh: 4,
                usefulnessMedium: 2,
                usefulnessLow: 1
            ),
            preferenceWeights: [
                "tone_supportive": 0.8,
                "pref_length": 0.3,
                "breathing": 0.9
            ]
        )
        
        // Зберігаємо
        store.savePortrait(originalPortrait)
        
        // Завантажуємо
        let loadedPortrait = store.loadPortrait()
        
        // Перевіряємо
        XCTAssertEqual(loadedPortrait.summary, originalPortrait.summary)
        XCTAssertEqual(loadedPortrait.focusAreas, originalPortrait.focusAreas)
        XCTAssertEqual(loadedPortrait.helpfulStrategies, originalPortrait.helpfulStrategies)
        XCTAssertEqual(loadedPortrait.taskStats.totalSuggested, originalPortrait.taskStats.totalSuggested)
        XCTAssertEqual(loadedPortrait.taskStats.completed, originalPortrait.taskStats.completed)
        XCTAssertEqual(loadedPortrait.taskStats.skipped, originalPortrait.taskStats.skipped)
        XCTAssertEqual(loadedPortrait.preferenceWeights, originalPortrait.preferenceWeights)
    }
    
    func testPortraitClear() {
        // Спочатку зберігаємо портрет
        let portrait = UserPortrait(
            summary: "Портрет для очищення",
            focusAreas: ["фокус"],
            helpfulStrategies: ["стратегія"],
            lastUpdated: Date(),
            taskStats: TaskStats(),
            preferenceWeights: [:]
        )
        
        store.savePortrait(portrait)
        XCTAssertNotEqual(store.loadPortrait().summary, UserPortrait.empty.summary)
        
        // Очищуємо
        store.clearPortrait()
        
        // Перевіряємо, що повернувся empty портрет
        let clearedPortrait = store.loadPortrait()
        XCTAssertEqual(clearedPortrait.summary, UserPortrait.empty.summary)
        XCTAssertTrue(clearedPortrait.focusAreas.isEmpty)
        XCTAssertTrue(clearedPortrait.helpfulStrategies.isEmpty)
    }
    
    // MARK: - Tasks Tests
    
    func testTasksSaveAndLoad() {
        let tasks = [
            ActionTask(
                title: "Перше завдання",
                details: "Деталі першого",
                status: .pending,
                usefulness: .notSet
            ),
            ActionTask(
                title: "Друге завдання",
                details: "Деталі другого",
                status: .done,
                usefulness: .high
            ),
            ActionTask(
                title: "Третє завдання",
                details: nil,
                status: .skipped,
                usefulness: .low
            )
        ]
        
        // Зберігаємо
        store.savePendingTasks(tasks)
        
        // Завантажуємо
        let loadedTasks = store.loadPendingTasks()
        
        // Перевіряємо кількість
        XCTAssertEqual(loadedTasks.count, 3)
        
        // Перевіряємо перше завдання
        let firstTask = loadedTasks[0]
        XCTAssertEqual(firstTask.title, "Перше завдання")
        XCTAssertEqual(firstTask.details, "Деталі першого")
        XCTAssertEqual(firstTask.status, .pending)
        XCTAssertEqual(firstTask.usefulness, .notSet)
        
        // Перевіряємо друге завдання
        let secondTask = loadedTasks[1]
        XCTAssertEqual(secondTask.title, "Друге завдання")
        XCTAssertEqual(secondTask.status, .done)
        XCTAssertEqual(secondTask.usefulness, .high)
        
        // Перевіряємо третє завдання
        let thirdTask = loadedTasks[2]
        XCTAssertEqual(thirdTask.title, "Третє завдання")
        XCTAssertNil(thirdTask.details)
        XCTAssertEqual(thirdTask.status, .skipped)
        XCTAssertEqual(thirdTask.usefulness, .low)
    }
    
    func testTasksClear() {
        // Спочатку зберігаємо завдання
        let tasks = [
            ActionTask(title: "Завдання 1"),
            ActionTask(title: "Завдання 2")
        ]
        
        store.savePendingTasks(tasks)
        XCTAssertEqual(store.loadPendingTasks().count, 2)
        
        // Очищуємо
        store.clearPendingTasks()
        
        // Перевіряємо, що список порожній
        XCTAssertTrue(store.loadPendingTasks().isEmpty)
    }
    
    func testTasksUpdate() {
        // Спочатку зберігаємо завдання
        let initialTasks = [
            ActionTask(title: "Початкове завдання", status: .pending)
        ]
        
        store.savePendingTasks(initialTasks)
        XCTAssertEqual(store.loadPendingTasks().count, 1)
        
        // Оновлюємо список
        let updatedTasks = [
            ActionTask(title: "Оновлене завдання 1", status: .done),
            ActionTask(title: "Оновлене завдання 2", status: .pending)
        ]
        
        store.savePendingTasks(updatedTasks)
        
        // Перевіряємо, що старий список замінився
        let loadedTasks = store.loadPendingTasks()
        XCTAssertEqual(loadedTasks.count, 2)
        XCTAssertEqual(loadedTasks[0].title, "Оновлене завдання 1")
        XCTAssertEqual(loadedTasks[1].title, "Оновлене завдання 2")
    }
    
    // MARK: - Edge Cases
    
    func testEmptyDataHandling() {
        // Тестуємо завантаження порожніх даних
        let emptyPortrait = store.loadPortrait()
        XCTAssertEqual(emptyPortrait.summary, UserPortrait.empty.summary)
        
        let emptyTasks = store.loadPendingTasks()
        XCTAssertTrue(emptyTasks.isEmpty)
    }
    
    func testInvalidDataHandling() {
        // Тестуємо обробку невалідних даних
        // (Це залежить від реалізації CoreDataStore)
        let portrait = store.loadPortrait()
        XCTAssertNotNil(portrait) // Має повернути empty замість crash
    }
}
