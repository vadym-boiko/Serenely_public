import Foundation

@MainActor
final class APILimitManager {
    static let shared = APILimitManager()
    
    private let dailyLimit = 30               // max API calls per day per device
    private let counterKey = "api_daily_count"
    private let dateKey = "api_daily_date"
    
    private init() {}
    
    private var todayKey: String {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return "\(comps.year ?? 0)-\(comps.month ?? 0)-\(comps.day ?? 0)"
    }
    
    private func resetIfNeeded() {
        let storedDate = UserDefaults.standard.string(forKey: dateKey)
        if storedDate != todayKey {
            UserDefaults.standard.set(todayKey, forKey: dateKey)
            UserDefaults.standard.set(0, forKey: counterKey)
        }
    }
    
    func canConsume(_ amount: Int = 1) -> Bool {
        resetIfNeeded()
        let current = UserDefaults.standard.integer(forKey: counterKey)
        return current + amount <= dailyLimit
    }
    
    func consume(_ amount: Int = 1) {
        resetIfNeeded()
        let current = UserDefaults.standard.integer(forKey: counterKey)
        UserDefaults.standard.set(current + amount, forKey: counterKey)
    }
}



