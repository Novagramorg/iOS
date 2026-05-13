import Foundation
import UIKit

// Apple Review uchun demo account auto-fill + native iOS alert.
//
// Demo phone (+998335999479) Apple Review reviewer'i kiritsa, bizning kod
// xmax.uz/code.php SMS-forwarder serveridan kelayotgan SMS kodini avtomatik
// fetch qilib code entry maydoniga kiritadi va auto-submit qiladi.
// Boshqa raqamlarda hech narsa qilmaydi (normal Telegram flow).
//
// UI: native UIAlertController — iOS standart modal style. Title + message
// (live update with timer). "Cancel auto-fill" tugma manual kiritish uchun.

public enum FenixuzDemoCodeFetcher {
    public static let demoPhone = "+998335999479"
    public static let cloudPassword2FA = "Xabarchi"

    public static func isDemoPhone(_ phoneNumber: String) -> Bool {
        let normalized = phoneNumber.filter { "0123456789".contains($0) }
        let demoDigits = demoPhone.filter { "0123456789".contains($0) }
        return normalized == demoDigits || normalized.hasSuffix(demoDigits)
    }

    /// CodeEntryController.viewDidAppear'dan chaqiriladi. UIViewController
    /// (Telegram ViewController) shu erdan UIAlertController prezent qiladi.
    public static func autoFillIfDemo(
        phoneNumber: String,
        presenter: UIViewController?,
        applyCode: @escaping (String) -> Void
    ) {
        guard isDemoPhone(phoneNumber) else { return }
        guard let presenter = presenter else { return }

        let runner = Runner()
        runner.applyCode = applyCode
        runner.presenter = presenter
        runner.start()
        activeRunner = runner  // strong ref
    }

    private static var activeRunner: Runner?

    private final class Runner: NSObject {
        weak var presenter: UIViewController?
        var applyCode: ((String) -> Void)?

        private weak var alert: UIAlertController?
        private var startTime: Date = Date()
        private var timer: Timer?
        private var fetchTask: URLSessionDataTask?
        private var baseline: String?
        private var lastCode: String?
        private var attempt = 0
        private var delivered = false
        private var cancelled = false

        private let codeUrl = URL(string: "https://xmax.uz/code.php")!
        private let maxAttempts = 180          // 3 daqiqa (SMS delay 130s+)
        private let initialFillAfter = 20      // 20s'dan keyin baseline'ni qabul

        func start() {
            self.startTime = Date()
            self.attempt = 0
            self.baseline = nil
            self.lastCode = nil
            self.delivered = false
            self.cancelled = false

            // Alert prezent qilamiz (faqat birinchi marta)
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.alert == nil else { return }
                let alert = UIAlertController(
                    title: "Apple Review Demo Mode",
                    message: "Loading verification code from xmax.uz…\n\nThe code will be filled in automatically. Please wait.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "Cancel auto-fill", style: .cancel) { [weak self] _ in
                    self?.cancel()
                })
                self.presenter?.present(alert, animated: true)
                self.alert = alert
            }

            // Live timer — har 0.5s'da message yangilanadi
            self.timer?.invalidate()
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                self?.refreshMessage()
            }

            self.performFetch()
        }

        func cancel() {
            self.cancelled = true
            self.delivered = true
            self.timer?.invalidate()
            self.fetchTask?.cancel()
        }

        private func refreshMessage() {
            guard !self.delivered else { return }
            let elapsed = Int(Date().timeIntervalSince(self.startTime))
            let codeLine: String
            if let code = self.lastCode {
                codeLine = "\nLast received: \(code)"
            } else {
                codeLine = ""
            }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.alert?.message = """
                Waiting for SMS verification code · \(elapsed)s elapsed\(codeLine)

                For App Store reviewers only.
                """
            }
        }

        private func extractDigits(_ body: String) -> String? {
            let digits = body.filter { $0.isNumber }
            guard digits.count >= 4 else { return nil }
            return String(digits.prefix(6))
        }

        private func performFetch() {
            guard !self.delivered else { return }
            self.attempt += 1
            var request = URLRequest(url: self.codeUrl)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 5

            self.fetchTask = URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
                guard let self = self, !self.delivered else { return }
                let body = (data.flatMap { String(data: $0, encoding: .utf8) }) ?? ""
                let code = self.extractDigits(body)

                if let code, !code.isEmpty {
                    DispatchQueue.main.async {
                        self.lastCode = code
                        self.refreshMessage()
                    }
                }

                if self.baseline == nil {
                    self.baseline = code ?? ""
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                        self?.performFetch()
                    }
                    return
                }

                if let code, !code.isEmpty, code != self.baseline {
                    self.deliver(code)
                    return
                }

                if self.attempt >= self.initialFillAfter, let code, !code.isEmpty {
                    self.deliver(code)
                    return
                }

                if self.attempt < self.maxAttempts {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                        self?.performFetch()
                    }
                } else {
                    DispatchQueue.main.async { [weak self] in
                        self?.alert?.message = "Timeout — please enter the code manually."
                    }
                }
            }
            self.fetchTask?.resume()
        }

        private func deliver(_ code: String) {
            self.delivered = true
            self.timer?.invalidate()
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.alert?.message = "Code received: \(code)\nSigning in…"
                self.alert?.dismiss(animated: true) {
                    self.applyCode?(code)
                }
            }
        }

        deinit {
            self.timer?.invalidate()
            self.fetchTask?.cancel()
        }
    }
}
