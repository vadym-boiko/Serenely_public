import UIKit

// One-time invisible keyboard warm-up to avoid first-focus lag
final class KeyboardWarmer {
    static let shared = KeyboardWarmer()
    private var warmed = false
    private var retryCount = 0
    private let maxRetries = 5

    private init() {}

    func prewarm() {
        // Всегда выполняем на главном потоке
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in self?.prewarm() }
            return
        }
        guard !warmed else { return }

        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) else {
                // Окно ещё не готово — делаем несколько повторных попыток
                if retryCount < maxRetries {
                    retryCount += 1
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                        self?.prewarm()
                    }
                }
                return
            }

        // Hidden UITextField to trigger keyboard subsystem initialization
        let tf = UITextField(frame: .zero)
        tf.isHidden = true
        window.addSubview(tf)
        DispatchQueue.main.async { [weak self, weak tf] in
            tf?.becomeFirstResponder()
            tf?.resignFirstResponder()
            tf?.removeFromSuperview()
            self?.warmed = true
        }
    }
}
