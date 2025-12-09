import Foundation
import Combine
import XCTest

// MARK: - Mock Store для тестування

class MockPortraitStore: PortraitStoring {
    var savedPortrait: UserPortrait = .empty
    var savedTasks: [ActionTask] = []
    var clearPortraitCalled = false
    var clearTasksCalled = false
    
    func loadPortrait() -> UserPortrait {
        return savedPortrait
    }
    
    func savePortrait(_ p: UserPortrait) {
        savedPortrait = p
    }
    
    func clearPortrait() {
        clearPortraitCalled = true
        savedPortrait = .empty
    }
    
    func loadPendingTasks() -> [ActionTask] {
        return savedTasks
    }
    
    func savePendingTasks(_ tasks: [ActionTask]) {
        savedTasks = tasks
    }
    
    func clearPendingTasks() {
        clearTasksCalled = true
        savedTasks = []
    }
}

// MARK: - Тести TasksViewModel

class TasksViewModelTests: XCTestCase {
    
    var viewModel: TasksViewModel!
    var mockStore: MockPortraitStore!
    
    override func setUp() {
        super.setUp()
        mockStore = MockPortraitStore()
        viewModel = TasksViewModel(store: mockStore)
    }
    
    override func tearDown() {
        viewModel = nil
        mockStore = nil
        super.tearDown()
    }
    
    func testInitialization() {
        XCTAssertTrue(viewModel.tasks.isEmpty)
    }
    
    func testAddQuickTask() {
        let taskTitle = "Нове швидке завдання"
        
        viewModel.addQuick(title: taskTitle)
        
        XCTAssertEqual(viewModel.tasks.count, 1)
        XCTAssertEqual(viewModel.tasks[0].title, taskTitle)
        XCTAssertEqual(viewModel.tasks[0].status, .notSet)
        XCTAssertEqual(viewModel.tasks[0].usefulness, .notSet)
    }
    
    func testSetStatus() {
        // Додаємо завдання
        viewModel.addQuick(title: "Тестове завдання")
        
        // Змінюємо статус
        viewModel.setStatus(.done, at: 0)
        
        XCTAssertEqual(viewModel.tasks[0].status, .done)
    }
    
    func testSetUsefulness() {
        // Додаємо завдання
        viewModel.addQuick(title: "Тестове завдання")
        
        // Змінюємо корисність
        viewModel.setUsefulness(.high, at: 0)
        
        XCTAssertEqual(viewModel.tasks[0].usefulness, .high)
    }
    
    func testDeleteTask() {
        // Додаємо кілька завдань
        viewModel.addQuick(title: "Завдання 1")
        viewModel.addQuick(title: "Завдання 2")
        viewModel.addQuick(title: "Завдання 3")
        
        XCTAssertEqual(viewModel.tasks.count, 3)
        
        // Видаляємо друге завдання
        viewModel.delete(at: IndexSet(integer: 1))
        
        XCTAssertEqual(viewModel.tasks.count, 2)
        XCTAssertEqual(viewModel.tasks[0].title, "Завдання 1")
        XCTAssertEqual(viewModel.tasks[1].title, "Завдання 3")
    }
    
    func testPersist() {
        // Додаємо завдання
        viewModel.addQuick(title: "Завдання для збереження")
        
        // Перевіряємо, що завдання збережено в store
        XCTAssertEqual(mockStore.savedTasks.count, 1)
        XCTAssertEqual(mockStore.savedTasks[0].title, "Завдання для збереження")
    }
    
    func testRefreshTasks() {
        // Додаємо завдання в store напряму
        let tasks = [
            ActionTask(title: "Завдання з store"),
            ActionTask(title: "Інше завдання з store")
        ]
        mockStore.savePendingTasks(tasks)
        
        // Оновлюємо viewModel
        viewModel.refreshTasks()
        
        XCTAssertEqual(viewModel.tasks.count, 2)
        XCTAssertEqual(viewModel.tasks[0].title, "Завдання з store")
        XCTAssertEqual(viewModel.tasks[1].title, "Інше завдання з store")
    }
    
    func testInvalidIndexHandling() {
        // Додаємо одне завдання
        viewModel.addQuick(title: "Єдине завдання")
        
        // Спробуємо змінити статус неіснуючого індексу
        viewModel.setStatus(.done, at: 5)
        
        // Перевіряємо, що завдання не змінилося
        XCTAssertEqual(viewModel.tasks[0].status, .notSet)
    }
}

// MARK: - Тести TherapyChatViewModel

class TherapyChatViewModelTests: XCTestCase {
    
    var viewModel: TherapyChatViewModel!
    var mockStore: MockPortraitStore!
    var mockGPT: MockGPTService!
    
    override func setUp() {
        super.setUp()
        mockStore = MockPortraitStore()
        mockGPT = MockGPTService()
        viewModel = TherapyChatViewModel(gpt: mockGPT, store: mockStore)
    }
    
    override func tearDown() {
        viewModel = nil
        mockStore = nil
        mockGPT = nil
        super.tearDown()
    }
    
