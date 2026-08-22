import Foundation
import UIKit

// Apple Review uchun demo account auto-fill.
//
// Demo raqamni (yuqoridagi `demoPhone`) reviewer kiritsa, kod code.vipads.uz
// backend'idan avtomatik olinadi, code entry maydoniga kiritiladi va submit qilinadi.
// Boshqa raqamlarda hech narsa qilmaydi (normal Telegram flow).
//
// Tuned parametrlar (CLAUDE.md §3 — real Apple rejection'lardan olingan, o'zgartirmang):
//   pollInterval 0.5s · perRequestTimeout 15s · hardTimeout 60s
//   consecutive-error auto-cancel: o'chirilgan (reviewer bo'sh ekranda qolmasin)
//
// IMPORTANT — 2026-08-21 fix (v4): "alert bor, counter aylanadi, lekin kod kelmaydi".
// Ikki sabab birga ishlagan:
//
//   1. `.otherSession` — demo akkaunt boshqa qurilmada Telegram'ga login bo'lib turgani
//      uchun Telegram kodni SMS emas, IN-APP yuborardi. SMS-forwarder uni hech qachon
//      ko'rmasdi, backend esa oldingi kodda qotib qolardi. Demo rejimda "Didn't get the
//      code?" tugmasi yashirilgani uchun reviewer uchun chiqish yo'li ham yo'q edi.
//      → Endi `codeSentToOtherSession` bo'lsa SMS'ga qayta so'rov (`auth.resendCode`)
//        avtomatik yuboriladi va Telegram haqiqiy SMS jo'natadi.
//
//   2. Baseline gate — birinchi poll'dagi qiymat "stale" deb belgilanib, undan FARQ
//      qiladigan kod kelmaguncha hech narsa yuborilmasdi. Backend qiymati o'zgarmasa
//      (yuqoridagi 1-holat, yoki Telegram ayni kodni qayta yuborsa) submit HECH QACHON
//      bo'lmasdi → 60s jim timeout. Bu v2 xatosining qaytishi edi.
//      → Endi baseline to'siq emas, afzallik: freshCodeGrace (8s) ichida yangi kod
//        kelsa uni, kelmasa backend'dagi mavjud kodni yuboramiz.
//
// UI: native UIAlertController. "Cancel auto-fill" tugma manual kiritish uchun.

