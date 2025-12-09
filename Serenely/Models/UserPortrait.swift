import Foundation

struct TaskStats: Codable {
    var totalSuggested: Int = 0
    var completed: Int = 0
    var skipped: Int = 0
    var usefulnessHigh: Int = 0
    var usefulnessMedium: Int = 0
    var usefulnessLow: Int = 0
}

struct UserPortrait: Codable {
    var summary: String
    var focusAreas: [String]
    var helpfulStrategies: [String]
    var lastUpdated: Date
    var taskStats: TaskStats
    var preferenceWeights: [String: Double]

    static let empty = UserPortrait(
        summary: "",
        focusAreas: [],
        helpfulStrategies: [],
        lastUpdated: .now,
        taskStats: TaskStats(),
        preferenceWeights: [:]
    )
}

struct PortraitDelta {
    var summary: String?                 // короткий перефраз 3–6 речень
    var newStrategies: [String] = []     // 0–8
    var weightUpdates: [String: Double] = [:] // 0..1 (зсув/сигнал)
    var focusAreas: [String] = []        // опційно, якщо хочемо оновити
}

extension UserPortrait {
    mutating func merge(_ d: PortraitDelta) {
        // 1) summary: якщо прийшов не порожній – м'яко поєднати з попереднім
        if let s = d.summary?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
            self.summary = mergedSummary(current: self.summary, incoming: s)
        }

        // 2) helpfulStrategies: унікальний union + cap до 8
        let ordered = LinkedHashSet(self.helpfulStrategies + d.newStrategies)
        self.helpfulStrategies = Array(ordered.prefix(8))

        // 3) focusAreas (якщо передали): унікалізувати і cap до 5
        if !d.focusAreas.isEmpty {
            let foc = LinkedHashSet(self.focusAreas + d.focusAreas)
            self.focusAreas = Array(foc.prefix(5))
        } else {
            self.focusAreas = Array(LinkedHashSet(self.focusAreas).prefix(5))
        }

        // 4) preferenceWeights: більш інерційне згладження (зберігаємо історію сильніше)
        for (k, v) in d.weightUpdates {
            let old = self.preferenceWeights[k, default: 0.5]
            // Інерція 0.85 до історії, 0.15 до нового сигналу
            self.preferenceWeights[k] = max(0, min(1, old * 0.85 + v * 0.15))
        }

        self.lastUpdated = .now
    }
}

// MARK: - Summary merge helper
private extension UserPortrait {
    func mergedSummary(current: String, incoming: String) -> String {
        let old = current.trimmingCharacters(in: .whitespacesAndNewlines)
        let new = incoming.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !old.isEmpty else { return String(new.prefix(800)) }

        // Якщо старий підсумок є плейсхолдером — повністю замінюємо на новий
        let placeholder = UserPortrait.empty.summary
        if old == placeholder || old.lowercased().contains("початкова сесія") {
            return String(new.prefix(800))
        }

        // Візьмемо суть зі старого (≈480 симв.) і додамо нові акценти (≈260 симв.)
        let keepOld = String(old.prefix(480))
        // Якщо початок нового вже присутній у старому — залишимо лише старе (щоб не дублювати)
        let newHead = String(new.prefix(80)).lowercased()
        if keepOld.lowercased().contains(newHead) {
            return String(keepOld.prefix(800))
        }

        let addNew = String(new.prefix(260))
        let combined = (keepOld + (keepOld.isEmpty ? "" : " ") + addNew)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(combined.prefix(800))
    }
}

// Утилітний «впорядкований сет»
fileprivate struct LinkedHashSet<Element: Hashable>: Sequence {
    private var set = Set<Element>()
    private var order: [Element] = []
    
    init(_ array: [Element]) { 
        for e in array where !set.contains(e) { 
            set.insert(e)
            order.append(e) 
        } 
    }
    
    func makeIterator() -> IndexingIterator<[Element]> { 
        order.makeIterator() 
    }
    
    func prefix(_ maxLength: Int) -> [Element] {
        Array(order.prefix(maxLength))
    }
}
