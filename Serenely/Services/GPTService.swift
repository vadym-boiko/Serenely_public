import Foundation

// MARK: - DTOs

struct GeneratedOutcome {
    let sessionSummary: String
    let suggestedTasks: [ActionTask]
}

// MARK: - Public protocol

protocol GPTServing {
    func sendMessage(_ message: String,
                     context: [ChatMessage],
                     portrait: UserPortrait) async throws -> ChatMessage

    func finalizeSession(from messages: [ChatMessage],
                         with portrait: UserPortrait) async throws -> GeneratedOutcome

    func regeneratePortrait(from session: [ChatMessage],
                            oldPortrait: UserPortrait,
                            lastSessionSummary: String,
                            feedbackFlags: [String],
                            taskFeedbacks: [ActionTask]) async throws -> UserPortrait

    func streamChat(_ messages: [ChatMessage], fastMode: Bool) -> AsyncThrowingStream<String, Error>
}

// MARK: - Secrets loader

private final class Secrets {
    static let shared = Secrets()
    private let dict: [String: Any]

    private init() {
        if let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
           let data = try? Data(contentsOf: url),
           let obj = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
           let d = obj as? [String: Any] {
            self.dict = d
        } else {
            self.dict = [:]
        }
    }

    var openAIKey: String {
        guard let key = dict["OPENAI_API_KEY"] as? String, !key.isEmpty else {
            assertionFailure("OPENAI_API_KEY is missing in Secrets.plist")
            return ""
        }
        return key
    }

    var preferredModel: String {
        if let m = dict["OPENAI_MODEL"] as? String, !m.isEmpty { return m }
        return "gpt-5.1" // за замовчуванням — GPT‑5.1, якщо не задано в Secrets.plist
    }
}

// MARK: - Service

final class GPTService: GPTServing {
    private let apiKey: String = Secrets.shared.openAIKey
    private var model: String { Secrets.shared.preferredModel }
    private let fallbackModel = "gpt-5.1-mini"

    // MARK: - Streaming internals

    private final class StreamingDelegate: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate {
        private var buffer = ""
        private let continuation: AsyncThrowingStream<String, Error>.Continuation
        private weak var task: URLSessionDataTask?

        init(continuation: AsyncThrowingStream<String, Error>.Continuation) {
            self.continuation = continuation
        }

        func attach(task: URLSessionDataTask) { self.task = task }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            guard !data.isEmpty else { return }
            let chunk = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
            buffer.append(chunk)

            // Обробка построчно (SSE: події як "data: {...}\n\n")
            var lines = buffer.components(separatedBy: "\n")
            buffer = lines.popLast() ?? "" // залишок без "\n"

