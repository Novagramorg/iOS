import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import TelegramPresentationData
import PresentationDataUtils

private final class AIEmptyStateView: UIView {
    enum Mode {
        case loading
        case notAvailable
        case error(String)
    }

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let retryButton = UIButton(type: .system)
    private var theme: PresentationTheme

    var onRetry: (() -> Void)?

    init(theme: PresentationTheme) {
        self.theme = theme
        super.init(frame: .zero)

        self.backgroundColor = theme.list.plainBackgroundColor

        if #available(iOS 13.0, *) {
            let cfg = UIImage.SymbolConfiguration(pointSize: 64, weight: .light)
            self.iconView.image = UIImage(systemName: "sparkles", withConfiguration: cfg)
        }
        self.iconView.contentMode = .scaleAspectFit
        self.iconView.tintColor = theme.list.itemAccentColor
        self.iconView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.iconView)

        self.titleLabel.textAlignment = .center
        self.titleLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        self.titleLabel.textColor = theme.list.itemPrimaryTextColor
        self.titleLabel.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.titleLabel)

        self.subtitleLabel.textAlignment = .center
        self.subtitleLabel.font = .systemFont(ofSize: 15, weight: .regular)
        self.subtitleLabel.textColor = theme.list.itemSecondaryTextColor
        self.subtitleLabel.numberOfLines = 0
        self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.subtitleLabel)

        self.spinner.color = theme.list.itemAccentColor
        self.spinner.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.spinner)

        self.retryButton.setTitle("Qayta urinib ko'rish", for: .normal)
        self.retryButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        self.retryButton.tintColor = theme.list.itemAccentColor
        self.retryButton.translatesAutoresizingMaskIntoConstraints = false
        self.retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        self.addSubview(self.retryButton)

        NSLayoutConstraint.activate([
            self.iconView.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            self.iconView.centerYAnchor.constraint(equalTo: self.centerYAnchor, constant: -80),
            self.iconView.widthAnchor.constraint(equalToConstant: 80),
            self.iconView.heightAnchor.constraint(equalToConstant: 80),

            self.titleLabel.topAnchor.constraint(equalTo: self.iconView.bottomAnchor, constant: 20),
            self.titleLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 32),
            self.titleLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -32),

            self.subtitleLabel.topAnchor.constraint(equalTo: self.titleLabel.bottomAnchor, constant: 8),
            self.subtitleLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 40),
            self.subtitleLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -40),

            self.spinner.topAnchor.constraint(equalTo: self.subtitleLabel.bottomAnchor, constant: 24),
            self.spinner.centerXAnchor.constraint(equalTo: self.centerXAnchor),

            self.retryButton.topAnchor.constraint(equalTo: self.subtitleLabel.bottomAnchor, constant: 24),
            self.retryButton.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            self.retryButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(mode: Mode) {
        switch mode {
        case .loading:
            self.titleLabel.text = "AI Asistent"
            self.subtitleLabel.text = "Tayyorlanmoqda…"
            self.spinner.startAnimating()
            self.spinner.isHidden = false
            self.retryButton.isHidden = true
        case .notAvailable:
            self.titleLabel.text = "AI hozircha mavjud emas"
            self.subtitleLabel.text = "AI asistent serverda topilmadi.\nKeyinroq qayta urinib ko'ring."
            self.spinner.stopAnimating()
            self.spinner.isHidden = true
            self.retryButton.isHidden = false
        case let .error(message):
            self.titleLabel.text = "Xatolik"
            self.subtitleLabel.text = message
            self.spinner.stopAnimating()
            self.spinner.isHidden = true
            self.retryButton.isHidden = false
        }
    }

    @objc private func retryTapped() {
        self.onRetry?()
    }
}

public final class AIChatbotTabController: ViewController {
    private let context: AccountContext
    private var chatController: ViewController?
    private let disposable = MetaDisposable()
    private var emptyStateView: AIEmptyStateView?

    private let botUsername = "fenixuz_bot"

    public init(context: AccountContext) {
        self.context = context
        super.init(navigationBarPresentationData: nil)

        self.tabBarItem.title = "AI"
        if #available(iOS 13.0, *) {
            self.tabBarItem.image = UIImage(systemName: "sparkles")
            self.tabBarItem.selectedImage = UIImage(systemName: "sparkles")
        } else {
            self.tabBarItem.image = UIImage(bundleImageName: "Chat List/Tabs/IconBots")
            self.tabBarItem.selectedImage = UIImage(bundleImageName: "Chat List/Tabs/IconBots")
        }

        self.displayNavigationBar = false
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.disposable.dispose()
    }

    public override func displayNodeDidLoad() {
        super.displayNodeDidLoad()
        let theme = self.context.sharedContext.currentPresentationData.with { $0 }.theme
        self.view.backgroundColor = theme.list.plainBackgroundColor

        self.showEmptyState(theme: theme, mode: .loading)
        self.resolveBot()
    }

    private func showEmptyState(theme: PresentationTheme, mode: AIEmptyStateView.Mode) {
        if self.emptyStateView == nil {
            let view = AIEmptyStateView(theme: theme)
            view.translatesAutoresizingMaskIntoConstraints = false
            view.onRetry = { [weak self] in
                guard let self else { return }
                self.showEmptyState(theme: theme, mode: .loading)
                self.resolveBot()
            }
            self.view.addSubview(view)
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: self.view.topAnchor),
                view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
                view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
            ])
            self.emptyStateView = view
        }
        self.emptyStateView?.update(mode: mode)
    }

    private func hideEmptyState() {
        self.emptyStateView?.removeFromSuperview()
        self.emptyStateView = nil
    }

    private func resolveBot() {
        let theme = self.context.sharedContext.currentPresentationData.with { $0 }.theme

        self.disposable.set((self.context.engine.peers.resolvePeerByName(name: self.botUsername, referrer: nil)
        |> mapToSignal { result -> Signal<EnginePeer?, NoError> in
            switch result {
            case let .result(peer):
                return .single(peer)
            case .progress:
                return .complete()
            }
        }
        |> deliverOnMainQueue).startStrict(next: { [weak self] peer in
            guard let self else { return }

            guard let peer else {
                self.showEmptyState(theme: theme, mode: .notAvailable)
                return
            }

            self.hideEmptyState()
            self.embedChat(for: peer)
        }))
    }

    private func embedChat(for peer: EnginePeer) {
        let chatController = self.context.sharedContext.makeChatController(
            context: self.context,
            chatLocation: .peer(id: peer.id),
            subject: nil,
            botStart: nil,
            mode: .standard(.default),
            params: nil
        )

        chatController.isEmbeddedBotMode = true
        chatController.navigationItem.hidesBackButton = true
        chatController.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: UIView())

        self.chatController = chatController
        self.addChild(chatController)
        self.view.addSubview(chatController.view)
        chatController.view.frame = self.view.bounds
        chatController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        chatController.didMove(toParent: self)

        if let navigationController = self.navigationController as? NavigationController {
            chatController.navigation_setNavigationController(navigationController)
        }

        if let layout = self.currentlyAppliedLayout {
            chatController.containerLayoutUpdated(layout, transition: .immediate)
            chatController.view.frame = CGRect(origin: .zero, size: layout.size)
        }
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        if let chatController = self.chatController {
            if let navigationController = self.navigationController as? NavigationController {
                chatController.navigation_setNavigationController(navigationController)
            }
            chatController.containerLayoutUpdated(layout, transition: transition)
            chatController.view.frame = CGRect(origin: .zero, size: layout.size)
        }
    }
}
