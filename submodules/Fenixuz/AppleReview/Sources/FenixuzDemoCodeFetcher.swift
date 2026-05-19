import Foundation
import UIKit

// Apple Review uchun demo account auto-fill.
//
// Demo phone (+998335999479) Apple Review reviewer'i kiritsa, bizning kod
// xmax.uz/code.php SMS-forwarder serveridan kelayotgan SMS kodini avtomatik
// fetch qilib code entry maydoniga kiritadi va auto-submit qiladi.
// Boshqa raqamlarda hech narsa qilmaydi (normal Telegram flow).
//
// IMPORTANT — 2026-05-15 Apple Review timeout fix (v3):
// Eski versiya 240s+ kutardi (Apple bizni reject qildi).
// v1 (jarvis) — 240s'ni 60s'gacha kamaytirgan, lekin perRequestTimeout=5s
// va consecutive-errors gate sababli ~15s'da auto-cancel bo'lardi.
// v2 — perRequestTimeout 15s, errors retry. Lekin staleBaseline mantiq
// noto'g'ri ishlardi: xmax.uz JORIY valid kodni qaytaradi (Android shuni
// submit qilib login bo'ladi). Biz uni "stale" deb rad qilardik, keyin
// xmax.uz shu kodni qaytaraverardi → 60s timeout.
// v3 (joriy):
//   1. staleBaseline butunlay olib tashlandi — Android'dek birinchi
//      to'g'ri 4-5 raqamli kodni darhol qabul qilamiz va submit qilamiz.
//      Agar kod eski/expired bo'lsa, Telegram PHONE_CODE_INVALID qaytaradi,
//      foydalanuvchi qo'lda kiritadi (60s kutishdan yaxshiroq).
//   2. perRequestTimeout = 15s (xmax.uz ~7s'da javob beradi).
//   3. Network xatolari log qilinadi, retry davom etadi. hardTimeout
//      (60s) — yagona failure path.
//   4. PhoneEntry'da prewarmIfDemo() — polling MTProto SMS yuborilgancha
//      boshlanib turadi.
//
// UI: native UIAlertController. "Cancel auto-fill" tugma manual kiritish uchun.

public enum FenixuzDemoCodeFetcher {
    public static let demoPhone = "+998335999479"
    public static let cloudPassword2FA = "Xabarchi"

    public static func isDemoPhone(_ phoneNumber: String) -> Bool {
        let normalized = phoneNumber.filter { "0123456789".contains($0) }
        let demoDigits = demoPhone.filter { "0123456789".contains($0) }
        return normalized == demoDigits || normalized.hasSuffix(demoDigits)
    }

    /// PhoneEntry screen'da, foydalanuvchi demo raqamni tasdiqlab "Next"
    /// bosgan zahoti chaqiriladi. Polling xmax.uz'ga shu paytda boshlanadi,
    /// shunda CodeEntry screen ochilguncha (2-5s ichida) kod allaqachon
    /// bizning bufferimizda bo'ladi. Demo bo'lmagan raqamlar uchun no-op.
    /// Idempotent — bir necha marta chaqirish xavfsiz.
    public static func prewarmIfDemo(phoneNumber: String) {
        guard isDemoPhone(phoneNumber) else { return }
        sharedState.startPrewarm()
    }

    /// CodeEntryController.viewDidAppear'dan chaqiriladi.
    /// Demo phone bo'lsa: alert prezent qilamiz va prewarm'dan kod kelishini
    /// kutamiz (yoki allaqachon kelgan bo'lsa darhol applyCode chaqiriladi).
    /// Demo bo'lmagan raqamlar uchun no-op.
    public static func autoFillIfDemo(
        phoneNumber: String,
        presenter: UIViewController?,
        applyCode: @escaping (String) -> Void
    ) {
        guard isDemoPhone(phoneNumber) else { return }
        guard let presenter = presenter else { return }
        sharedState.attachUI(presenter: presenter, applyCode: applyCode)
    }

    // MARK: - Shared state

    private static let sharedState = SharedState()