public enum FenixuzDemoCodeFetcher {
//    public static let demoPhone = "+998335999479"
//    public static let cloudPassword2FA = "Xabarchi"
    public static let demoPhone = "+998333470981"
    public static let cloudPassword2FA = "demoadmin0422"

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
    ///
    /// `codeSentToOtherSession` — Telegram kodni SMS emas, boshqa faol sessiyaga
    /// (in-app) yubordi. Bunday holda SMS-forwarder kodni HECH QACHON ko'rmaydi,
    /// shuning uchun `requestSmsFallback` orqali SMS'ga qayta so'rov yuboramiz.
    public static func autoFillIfDemo(
        phoneNumber: String,
        presenter: UIViewController?,
        codeSentToOtherSession: Bool = false,
        requestSmsFallback: (() -> Void)? = nil,
        applyCode: @escaping (String) -> Void
    ) {
        guard isDemoPhone(phoneNumber) else { return }
        guard let presenter = presenter else { return }
        sharedState.attachUI(
            presenter: presenter,
            codeSentToOtherSession: codeSentToOtherSession,
            requestSmsFallback: requestSmsFallback,
            applyCode: applyCode
        )
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
        private var baselineCode: String?       // prewarm boshida backend'da turgan kod — yangiroq kodni afzal ko'rish uchun
        private var baselineCaptured = false    // birinchi poll baseline'ni qayd etgach true
        private var smsFallbackRequested = false // .otherSession uchun SMS resend bir marta so'raladi
        private var submittedAny = false        // kamida bitta kod yuborildi (alert yopilgan)
        private var fetchTask: URLSessionDataTask?
        private var pollTimer: Timer?
        private var uiTimer: Timer?
        private weak var alert: UIAlertController?
        private weak var presenter: UIViewController?
        private var applyCode: ((String) -> Void)?
        private var delivered = false
        private var cancelled = false

        // Konfiguratsiya — Apple Review timeout fix uchun tunable parametrlar (CLAUDE.md §3).
        // Backend ~0.7s'da javob beradi, lekin perRequestTimeout 15s qoldirilgan — vaqti-vaqti
        // bilan so'rov javobsiz qoladi (2026-08-21 kuzatuvi: 433 poll'dan 2 tasi bo'sh).
        // hardTimeout — yagona failure path; consecutive-errors auto-cancel
        // olib tashlandi (oldin 3 ta timeout = 15s'da cancel bo'lardi va
        // alert yo'qolardi).
        private let codeUrl = URL(string: "https://code.vipads.uz/auth/request-code")!
        private let pollInterval: TimeInterval = 0.5   // sec between poll attempts
        private let perRequestTimeout: TimeInterval = 15
        private let hardTimeout: TimeInterval = 60     // sec from prewarmStart
        // Backend oxirgi kodni saqlab turadi, shuning uchun birinchi poll odatda OLDINGI
        // kodni qaytaradi. Shuncha soniya davomida baseline'dan FARQ qiladigan (yangi kelgan)
        // kodni kutamiz; keyin saqlangan kodni baribir yuboramiz — Telegram ko'pincha ayni
        // kodni qayta yuboradi, ya'ni saqlangan kod joriy kod bo'lib chiqadi.
        private let freshCodeGrace: TimeInterval = 8
        // Birinchi kod yuborilgandan KEYINGI jim kuzatuv oynasi. Alert allaqachon yopilgan,
        // ya'ni reviewer hech narsa kutmayapti — biz orqa fonda kuzatib turamiz va kechikkan
        // SMS kelsa uni ham kiritamiz. (2026-08-21 kuzatuvi: forwarder'ga kod ba'zan
        // hardTimeout'dan keyin yetib keladi.) hardTimeout — alert deadline'i, o'zgarmadi.
        private let lateCodeWatchWindow: TimeInterval = 150

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
                self.baselineCode = nil
                self.baselineCaptured = false
                self.smsFallbackRequested = false
                self.submittedAny = false
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

        func attachUI(
            presenter: UIViewController,
            codeSentToOtherSession: Bool,
            requestSmsFallback: (() -> Void)?,
            applyCode: @escaping (String) -> Void
        ) {
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

                // Telegram kodni boshqa faol sessiyaga (in-app) yuborgan bo'lsa, SMS-forwarder
                // uni ko'rmaydi va backend eski kodda qotib qoladi. Reviewer "Didn't get the
                // code?" tugmasini ko'rmaydi (demo rejimda yashiringan), shuning uchun SMS'ga
                // qayta so'rovni o'zimiz yuboramiz — bu Telegram'ni haqiqiy SMS jo'natishga
                // majbur qiladi va forwarder joriy kodni oladi.
                if codeSentToOtherSession, !self.smsFallbackRequested, let requestSmsFallback = requestSmsFallback {
                    self.smsFallbackRequested = true
                    #if DEBUG
                    print("[FenixuzDemoLogin] code went to another session — requesting the SMS fallback")
                    #endif
                    requestSmsFallback()
                }

                // Agar prewarm paytida kod allaqachon kelgan bo'lsa, darhol yubor.
                if let code = self.capturedCode {
                    self.deliver(code)
                    return
                }

                // Alert prezent qilamiz (faqat birinchi marta; kod allaqachon yuborilgan
                // bo'lsa qayta ko'rsatmaymiz).
                if self.alert == nil, !self.submittedAny {
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
            // New backend (code.vipads.uz/auth/request-code) returns {"code":"60435"}.
            // Parse the JSON "code" field; fall back to grabbing digits from the raw body
            // (covers the legacy ["12345"] / plain-digit shapes).
            if let data = body.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let codeValue = obj["code"] {
                let digits = "\(codeValue)".filter { $0.isNumber }
                if digits.count >= 4 {
                    return String(digits.prefix(6))
                }
            }
            let digits = body.filter { $0.isNumber }
            guard digits.count >= 4 else { return nil }
            return String(digits.prefix(6))
        }

        private func performFetch() {
            guard !self.delivered, !self.cancelled else { return }

            // Kod hali yuborilmagan bo'lsa — hardTimeout alert deadline'i.
            // Yuborilgan bo'lsa — alert yopilgan, kechikkan kodni jim kuzatamiz.
            if let start = self.prewarmStart {
                let elapsed = Date().timeIntervalSince(start)
                if self.submittedAny {
                    // Code entry ekrani yopilgan (login o'tdi yoki reviewer chiqib ketdi) — to'xtaymiz.
                    if self.presenter == nil || elapsed >= self.lateCodeWatchWindow {
                        self.delivered = true
                        self.pollTimer?.invalidate()
                        return
                    }
                } else if elapsed >= self.hardTimeout {
                    self.failWithTimeout()
                    return
                }
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

                    // ACCEPTANCE LOGIC — backend bergan kodni SUBMIT qilamiz (v3 doktrinasi,
                    // CLAUDE.md §3: "stale-baseline check: disabled").
                    // Baseline endi TO'SIQ emas, faqat afzallik ko'rsatkichi:
                    //   - baseline'dan farq qilgan kod = shu login uchun kelgan yangi SMS → darhol yuboramiz.
                    //   - freshCodeGrace (8s) ichida o'zgarish bo'lmasa = Telegram ayni kodni qayta
                    //     yuborgan (yoki backend allaqachon joriy kodni saqlayapti) → saqlangan
                    //     kodni baribir yuboramiz.
                    // Eski v2 xatosi shu yerda edi: baseline'ni butunlay bloklash. Backend qiymati
                    // o'zgarmasa hech qachon submit bo'lmasdi va reviewer 60s jim ekranda qolardi.
                    // lastSubmittedCode — bir kod ikki marta yuborilmasligi uchun guard.
                    if !self.baselineCaptured {
                        self.baselineCaptured = true
                        self.baselineCode = code
                        #if DEBUG
                        print("[FenixuzDemoLogin] baseline recorded (\(code ?? "<empty>")) — preferring a fresher code for \(self.freshCodeGrace)s")
                        #endif
                        self.schedulePoll()
                        return
                    }

                    if let code = code, code != self.lastSubmittedCode {
                        let isFresherThanBaseline = code != self.baselineCode
                        let graceExpired: Bool
                        if let start = self.prewarmStart {
                            graceExpired = Date().timeIntervalSince(start) >= self.freshCodeGrace
                        } else {
                            graceExpired = true
                        }

                        if isFresherThanBaseline || graceExpired {
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
                                // Prewarm fazada to'xtab qolmaymiz: keyinroq yangiroq kod
                                // kelsa capturedCode'ni yangilaymiz (va hardTimeout ishlaydi).
                                self.schedulePoll()
                            }
                            return
                        }
                    }

                    // Kod hali baseline bilan bir xil va grace tugamagan / bo'sh / avval
                    // submit qilingan — yana so'rov.
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

        /// Kodni code-entry maydoniga qo'yib submit qiladi.
        ///
        /// Bu TERMINAL emas. Backend kechikkan kodni keyinroq berishi mumkin (yoki biz
        /// grace tugagach saqlangan kodni yuborgan bo'lsak, u eski chiqishi mumkin), shuning
        /// uchun yuborgandan keyin ham `lateCodeWatchWindow` ichida kuzatishda davom etamiz
        /// va yangi kod kelsa uni ham kiritamiz. `lastSubmittedCode` ayni kodni ikki marta
        /// yuborishdan saqlaydi.
        private func deliver(_ code: String) {
            guard !self.cancelled, code != self.lastSubmittedCode else { return }
            self.lastSubmittedCode = code
            self.capturedCode = nil
            self.uiTimer?.invalidate()
            #if DEBUG
            if let start = self.prewarmStart {
                let elapsed = Date().timeIntervalSince(start)
                print("[FenixuzDemoLogin] delivering code (\(code)) after \(String(format: "%.1f", elapsed))s")
            }
            #endif

            let apply = self.applyCode

            // Do NOT gate the login on the dismiss completion: UIKit silently drops a dismiss
            // that lands mid-present-transition, so the completion may never fire and the
            // reviewer's auto-login would hang. The `lastSubmittedCode` guard above already
            // prevents a double-submit, so dismiss without a completion and apply the code
            // unconditionally.
            if let alert = self.alert {
                alert.message = "Code received: \(code)\nSigning in..."
                alert.dismiss(animated: true, completion: nil)
                self.alert = nil
            }
            apply?(code)

            // Kechikkan kodni kutishda davom etamiz (alert allaqachon yopilgan).
            self.submittedAny = true
            self.schedulePoll()
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