    func testInitialization() {
        XCTAssertEqual(viewModel.messages.count, 1) // Привітання
        XCTAssertEqual(viewModel.messages[0].sender, .assistant)
        XCTAssertTrue(viewModel.messages[0].text.contains("Привіт"))
        XCTAssertFalse(viewModel.isFinalizing)
        XCTAssertTrue(viewModel.sessionSummary.isEmpty)
        XCTAssertTrue(viewModel.suggestedTasks.isEmpty)
        XCTAssertFalse(viewModel.showSummarySheet)
    }
    
    func testStartNewSession() {
        // Додаємо повідомлення
        viewModel.messages.append(ChatMessage(sender: .user, text: "Тестове повідомлення"))
        viewModel.currentInput = "Введення"
        viewModel.isFinalizing = true
        
        // Починаємо нову сесію
        viewModel.startNewSession()
        
        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages[0].sender, .assistant)
        XCTAssertTrue(viewModel.currentInput.isEmpty)
        XCTAssertFalse(viewModel.isFinalizing)
        XCTAssertTrue(viewModel.sessionSummary.isEmpty)
        XCTAssertTrue(viewModel.suggestedTasks.isEmpty)
        XCTAssertFalse(viewModel.showSummarySheet)
    }
    
    func testClearPortrait() {
        // Встановлюємо початковий портрет
        let originalPortrait = UserPortrait(
            summary: "Оригінальний портрет",
            focusAreas: ["фокус"],
            helpfulStrategies: ["стратегія"],
            lastUpdated: Date(),
            taskStats: TaskStats(),
            preferenceWeights: ["key": 0.5]
        )
        mockStore.savePortrait(originalPortrait)
        
        // Очищуємо портрет
        viewModel.clearPortrait()
        
        // Перевіряємо, що портрет очищено
        XCTAssertTrue(mockStore.clearPortraitCalled)
        XCTAssertEqual(viewModel.portrait.summary, UserPortrait.empty.summary)
        XCTAssertTrue(viewModel.portrait.focusAreas.isEmpty)
        XCTAssertTrue(viewModel.portrait.helpfulStrategies.isEmpty)
    }
    
    func testConfirmSummaryAndUpdatePortrait() {
        // Налаштовуємо початковий стан
        viewModel.sessionSummary = "Підсумок сесії"
        let taskFeedbacks = [
            ActionTask(title: "Завдання 1", status: .done, usefulness: .high),
            ActionTask(title: "Завдання 2", status: .skipped, usefulness: .low)
        ]
        
        // Підтверджуємо підсумок
        viewModel.confirmSummaryAndUpdatePortrait(
            editedSummary: "Відредагований підсумок",
            thumbsUp: true,
            flags: ["too_long"],
            with: taskFeedbacks
        )
        
        // Перевіряємо оновлення портрету
        XCTAssertEqual(viewModel.portrait.summary, "Відредагований підсумок")
        XCTAssertTrue(viewModel.portrait.preferenceWeights["tone_supportive"]! > 0.5)
        XCTAssertTrue(viewModel.portrait.preferenceWeights["pref_length"]! < 0.5)
        
        // Перевіряємо статистику завдань
        XCTAssertEqual(viewModel.portrait.taskStats.totalSuggested, 2)
        XCTAssertEqual(viewModel.portrait.taskStats.completed, 1)
        XCTAssertEqual(viewModel.portrait.taskStats.skipped, 1)
        XCTAssertEqual(viewModel.portrait.taskStats.usefulnessHigh, 1)
        XCTAssertEqual(viewModel.portrait.taskStats.usefulnessLow, 1)
        
        // Перевіряємо, що завдання збережено
        XCTAssertEqual(mockStore.savedTasks.count, 1) // Тільки не пропущені
        XCTAssertEqual(mockStore.savedTasks[0].title, "Завдання 1")
    }
}

// MARK: - Mock GPT Service

class MockGPTService: GPTServing {
    var sendMessageResponse: ChatMessage = ChatMessage(sender: .assistant, text: "Mock response")
    var finalizeSessionResponse: GeneratedOutcome = GeneratedOutcome(
        sessionSummary: "Mock summary",
        suggestedTasks: [ActionTask(title: "Mock task")]
    )
    var regeneratePortraitResponse: UserPortrait = UserPortrait.empty
    
    func sendMessage(_ message: String, context: [ChatMessage], portrait: UserPortrait) async throws -> ChatMessage {
        return sendMessageResponse
    }
    
    func finalizeSession(from messages: [ChatMessage], with portrait: UserPortrait) async throws -> GeneratedOutcome {
        return finalizeSessionResponse
    }
    
    func regeneratePortrait(from session: [ChatMessage], oldPortrait: UserPortrait, lastSessionSummary: String, feedbackFlags: [String], taskFeedbacks: [ActionTask]) async throws -> UserPortrait {
        return regeneratePortraitResponse
    }
    
    func streamChat(_ messages: [ChatMessage], fastMode: Bool) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            continuation.yield("Mock stream response")
            continuation.finish()
        }
    }
}