            for raw in lines {
                let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard line.hasPrefix("data:") else { continue }
                let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                if payload == "[DONE]" {
                    continuation.finish()
                    return
                }
                // Парсимо JSON та витягуємо delta.content
                if let data = payload.data(using: .utf8),
                   let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let choices = obj["choices"] as? [[String: Any]] {
                        for choice in choices {
                            if let delta = choice["delta"] as? [String: Any] {
                                if let content = delta["content"] as? String, !content.isEmpty {
                                    continuation.yield(content)
                                }
                            } else if let msg = choice["message"] as? [String: Any],
                                      let content = msg["content"] as? String {
                                continuation.yield(content)
                            }
                            if let finish = choice["finish_reason"] as? String, !finish.isEmpty {
                                // Завершення відповіді
                                continuation.finish()
                                return
                            }
                        }
                    } else if let content = obj["text"] as? String { // інші формати
                        continuation.yield(content)
                    }
                }
            }
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            if let error = error {
                // Якщо була відміна — просто закриваємо без помилки
                if (error as NSError).code == NSURLErrorCancelled {
                    continuation.finish()
                } else {
                    continuation.finish(throwing: error)
                }
            } else {
                continuation.finish()
            }
        }
    }

    // MARK: - Public

    func sendMessage(_ message: String,
                     context: [ChatMessage],
                     portrait: UserPortrait) async throws -> ChatMessage {
        let lang = detectLanguageCode(from: message, context: context)

        var msgs: [[String: String]] = []
        let systemPromptUK = """
        Ти уважний, емпатичний співрозмовник. Пиши українською. Відповідай коротко, до 7 речень. Враховуй портрет.

        Внутрішньо можеш розмірковувати про можливі пояснення/патерни та диференційні гіпотези, але У ВІДПОВІДІ не став діагнозів, не використовуй клінічні ярлики і не роби категоричних висновків. Якщо помічаєш червоні прапорці або ризики — м’яко запропонуй звернутися до фахівця.

        summary: \(portrait.summary)
        helpfulStrategies: \(portrait.helpfulStrategies.joined(separator: ", "))
        preferences: \(portrait.preferenceWeights)
        """

        let systemPromptEN = """
        You are a caring, empathetic conversational partner. Reply in English. Keep responses short (up to 7 sentences) and consider the user portrait.

        You may reason internally about patterns and differential hypotheses, but DO NOT give diagnoses, clinical labels, or categorical statements in the response. If you notice red flags or risks, gently suggest contacting a professional.

        summary: \(portrait.summary)
        helpfulStrategies: \(portrait.helpfulStrategies.joined(separator: ", "))
        preferences: \(portrait.preferenceWeights)
        """

        msgs.append([
            "role": "system",
            "content": (lang == "en" ? systemPromptEN : systemPromptUK)
        ])
        for m in context { msgs.append(["role": role(of: m), "content": m.text]) }
        if context.last?.text != message { msgs.append(["role": "user", "content": message]) }

        let text = try await unifiedRequestText(messages: msgs, temperature: 0.7)
        return ChatMessage(sender: .assistant, text: text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func detectLanguageCode(from message: String, context: [ChatMessage]) -> String {
        // If user explicitly set app language to EN, prefer EN throughout
        if L10n.current == .en { return "en" }

        func lang(of text: String) -> String {
            let hasCyr = text.range(of: "\\p{Cyrillic}", options: .regularExpression) != nil
            return hasCyr ? "uk" : "en"
        }

        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return lang(of: trimmed) }

        // Consider the last up to 10 user messages for a more stable signal
        let recentUser = context.reversed().filter { $0.sender == .user }.prefix(10)
        if !recentUser.isEmpty {
            let votesEn = recentUser.reduce(0) { $0 + (lang(of: $1.text) == "en" ? 1 : 0) }
            let ratioEn = Double(votesEn) / Double(recentUser.count)
            return ratioEn >= 0.5 ? "en" : "uk"
        }

        // Default to app language
        return L10n.current == .en ? "en" : "uk"
    }

    func finalizeSession(from messages: [ChatMessage],
                         with portrait: UserPortrait) async throws -> GeneratedOutcome {
        let transcript = messages
            .filter { $0.sender != .system }
            .map { "\($0.sender == .user ? "USER" : "ASSISTANT"): \($0.text)" }
            .joined(separator: "\n")
        let lang = detectLanguageCode(from: "", context: messages)

        let promptUK = """
        Ти допомагаєш підсумувати розмову для приватного щоденника.

        Цілі підсумку (збільш пріоритет корисності):
        • Українська мова, теплий, підтримуючий, некатегоричний тон.
        • Сконденсований, практичний, персоналізований. Без діагнозів і узагальнень.
        • Довжина: 4–7 коротких речень.
        • ВНУТРІШНЬО можна розглянути гіпотези/патерни; У ТЕКСТІ — без діагнозів і ярликів. Якщо є «червоні прапорці», додай 1 фразу-пораду звернутися до фахівця.

        Структура підсумку (дотримуйся порядку):
        1) 1 речення — м’яке віддзеркалення стану/запиту користувача своїми словами.
        2) 1–2 речення — ключові спостереження/тригери (персонально, без моралі).
        3) 1 речення — "Фокус на сьогодні: …" (одна проста ідея).
        4) 1–2 речення — підтримка/нормалізація + обережна мотивація.

        Завдання — НЕобов’язкові, до 7 шт., але корисні. Кожне завдання повинно мати:
        • title: дуже коротка дія (5–10 хв або менше, безпечна, м’яка)
        • details: конкретика + "чому це може допомогти" + "як почати: перший крок"

        Формат ВІДПОВІДІ (дотримуйся точно):
        ПІДСУМОК:
        <4–7 речень за структурою вище>

        ЗАВДАННЯ(JSON):
        [
          {"title": "…", "details": "…"},
          ...
        ]

        Контекст портрета (враховуй для персоналізації):
        summary: \(portrait.summary)
        helpfulStrategies: \(portrait.helpfulStrategies)
        preferences: \(portrait.preferenceWeights)

        Ось транскрипт сесії:
        \(transcript)
        """

        let promptEN = """
        You help summarize a conversation for a private journal.

        Summary goals (prioritize usefulness):
        • English language, warm, supportive, non-categorical tone.
        • Concise, practical, personalized. No diagnoses or sweeping generalizations.
        • Length: 4–7 short sentences.
        • You may reason internally, but DO NOT include diagnoses/labels. If you notice red flags, add 1 gentle sentence to suggest contacting a professional.

        Summary structure (in order):
        1) 1 sentence — soft reflection of the user's state/request in your own words.
        2) 1–2 sentences — key observations/triggers (personal, without moralizing).
        3) 1 sentence — "Focus for today: …" (one simple idea).
        4) 1–2 sentences — support/normalization + gentle motivation.

        Tasks are OPTIONAL, up to 7, but useful. Each task must have:
        • title: very short action (≤10 minutes, safe, gentle)
        • details: specifics + "why it may help" + "how to start: first step"

        RESPONSE FORMAT (strict):
        SUMMARY:
        <4–7 sentences per the structure above>

        TASKS(JSON):
        [
          {"title": "…", "details": "…"},
          ...
        ]

        Portrait context (use for personalization):
        summary: \(portrait.summary)
        helpfulStrategies: \(portrait.helpfulStrategies)
        preferences: \(portrait.preferenceWeights)

        Here is the session transcript:
        \(transcript)
        """

        let msgs: [[String: String]] = [
            ["role": "system", "content": (lang == "en" ? "You are an empathetic reflection assistant. Write in English." : "Ти емпатичний асистент рефлексії. Пиши українською.")],
            ["role": "user", "content": (lang == "en" ? promptEN : promptUK)]
        ]

        let content = try await unifiedRequestText(messages: msgs, temperature: 0.5)
        let summary = extractSummary(from: content)
        let tasks = parseTasks(from: content)

        return GeneratedOutcome(
            sessionSummary: summary.isEmpty ? content : summary,
            suggestedTasks: tasks
        )
    }

    func regeneratePortrait(from session: [ChatMessage],
                            oldPortrait: UserPortrait,
                            lastSessionSummary: String,
                            feedbackFlags: [String],
                            taskFeedbacks: [ActionTask]) async throws -> UserPortrait {

        let transcript = session
            .filter { $0.sender != .system }
            .map { "\($0.sender == .user ? "USER" : "ASSISTANT"): \($0.text)" }
            .joined(separator: "\n")

        let lang = detectLanguageCode(from: "", context: session)
        let promptUK = """
        Ти — асистент, що підтримує психоемоційний щоденник. На вході:
        1) Попередній портрет (опис, стратегії, ваги вподобань).
        2) Підсумок останньої сесії та фідбек користувача.
        3) Повний транскрипт поточної сесії.

        Завдання:
        • Згенеруй АКТУАЛЬНИЙ загальний портрет (3–6 речень) — summary.
        • Онови:
          - focusAreas: 0–5 фокусів.
          - helpfulStrategies: 0–8 коротких назв технік.
          - preferenceWeights: {ключ: Double 0..1} — лише релевантні.
        • Без діагнозів/ризикованих порад.
        • УСІ РЯДКОВІ ПОЛЯ МАЮТЬ БУТИ УКРАЇНСЬКОЮ (summary, focusAreas, helpfulStrategies).

        ВІДПОВІДЬ СТРОГО ЧИСТИМ JSON:
        {
          "summary": "…",
          "focusAreas": ["…", "..."],
          "helpfulStrategies": ["…", "..."],
          "preferenceWeights": {"tone_supportive": 0.7, "pref_length": 0.3}
        }

        Попередній портрет:
        summary: \(oldPortrait.summary)
        focusAreas: \(oldPortrait.focusAreas)
        helpfulStrategies: \(oldPortrait.helpfulStrategies)
        preferenceWeights: \(oldPortrait.preferenceWeights)

        Підсумок останньої сесії:
        \(lastSessionSummary)

        Прапорці: \(feedbackFlags)
        Оцінки завдань: \(taskFeedbacks.map { "\($0.title)=\($0.usefulness.rawValue)" })

        Транскрипт:
        \(transcript)
        """

        let promptEN = """
        You are an assistant for a mental health journal. Input:
        1) Previous portrait (summary, strategies, preference weights).
        2) Last session summary and user feedback.
        3) Full transcript of the current session.

        Task:
        • Generate an UPDATED overall portrait (3–6 sentences) — summary.
        • Update:
          - focusAreas: 0–5 focus areas.
          - helpfulStrategies: 0–8 short technique names.
          - preferenceWeights: {key: Double 0..1} — only relevant.
        • No diagnoses/risky advice.
        • ALL STRING FIELDS MUST BE IN ENGLISH (summary, focusAreas, helpfulStrategies).

        RESPOND WITH STRICT, CLEAN JSON ONLY:
        {
          "summary": "…",
          "focusAreas": ["…", "..."],
          "helpfulStrategies": ["…", "..."],
          "preferenceWeights": {"tone_supportive": 0.7, "pref_length": 0.3}
        }

        Previous portrait:
        summary: \(oldPortrait.summary)
        focusAreas: \(oldPortrait.focusAreas)
        helpfulStrategies: \(oldPortrait.helpfulStrategies)
        preferenceWeights: \(oldPortrait.preferenceWeights)

        Last session summary:
        \(lastSessionSummary)

        Flags: \(feedbackFlags)
        Task ratings: \(taskFeedbacks.map { "\($0.title)=\($0.usefulness.rawValue)" })

        Transcript:
        \(transcript)
        """

        let msgs: [[String: String]] = [
            ["role": "system", "content": (lang == "en" ? "You are an empathetic assistant. Return CLEAN JSON. English." : "Ти емпатичний асистент. Дай ЧИСТИЙ JSON. Українська.")],
            ["role": "user", "content": (lang == "en" ? promptEN : promptUK)]
        ]

        let content = try await unifiedRequestText(messages: msgs, temperature: 0.5)

        let json = parseJSON(content)
        let newSummary = (json["summary"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? oldPortrait.summary
        let focus = json["focusAreas"] as? [String] ?? oldPortrait.focusAreas
        let stratRaw = json["helpfulStrategies"] as? [String] ?? oldPortrait.helpfulStrategies
        let strat = stratRaw.map { localizeStrategy($0) }
        let weights = json["preferenceWeights"] as? [String: Double] ?? oldPortrait.preferenceWeights

        func uniqueMerge(_ a: [String], _ b: [String]) -> [String] { Array(LinkedHashSet(a + b)) }
        func mergedWeights(_ old: [String: Double], _ upd: [String: Double]) -> [String: Double] {
            var out = old
            for (k, v) in upd {
                if let prev = out[k] { out[k] = max(0.0, min(1.0, (prev + v) / 2.0)) }
                else { out[k] = max(0.0, min(1.0, v)) }
            }
            return out
        }

        return UserPortrait(
            summary: newSummary.isEmpty ? oldPortrait.summary : newSummary,
            focusAreas: uniqueMerge(oldPortrait.focusAreas, focus),
            helpfulStrategies: uniqueMerge(oldPortrait.helpfulStrategies, strat),
            lastUpdated: .now,
            taskStats: oldPortrait.taskStats,
            preferenceWeights: mergedWeights(oldPortrait.preferenceWeights, weights)
        )
    }

    func streamChat(_ messages: [ChatMessage], fastMode: Bool) -> AsyncThrowingStream<String, Error> {
        // Будуємо запит до Chat Completions зі стрімінгом
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.waitsForConnectivity = true
        config.httpAdditionalHeaders = [
            "Connection": "keep-alive"
        ]

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "model": fastMode ? fallbackModel : model,
            "messages": messages.map { ["role": $0.sender.rawValue, "content": $0.text] },
            "stream": true,
            "temperature": fastMode ? 0.3 : 0.7,
            "max_tokens": fastMode ? 160 : 512
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        // AsyncThrowingStream з політикою скидання найстаріших подій
        return AsyncThrowingStream(String.self, bufferingPolicy: .bufferingOldest(64)) { continuation in
            let delegate = StreamingDelegate(continuation: continuation)
            let sessionWithDelegate = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
            let task = sessionWithDelegate.dataTask(with: request)
            delegate.attach(task: task)

            continuation.onTermination = { _ in
                task.cancel()
                sessionWithDelegate.invalidateAndCancel()
            }

            task.resume()
        }
    }

    // MARK: - Unified request (без temperature для gpt‑5)

    private func unifiedRequestText(messages: [[String: String]], temperature: Double) async throws -> String {
        let isGPT5 = model.lowercased().hasPrefix("gpt-5")

        // 1) Responses API (рекомендовано для GPT‑5)
        do {
            if let text = try await callResponsesAPI(model: model, messages: messages, includeTemperature: !isGPT5, temperature: temperature) {
                return text
            }
        } catch {
            if isModelNotFound(error) || isUnauthorized(error) {
                if let text = try await callResponsesAPI(model: fallbackModel, messages: messages, includeTemperature: true, temperature: temperature) {
                    return text
                }
            }
            // Якщо інша помилка — спробуємо chat/completions
        }

        // 2) Chat Completions (для старших моделей або як запасний варіант)
        do {
            if let text = try await callChatCompletions(model: model, messages: messages, includeTemperature: !isGPT5, temperature: temperature) {
                return text
            }
        } catch {
            if isModelNotFound(error) || isUnauthorized(error) {
                if let text = try await callChatCompletions(model: fallbackModel, messages: messages, includeTemperature: true, temperature: temperature) {
                    return text
                }
            }
            throw error
        }

        throw NSError(domain: "GPTService", code: -999, userInfo: [NSLocalizedDescriptionKey: "Порожня відповідь моделі"])
    }

    // MARK: - Low-level calls

    private func callChatCompletions(model: String,
                                     messages: [[String: String]],
                                     includeTemperature: Bool,
                                     temperature: Double) async throws -> String? {
        var body: [String: Any] = ["model": model, "messages": messages]
        if includeTemperature { body["temperature"] = temperature }

        let data = try await performRequest(path: "/v1/chat/completions", body: body)
        if
            let choices = data["choices"] as? [[String: Any]],
            let first = choices.first,
            let msg = first["message"] as? [String: Any],
            let content = msg["content"] as? String
        { return content }
        return nil
    }

    private func callResponsesAPI(model: String,
                                  messages: [[String: String]],
                                  includeTemperature: Bool,
                                  temperature: Double) async throws -> String? {
        let stitched = messages.map { "[\($0["role"] ?? "")] \($0["content"] ?? "")" }.joined(separator: "\n")
        var body: [String: Any] = ["model": model, "input": stitched]
        if includeTemperature { body["temperature"] = temperature }

        let data = try await performRequest(path: "/v1/responses", body: body)

        if let output = (data["output_text"] as? String) ?? (data["text"] as? String) {
            return output
        }
        if let out = data["output"] as? [[String: Any]] {
            let texts = out.compactMap { $0["content"] as? String }
            if !texts.isEmpty { return texts.joined(separator: "\n") }
        }
        return nil
    }

    // MARK: - HTTP layer

    private func performRequest(path: String, body: [String: Any]) async throws -> [String: Any] {
        guard let url = URL(string: "https://api.openai.com\(path)") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let text = String(data: data, encoding: .utf8) ?? ""
            print("❌ OpenAI HTTP \(http.statusCode): \(text)")
            throw NSError(domain: "GPTService", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(briefError(from: text))"])
        }

        let obj = try JSONSerialization.jsonObject(with: data, options: [])
        return (obj as? [String: Any]) ?? [:]
    }

    // MARK: - Utils

    private func role(of message: ChatMessage) -> String {
        switch message.sender {
        case .user: return "user"
        case .assistant: return "assistant"
        case .system: return "system"
        }
    }

    private func isModelNotFound(_ error: Error) -> Bool {
        let ns = error as NSError
        let msg = (ns.userInfo[NSLocalizedDescriptionKey] as? String ?? "").lowercased()
        return ns.code == 404 || msg.contains("model") && msg.contains("not") && msg.contains("found")
    }

    private func isUnauthorized(_ error: Error) -> Bool {
        (error as NSError).code == 401
    }

    private func briefError(from text: String) -> String {
        if let data = text.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let err = json["error"] as? [String: Any],
           let msg = err["message"] as? String { return msg }
        return text
    }

    private func extractSummary(from content: String) -> String {
        // Support both Ukrainian and English markers
        let ukMarker = "ПІДСУМОК:"
        let enMarker = "SUMMARY:"
        let tasksMarkers = ["ЗАВДАННЯ", "TASKS"]

        let markerRange: Range<String.Index>?
        if let r = content.range(of: enMarker) { markerRange = r }
        else { markerRange = content.range(of: ukMarker) }
        guard let r = markerRange else { return "" }

        let tail = content[r.upperBound...]
        if let tm = tasksMarkers.compactMap({ tail.range(of: $0) }).first {
            return tail[..<tm.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return tail.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseTasks(from content: String) -> [ActionTask] {
        guard let start = content.firstIndex(of: "["),
              let end = content.lastIndex(of: "]"),
              start <= end else { return [] }

        let jsonString = String(content[start...end])
        guard let data = jsonString.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }

        return arr.compactMap { d in
            guard let title = d["title"] as? String else { return nil }
            let details = d["details"] as? String
            return ActionTask(title: title, details: details)
        }
    }

    private func parseJSON(_ content: String) -> [String: Any] {
        guard let start = content.firstIndex(of: "{"),
              let end = content.lastIndex(of: "}") else { return [:] }
        let jsonString = String(content[start...end])
        guard let data = jsonString.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return obj
    }

    // MARK: - Localization helpers
    private func localizeStrategy(_ s: String) -> String {
        let lower = s.lowercased()
        // Якщо вже є кирилиця — лишаємо як є
        if lower.range(of: "\\p{Cyrillic}", options: .regularExpression) != nil { return s }
        if lower.contains("breath") { return "Дихальні вправи 4–6" }
        if lower.contains("journal") { return "Короткий джорналінг" }
        if lower.contains("walk") { return "Коротка прогулянка" }
        if lower.contains("meditat") { return "Коротка медитація" }
        if lower.contains("ground") { return "Граундінг 5-4-3-2-1" }
        if lower.contains("stretch") { return "Розтяжка 5 хвилин" }
        if lower.contains("gratitude") { return "Практика вдячності" }
        if lower.contains("music") { return "Спокійна музика 5 хв" }
        return s
    }
}

// Збереження порядку при мерджі
fileprivate struct LinkedHashSet<Element: Hashable>: Sequence {
    private var set = Set<Element>()
    private var order: [Element] = []
    init(_ array: [Element]) {
        for e in array where !set.contains(e) {
            set.insert(e); order.append(e)
        }
    }
    func makeIterator() -> IndexingIterator<[Element]> { order.makeIterator() }
}
