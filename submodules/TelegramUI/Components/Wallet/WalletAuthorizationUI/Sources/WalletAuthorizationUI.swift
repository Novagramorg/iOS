import AccountContext
import AlertComponent
import AlertInputFieldComponent
import ComponentFlow
import Display
import SwiftSignalKit
import WalletContext

private final class WalletAuthorizedOperation<Value>: Disposable {
    private let context: AccountContext
    private let present: (ViewController) -> Void
    private let operation: (String?) -> Signal<Value, WalletContext.WalletError>
    private let next: (Value) -> Void
    private let failed: (WalletContext.WalletError) -> Void
    private let disposable = MetaDisposable()
    private weak var passwordController: ViewController?
    private var isDisposed = false

    init(
        context: AccountContext,
        present: @escaping (ViewController) -> Void,
        operation: @escaping (String?) -> Signal<Value, WalletContext.WalletError>,
        next: @escaping (Value) -> Void,
        failed: @escaping (WalletContext.WalletError) -> Void
    ) {
        self.context = context
        self.present = present
        self.operation = operation
        self.next = next
        self.failed = failed
        self.start(password: nil, inputState: nil, progress: nil)
    }

    func dispose() {
        self.isDisposed = true
        self.disposable.dispose()
        self.passwordController?.dismiss(completion: nil)
    }

    private func start(
        password: String?,
        inputState: AlertInputFieldComponent.ExternalState?,
        progress: ValuePromise<Bool>?
    ) {
        guard !self.isDisposed else { return }
        progress?.set(true)
        self.disposable.set((self.operation(password)
        |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let self, !self.isDisposed else { return }
            progress?.set(false)
            self.passwordController?.dismiss(completion: nil)
            self.next(value)
        }, error: { [weak self] error in
            guard let self, !self.isDisposed else { return }
            progress?.set(false)
            switch error {
            case .requestPassword where inputState == nil:
                self.presentPasswordPrompt()
            case .requestPassword, .invalidPassword:
                inputState?.animateError()
            default:
                self.passwordController?.dismiss(completion: nil)
                self.failed(error)
            }
        }))
    }

    private func presentPasswordPrompt() {
        let inputState = AlertInputFieldComponent.ExternalState()
        let progress = ValuePromise<Bool>(false)
        let enabled = inputState.valueSignal
        |> map { !$0.isEmpty }
        var submit: (() -> Void)?
        let content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = [
            AnyComponentWithIdentity(
                id: "title",
                component: AnyComponent(AlertTitleComponent(title: "Telegram Password"))
            ),
            AnyComponentWithIdentity(
                id: "text",
                component: AnyComponent(AlertTextComponent(content: .plain(
                    "Enter your Telegram 2-Step Verification password to continue."
                )))
            ),
            AnyComponentWithIdentity(
                id: "password",
                component: AnyComponent(AlertInputFieldComponent(
                    context: self.context,
                    placeholder: "Password",
                    isSecureTextEntry: true,
                    isInitiallyFocused: true,
                    externalState: inputState,
                    returnKeyAction: { submit?() }
                ))
            )
        ]
        let controller = AlertScreen(
            configuration: AlertScreen.Configuration(allowInputInset: true),
            content: content,
            actions: [
                .init(title: "Cancel", action: { [weak self] in
                    self?.failed(.authorizationCancelled)
                }),
                .init(
                    title: "Continue",
                    type: .default,
                    action: { submit?() },
                    autoDismiss: false,
                    isEnabled: enabled,
                    progress: progress.get()
                )
            ],
            updatedPresentationData: (
                self.context.sharedContext.currentPresentationData.with { $0 },
                self.context.sharedContext.presentationData
            )
        )
        controller.dismissed = { [weak self] byOutsideTap in
            if byOutsideTap {
                let _ = (progress.get()
                |> take(1)).start(next: { [weak self] inProgress in
                    guard !inProgress else {
                        return
                    }
                    self?.failed(.authorizationCancelled)
                })
            }
        }
        submit = { [weak self] in
            guard let self else { return }
            self.start(password: inputState.value, inputState: inputState, progress: progress)
        }
        self.passwordController = controller
        self.present(controller)
    }
}

/// Runs a protected wallet operation without a password first. If Telegram asks
/// for 2FA, presents one secure prompt and retries with fresh SRP parameters.
public func performWalletAuthorizedOperation<Value>(
    context: AccountContext,
    present: @escaping (ViewController) -> Void,
    operation: @escaping (String?) -> Signal<Value, WalletContext.WalletError>,
    next: @escaping (Value) -> Void,
    failed: @escaping (WalletContext.WalletError) -> Void
) -> Disposable {
    WalletAuthorizedOperation(
        context: context,
        present: present,
        operation: operation,
        next: next,
        failed: failed
    )
}

public func walletAuthorizationErrorMessage(_ error: WalletContext.WalletError) -> (title: String, text: String)? {
    switch error {
    case .twoStepAuthMissing:
        return ("Two-Step Verification Required", "Set up a Telegram password before changing this wallet.")
    case let .passwordTooFresh(timeout):
        return ("Password Is Too New", "Try again in \(timeout) seconds.")
    case let .sessionTooFresh(timeout):
        return ("Session Is Too New", "For your security, try again in \(timeout) seconds.")
    case .backupDisabled:
        return ("Backup Is Disabled", "Enable encrypted backup before restoring the recovery phrase from Telegram.")
    case .backupNotAvailable:
        return ("Backup Unavailable", "Encrypted backup is not available for this wallet.")
    case .keyRotationFailed:
        return (
            "Couldn't Update Recovery Phrase",
            "The new recovery phrase was not activated. Your previous phrase and encrypted backup are still valid."
        )
    default:
        return nil
    }
}