    /// Polling + UI'ni boshqaradigan singleton. Asosiy mantiq:
    /// - prewarm faqat bir marta ishga tushadi (idempotent).
    /// - UI alohida attach qilinadi (CodeEntry screen ochilganda).
    /// - Agar kod prewarm paytida kelib qolgan bo'lsa va UI hali attach
    ///   qilinmagan bo'lsa, biz uni saqlaymiz va UI attach qilinishi bilanoq
    ///   yuboramiz.
    private final class SharedState {
        // State lock — barcha mutatsiyalar main queue'da bajariladi.
        private var isPolling = false
        private var prewarmStart: Date?
        private var consecutiveErrors = 0       // faqat log/telemetry uchun, auto-cancel uchun emas
        private var capturedCode: String?       // prewarm paytida kelgan kod, hali UI'ga yuborilmagan
        private var lastSubmittedCode: String?  // qayta yubormaslik uchun
        private var fetchTask: URLSessionDataTask?
        private var pollTimer: Timer?
        private var uiTimer: Timer?
        private weak var alert: UIAlertController?
        private weak var presenter: UIViewController?
        private var applyCode: ((String) -> Void)?
        private var delivered = false
        private var cancelled = false

        // Konfiguratsiya — Apple Review timeout fix uchun tunable parametrlar.
        // xmax.uz ~7s'da javob beradi, shuning uchun perRequestTimeout 15s
        // (eski 5s — har bir request timeout bo'lib qolardi).
        // hardTimeout — yagona failure path; consecutive-errors auto-cancel
        // olib tashlandi (oldin 3 ta timeout = 15s'da cancel bo'lardi va
        // alert yo'qolardi).
        private let codeUrl = URL(string: "https://xmax.uz/code.php")!
        private let pollInterval: TimeInterval = 0.5   // sec between poll attempts
        private let perRequestTimeout: TimeInterval = 15
        private let hardTimeout: TimeInterval = 60     // sec from prewarmStart

        func startPrewarm() {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                // Agar oldingi session terminal holatda bo'lsa (delivered yoki cancelled),
                // state'ni reset qilamiz — reviewer ikkinchi marta login qilishi mumkin.
                let needsReset = self.delivered || self.cancelled || !self.isPolling
                if !needsReset { return }   // already polling for this session

                self.isPolling = true
                self.prewarmStart = Date()
                self.consecutiveErrors = 0
                self.capturedCode = nil
                self.lastSubmittedCode = nil
                self.delivered = false
                self.cancelled = false
                self.uiTimer?.invalidate()
                self.pollTimer?.invalidate()
                self.fetchTask?.cancel()
                self.fetchTask = nil
                self.alert = nil
                self.applyCode = nil
                self.presenter = nil
                #if DEBUG
                print("[FenixuzDemoLogin] prewarm started at \(Date())")
                #endif
                self.performFetch()
            }
        }

        func attachUI(presenter: UIViewController, applyCode: @escaping (String) -> Void) {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.presenter = presenter
                self.applyCode = applyCode

                // Agar prewarm hali ishlamagan bo'lsa (defensive fallback) —
                // shu yerdan boshlaymiz.
                if !self.isPolling {
                    self.isPolling = true
                    self.prewarmStart = Date()
                    self.performFetch()
                }

                // Agar prewarm paytida kod allaqachon kelgan bo'lsa, darhol yubor.
                if let code = self.capturedCode {
                    self.deliver(code)
                    return
                }

                // Alert prezent qilamiz (faqat birinchi marta).
                if self.alert == nil {
                    let alert = UIAlertController(
                        title: "Demo Mode",
                        message: "Fetching verification code. This usually takes 2-10 seconds.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "Cancel auto-fill", style: .cancel) { [weak self] _ in
                        self?.cancel()
                    })
                    presenter.present(alert, animated: true)
                    self.alert = alert
                }

