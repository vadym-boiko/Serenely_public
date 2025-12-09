import Foundation
import XCTest

// MARK: - Тести моделі даних

class ModelTests: XCTestCase {
    
    // MARK: - ActionTask Tests
    
    func testActionTaskCreation() {
        let task = ActionTask(
            title: "Тестове завдання",
            details: "Деталі завдання",
            status: .pending,
            usefulness: .high
        )
        
        XCTAssertEqual(task.title, "Тестове завдання")
        XCTAssertEqual(task.details, "Деталі завдання")
        XCTAssertEqual(task.status, .pending)
        XCTAssertEqual(task.usefulness, .high)
        XCTAssertNotNil(task.id)
        XCTAssertNotNil(task.createdAt)
    }
    
    func testActionTaskEquality() {
        let id = UUID()
        let date = Date()
        
        let task1 = ActionTask(
            id: id,
            title: "Завдання",
            details: "Деталі",
            createdAt: date,
            status: .done,
            usefulness: .medium
        )
        
        let task2 = ActionTask(
            id: id,
            title: "Завдання",
            details: "Деталі",
            createdAt: date,
            status: .done,
            usefulness: .medium
        )
        
        XCTAssertEqual(task1, task2)
    }
    
    // MARK: - UserPortrait Tests
    
    func testUserPortraitCreation() {
        let portrait = UserPortrait(
            summary: "Тестовий портрет",
            focusAreas: ["фокус1", "фокус2"],
            helpfulStrategies: ["стратегія1"],
            lastUpdated: Date(),
            taskStats: TaskStats(
                totalSuggested: 10,
                completed: 5,
                skipped: 2,
                usefulnessHigh: 3,
                usefulnessMedium: 2,
                usefulnessLow: 1
            ),
            preferenceWeights: ["tone_supportive": 0.8, "pref_length": 0.3]
        )
        
        XCTAssertEqual(portrait.summary, "Тестовий портрет")
        XCTAssertEqual(portrait.focusAreas.count, 2)
        XCTAssertEqual(portrait.helpfulStrategies.count, 1)
        XCTAssertEqual(portrait.taskStats.totalSuggested, 10)
        XCTAssertEqual(portrait.preferenceWeights["tone_supportive"], 0.8)
    }
    
    func testUserPortraitEmpty() {
        let empty = UserPortrait.empty
        
        XCTAssertFalse(empty.summary.isEmpty)
        XCTAssertTrue(empty.focusAreas.isEmpty)
        XCTAssertTrue(empty.helpfulStrategies.isEmpty)
        XCTAssertEqual(empty.taskStats.totalSuggested, 0)
        XCTAssertTrue(empty.preferenceWeights.isEmpty)
    }
    
    // MARK: - TaskStats Tests
    
    func testTaskStatsCalculation() {
        var stats = TaskStats()
        
        // Симуляція додавання завдань
        stats.totalSuggested += 3
        stats.completed += 2
        stats.skipped += 1
        stats.usefulnessHigh += 1
        stats.usefulnessMedium += 1
        stats.usefulnessLow += 1
        
        XCTAssertEqual(stats.totalSuggested, 3)
        XCTAssertEqual(stats.completed, 2)
        XCTAssertEqual(stats.skipped, 1)
        XCTAssertEqual(stats.usefulnessHigh, 1)
        XCTAssertEqual(stats.usefulnessMedium, 1)
        XCTAssertEqual(stats.usefulnessLow, 1)
    }
    
    // MARK: - PortraitDelta Tests
    
    func testPortraitDeltaMerge() {
        var portrait = UserPortrait.empty
        
        let delta = PortraitDelta(
            summary: "Оновлений портрет",
            newStrategies: ["Нова стратегія"],
            weightUpdates: ["tone_supportive": 0.9],
            focusAreas: ["Новий фокус"]
        )
        
        portrait.merge(delta)
        
        XCTAssertEqual(portrait.summary, "Оновлений портрет")
        XCTAssertTrue(portrait.helpfulStrategies.contains("Нова стратегія"))
        XCTAssertTrue(portrait.focusAreas.contains("Новий фокус"))
        XCTAssertEqual(portrait.preferenceWeights["tone_supportive"], 0.9)
    }
}

// MARK: - Тести JSON кодування

extension ModelTests {
    
    func testActionTaskCodable() throws {
        let task = ActionTask(
            title: "JSON тест",
            details: "Деталі для JSON",
            status: .done,
            usefulness: .high
        )
        
        let data = try JSONEncoder().encode(task)
        let decoded = try JSONDecoder().decode(ActionTask.self, from: data)
        
        XCTAssertEqual(task.id, decoded.id)
        XCTAssertEqual(task.title, decoded.title)
        XCTAssertEqual(task.details, decoded.details)
        XCTAssertEqual(task.status, decoded.status)
        XCTAssertEqual(task.usefulness, decoded.usefulness)
    }
    
    func testUserPortraitCodable() throws {
        let portrait = UserPortrait(
            summary: "JSON портрет",
            focusAreas: ["фокус1", "фокус2"],
            helpfulStrategies: ["стратегія1"],
            lastUpdated: Date(),
            taskStats: TaskStats(totalSuggested: 5, completed: 3, skipped: 1, usefulnessHigh: 2, usefulnessMedium: 1, usefulnessLow: 0),
            preferenceWeights: ["key1": 0.5, "key2": 0.8]
        )
        
        let data = try JSONEncoder().encode(portrait)
        let decoded = try JSONDecoder().decode(UserPortrait.self, from: data)
        
        XCTAssertEqual(portrait.summary, decoded.summary)
        XCTAssertEqual(portrait.focusAreas, decoded.focusAreas)
        XCTAssertEqual(portrait.helpfulStrategies, decoded.helpfulStrategies)
        XCTAssertEqual(portrait.taskStats.totalSuggested, decoded.taskStats.totalSuggested)
        XCTAssertEqual(portrait.preferenceWeights, decoded.preferenceWeights)
    }
}
