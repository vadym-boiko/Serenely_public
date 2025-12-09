import Foundation
import SwiftUI

extension Notification.Name {
    static let navigateToTasks = Notification.Name("navigateToTasks")
}

struct SessionHighlights {
    var summaryUpdated: Bool = false
    var summaryPreview: String? = nil
    var newFocusAreas: [String] = []
    var newStrategies: [String] = []
    var weightUps: [(String, Double)] = []   // (key, +delta)
    var weightDowns: [(String, Double)] = [] // (key, -delta)
}

@MainActor
final class TherapyChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var currentInput: String = ""
    @Published var isFinalizing: Bool = false
    @Published var isGeneratingResponse: Bool = false

    @Published var sessionSummary: String = ""
    @Published var suggestedTasks: [ActionTask] = []
    @Published var showSummarySheet: Bool = false

    @Published private(set) var portrait: UserPortrait
    @Published var lastSessionHighlights: SessionHighlights = .init()

    private let gpt: GPTServing
    private let store: PortraitStoring
    private let apiLimiter = APILimitManager.shared

    init(gpt: GPTServing = GPTService(),
         store: PortraitStoring = CoreDataStore.shared) {
        self.gpt = gpt
        self.store = store
        self.portrait = store.loadPortrait()
        self.suggestedTasks = store.loadPendingTasks()
        startNewSession()
    }

    func startNewSession() {
        messages.removeAll()
        currentInput = ""
        isFinalizing = false
        isGeneratingResponse = false
        sessionSummary = ""
        messages.append(ChatMessage(sender: .assistant, text: L10n.t("chat.welcome", "Hi! How are you feeling?")))
    }

    func send() async {
        let text = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard apiLimiter.canConsume() else {
            messages.append(
                ChatMessage(
                    sender: .assistant,
                    text: L10n.t("error.quota_reached", "Daily message limit reached. Please try again tomorrow.")
                )
            )
            return
        }

        let userMsg = ChatMessage(sender: .user, text: text)
        messages.append(userMsg)
        currentInput = ""
        
        isGeneratingResponse = true

        do {
            let reply = try await gpt.sendMessage(text, context: messages, portrait: portrait)
            messages.append(reply)
            apiLimiter.consume()
        } catch {
            messages.append(ChatMessage(sender: .assistant, text: "Вибач, сталася помилка запиту до моделі."))
            #if DEBUG
            print("sendMessage error:", error)
            #endif
        }
        
        isGeneratingResponse = false
    }

    func endSession() async {
        guard !isFinalizing else { return }
        isFinalizing = true
        do {
            let outcome = try await gpt.finalizeSession(from: messages, with: portrait)
            sessionSummary = outcome.sessionSummary
            suggestedTasks = outcome.suggestedTasks
            
            // Невелика затримка перед відображенням підсумку для плавності
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.showSummarySheet = true
                self?.isFinalizing = false
            }
        } catch {
            sessionSummary = "Не вдалось згенерувати підсумок цього разу."
            suggestedTasks = []
            // Не змінюємо pending tasks при помилці
            
            // Показати шторку з повідомленням після малої затримки
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.showSummarySheet = true
                self?.isFinalizing = false
            }
            #if DEBUG
            print("finalizeSession error:", error)
            #endif
        }
    }

    // MARK: - NEW: Очистити портрет
    func clearPortrait() {
        // 1) Очистити збережений портрет у Core Data
        store.clearPortrait()

        // 2) Скинути локальний стейт на "порожній"
        portrait = .empty

        // 3) М’яко перезапустити чат, щоб system prompt одразу підхопив новий портрет
        startNewSession()
    }

    /// Користувач підтверджує/редагує підсумок + дає фідбек по завданнях.
    func confirmSummaryAndUpdatePortrait(
        editedSummary: String,
        thumbsUp: Bool?,
        flags: [String],
        with taskFeedbacks: [ActionTask],
        saved: Bool
    ) {
        let oldPortraitSnapshot = portrait

        // 1) Побудова дельти
        let finalSummary = editedSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseSummary = finalSummary.isEmpty ? sessionSummary : finalSummary

        // Інференс нових стратегій з завдань
        var newStrategies: [String] = []
        for t in taskFeedbacks {
            // додай стратегію, якщо корисність висока АБО виконано і не low
            let isGood = (t.usefulness == .high) || (t.status == .done && t.usefulness != .low)
            if isGood {
                let s = normalizedStrategyName(from: t) // існуюча функція
                if !s.isEmpty { newStrategies.append(s) }
            }
        }

        // Апдейти ваг за прапорцями/корисністю
        var weightUpdates: [String: Double] = [:]
        if let thumbsUp {
            let delta = thumbsUp ? 0.8 : 0.2
            weightUpdates["tone_supportive"] = delta
        }
        if flags.contains("too_long") { weightUpdates["pref_length"] = 0.1 }  // коротше
        if flags.contains("too_dry")  { weightUpdates["tone_warmth"] = 0.8 }  // тепліше

        // Додаткові сигнали з завдань
        for t in taskFeedbacks {
            let key = inferredPreferenceKey(from: t) // існуюча функція
            guard !key.isEmpty else { continue }
            // мапимо корисність на сигнал
            let sig: Double
            switch t.usefulness {
            case .high:   sig = 1.0
            case .medium: sig = 0.6
            case .low:    sig = 0.2
            case .notSet: sig = 0.5
            }
            weightUpdates[key] = max(weightUpdates[key] ?? 0, sig)
        }

        // 2) Merge дельти в існуючий портрет
        let delta = PortraitDelta(
            summary: String(baseSummary.prefix(800)),
            newStrategies: newStrategies,
            weightUpdates: weightUpdates,
            focusAreas: [] // за потреби можна передавати
        )
        portrait.merge(delta)

        // 3) Оновити список pending‑завдань без втрати існуючих
        //    - По фідбеку оновлюємо статус/корисність існуючих
        //    - Не очищуємо повністю список
        //    - У pending залишаємо лише .pending / .notSet
        var mergedTasks = store.loadPendingTasks()
        for fb in taskFeedbacks {
            if let idx = mergedTasks.firstIndex(where: { $0.id == fb.id }) {
                mergedTasks[idx].status = fb.status
                mergedTasks[idx].usefulness = fb.usefulness
            } else {
                mergedTasks.append(fb)
            }
        }
        let pendingToSave = mergedTasks.filter { $0.status == .pending || $0.status == .notSet }
        store.savePendingTasks(pendingToSave)
        NotificationCenter.default.post(name: .tasksDidUpdate, object: nil)

        // Оновлюємо статистику портрету
        for t in taskFeedbacks {
            portrait.taskStats.totalSuggested += 1
            switch t.status {
            case .done:    portrait.taskStats.completed += 1
            case .skipped: portrait.taskStats.skipped += 1
            case .pending: break
            case .notSet:  break
            }

            switch t.usefulness {
            case .high:   portrait.taskStats.usefulnessHigh += 1
            case .medium: portrait.taskStats.usefulnessMedium += 1
            case .low:    portrait.taskStats.usefulnessLow += 1
            case .notSet: break
            }
        }

        // Обчислюємо диф між старим та новим портретом
        let oldP = oldPortraitSnapshot
        let newP = portrait

        var hl = SessionHighlights()

        // 1) Summary
        hl.summaryUpdated = (newP.summary.trimmingCharacters(in: .whitespacesAndNewlines)
                             != oldP.summary.trimmingCharacters(in: .whitespacesAndNewlines))
        if hl.summaryUpdated {
            hl.summaryPreview = String(newP.summary.prefix(160))
        }

        // 2) Нові фокуси/стратегії
        hl.newFocusAreas = newP.focusAreas.filter { !oldP.focusAreas.contains($0) }
        hl.newStrategies = newP.helpfulStrategies.filter { !oldP.helpfulStrategies.contains($0) }

        // 3) Зміни ваг (поріг 0.1, топ-6 за |Δ|)
        let keys = Set(oldP.preferenceWeights.keys).union(newP.preferenceWeights.keys)
        var deltas: [(String, Double)] = keys.map { key in
            let o = oldP.preferenceWeights[key] ?? 0.0
            let n = newP.preferenceWeights[key] ?? 0.0
            return (key, n - o)
        }
        deltas = deltas.filter { abs($0.1) >= 0.1 }
        deltas.sort { abs($0.1) > abs($1.1) }
        deltas = Array(deltas.prefix(6))
        hl.weightUps = deltas.filter { $0.1 > 0 }
        hl.weightDowns = deltas.filter { $0.1 < 0 }

        // Запам'ятати хайлайти
        self.lastSessionHighlights = hl

        // 4) Зберегти локально, очистити тимчасові тудушки та закрити шит
        store.savePortrait(portrait)
        showSummarySheet = false
        // Якщо користувач натиснув "Зберегти у портрет" — одразу почати нову сесію (очистити чат)
        if saved { startNewSession() }

        // 5) (опційно) асинхронно покликати regeneratePortrait для додаткового рефрешу
        let sessionSnapshot = messages
        Task {
            do {
                let regenerated = try await gpt.regeneratePortrait(
                    from: sessionSnapshot,
                    oldPortrait: portrait,
                    lastSessionSummary: portrait.summary,
                    feedbackFlags: flags,
                    taskFeedbacks: taskFeedbacks
                )
                // Замість повної заміни — м'яко змерджити відповідь моделі назад у портрет
                self.portrait.merge(PortraitDelta(
                    summary: regenerated.summary,                 // перефраз від моделі
                    newStrategies: regenerated.helpfulStrategies, // union обмежиться у merge()
                    weightUpdates: regenerated.preferenceWeights  // згладження всередині merge()
                ))
                self.store.savePortrait(self.portrait)
            } catch {
                #if DEBUG
                print("regeneratePortrait error:", error)
                #endif
            }
            // Нову сесію вже могли запустити вище при saved == true
        }
    }

    // MARK: - Helpers

    private func inferredPreferenceKey(from task: ActionTask) -> String {
        let all = (task.title + " " + (task.details ?? "")).lowercased()
        if all.contains("дихан") { return "breathing" }
        if all.contains("журнал") || all.contains("запис") { return "journaling" }
        if all.contains("прогулян") { return "walking" }
        return ""
    }

    private func normalizedStrategyName(from task: ActionTask) -> String {
        let all = (task.title + " " + (task.details ?? "")).lowercased()
        if all.contains("дихан") { return "Дихальні вправи 4-6" }
        if all.contains("журнал") || all.contains("запис") { return "Короткий джорналінг" }
        if all.contains("прогулян") { return "Коротка прогулянка" }
        return task.title
    }

    private func usefulnessDelta(_ u: TaskUsefulness) -> Double {
        switch u {
        case .high: return 1.0
        case .medium: return 0.4
        case .low: return -0.2
        case .notSet: return 0.0
        }
    }

    private func clamp01(_ x: Double) -> Double { max(0.0, min(1.0, x)) }
}