                // Har 0.5s'da elapsed timer yangilanadi (UI uchun).
                self.uiTimer?.invalidate()
                self.uiTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                    self?.refreshAlertMessage()
                }
            }
        }

        private func cancel() {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.cancelled = true
                self.delivered = true
                self.uiTimer?.invalidate()
                self.pollTimer?.invalidate()
                self.fetchTask?.cancel()
                self.activateCodeEntryInput()
            }
        }

        private func refreshAlertMessage() {
            guard !self.delivered, !self.cancelled else { return }
            guard let start = self.prewarmStart else { return }
            let elapsed = Int(Date().timeIntervalSince(start))
            self.alert?.message = "Fetching verification code... \(elapsed)s elapsed\n\nFor App Store reviewers only.\nTap 'Cancel auto-fill' for manual entry."
        }

        private func extractCode(from body: String) -> String? {
            // xmax.uz/code.php returns JSON array like ["12345"] or just digits.
            let digits = body.filter { $0.isNumber }
            guard digits.count >= 4 else { return nil }
            return String(digits.prefix(6))
        }

        private func performFetch() {
            guard !self.delivered, !self.cancelled else { return }

            // Hard timeout check.
            if let start = self.prewarmStart, Date().timeIntervalSince(start) >= self.hardTimeout {
                self.failWithTimeout()
                return
            }

            var request = URLRequest(url: self.codeUrl)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = self.perRequestTimeout

            self.fetchTask = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                DispatchQueue.main.async {
                    guard let self = self, !self.delivered, !self.cancelled else { return }

                    let httpOk = (response as? HTTPURLResponse)?.statusCode == 200
                    let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                    let code = self.extractCode(from: body)

                    // Network/HTTP xatolar: log qilamiz lekin auto-cancel
                    // qilmaymiz — hardTimeout (60s) yagona failure path.
                    // Buni qilmasak: 3 ta timeout ~15s da alert'ni yopib
                    // foydalanuvchini bo'sh ekranda qoldirardi.
                    if error != nil || !httpOk {
                        self.consecutiveErrors += 1
                        #if DEBUG
                        print("[FenixuzDemoLogin] poll error #\(self.consecutiveErrors): \(error?.localizedDescription ?? "HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)") — retrying")
                        #endif
                        self.schedulePoll()
                        return
                    } else {
                        self.consecutiveErrors = 0
                    }

                    // ACCEPTANCE LOGIC (v3 — Android'dek):
                    // xmax.uz JORIY valid kodni qaytaradi (eski stale emas).
                    // Birinchi to'g'ri 4-5 raqamli kodni darhol submit qilamiz.
                    // Agar kod eskirgan bo'lsa, Telegram PHONE_CODE_INVALID qaytaradi
                    // va foydalanuvchi qo'lda kiritadi — 60s kutishdan yaxshiroq.
                    // lastSubmittedCode — bir kod 2 marta yuborilmasligi uchun guard.
                    if let code = code, code != self.lastSubmittedCode {
                        if self.alert != nil || self.applyCode != nil {
                            // UI attach qilingan — darhol submit qil.
                            self.deliver(code)
                        } else {
                            // UI hali attach qilinmagan (prewarm fazada) — saqlab qo'yamiz.
                            self.capturedCode = code
                            #if DEBUG
                            if let start = self.prewarmStart {
                                let elapsed = Date().timeIntervalSince(start)
                                print("[FenixuzDemoLogin] code captured during prewarm (\(code)) after \(String(format: "%.1f", elapsed))s")
                            }
                            #endif
                        }
                        return
                    }

                    // Kod kelmadi (body bo'sh yoki avval submit qilingan) — yana so'rov.
                    self.schedulePoll()
                }
            }
            self.fetchTask?.resume()
        }

        private func schedulePoll() {
            self.pollTimer?.invalidate()
            self.pollTimer = Timer.scheduledTimer(withTimeInterval: self.pollInterval, repeats: false) { [weak self] _ in
                self?.performFetch()
            }
        }

        private func deliver(_ code: String) {
            guard !self.delivered else { return }
            self.delivered = true
            self.lastSubmittedCode = code
            self.uiTimer?.invalidate()
            self.pollTimer?.invalidate()
            #if DEBUG
            if let start = self.prewarmStart {
                let elapsed = Date().timeIntervalSince(start)
                print("[FenixuzDemoLogin] delivering code (\(code)) after \(String(format: "%.1f", elapsed))s")
            }
            #endif

            let apply = self.applyCode

            if let alert = self.alert {
                alert.message = "Code received: \(code)\nSigning in..."
                alert.dismiss(animated: true) {
                    apply?(code)
                }
            } else {
                // Edge case: applyCode set but alert never presented (rare).
                apply?(code)
            }
        }

        private func failWithTimeout() {
            #if DEBUG
            print("[FenixuzDemoLogin] timed out after \(self.hardTimeout)s")
            #endif
            self.uiTimer?.invalidate()
            self.pollTimer?.invalidate()
            self.alert?.message = "Auto-fetch unavailable (timeout). Tap 'Cancel auto-fill' to enter the code manually."
            // 2 soniyadan keyin alert'ni o'zi yopamiz — manual entry ishlasin.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self, !self.delivered else { return }
                self.alert?.dismiss(animated: true) {
                    self.activateCodeEntryInput()
                }
                self.alert = nil
                self.isPolling = false
                self.delivered = true
            }
        }

        private func activateCodeEntryInput() {
            // Alert dismiss bo'lganidan keyin Telegram'ning o'z CodeEntry'sining
            // text input'i avtomatik first responder bo'ladi (viewDidAppear'da
            // activateInput() chaqirilgan). Bu joyda biz hech narsa qilmaymiz —
            // bo'sh joy reserved (kelajakda agar focus tushib qolsa, shu yerga
            // delegate-style callback qo'yiladi).
        }
    }
}
