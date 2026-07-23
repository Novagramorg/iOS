import Foundation
import UIKit
import Display
import AccountContext
import SwiftSignalKit
import TelegramPresentationData
import ComponentFlow
import ViewControllerComponent
import MultilineTextComponent
import BalancedTextComponent
import LottieComponent
import ButtonComponent
import EdgeEffect

private final class WalletWordsScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let words: [String]
    let verify: Bool
    let completion: (() -> Void)?

    init(context: AccountContext, words: [String], verify: Bool, completion: (() -> Void)?) {
        self.context = context
        self.words = words
        self.verify = verify
        self.completion = completion
    }

    static func ==(lhs: WalletWordsScreenComponent, rhs: WalletWordsScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.words != rhs.words {
            return false
        }
        if lhs.verify != rhs.verify {
            return false
        }
        return true
    }

    final class View: UIView {
        private final class WordItem {
            let number = ComponentView<Empty>()
            let word = ComponentView<Empty>()
        }

        private let scrollView: UIScrollView
        private let animation = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let text = ComponentView<Empty>()
        private var wordItems: [WordItem] = []
        private let bottomEdgeEffect: EdgeEffectView
        private let button = ComponentView<Empty>()

        private let playAnimation = ActionSlot<Void>()
        private var didPlayAnimation = false
        private var isVerifying = false

        private var environment: EnvironmentType?
        private var component: WalletWordsScreenComponent?

        override init(frame: CGRect) {
            self.scrollView = UIScrollView()
            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.scrollsToTop = true
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.contentInsetAdjustmentBehavior = .never
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.alwaysBounceVertical = true

            self.bottomEdgeEffect = EdgeEffectView()
            self.bottomEdgeEffect.isUserInteractionEnabled = false

            super.init(frame: frame)

            self.addSubview(self.scrollView)
            self.addSubview(self.bottomEdgeEffect)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func scrollToTop() {
            self.scrollView.setContentOffset(CGPoint(), animated: true)
        }

        private func dismiss() {
            self.environment?.controller()?.dismiss()
        }

        private func complete() {
            guard let component = self.component, !component.words.isEmpty, !self.isVerifying else {
                return
            }
            if component.verify {
                self.isVerifying = true
                guard let wordsController = self.environment?.controller() else {
                    self.isVerifying = false
                    return
                }
                let verificationController = component.context.sharedContext.makeWalletImportScreen(
                    context: component.context,
                    mode: .verify(words: component.words),
                    completion: { [weak self, weak wordsController] in
                        guard let wordsController else {
                            return
                        }
                        let navigationController = wordsController.navigationController as? NavigationController
                        let remainingViewControllers: [UIViewController]?
                        if let navigationController,
                           let wordsControllerIndex = navigationController.viewControllers.firstIndex(where: { $0 === wordsController }) {
                            remainingViewControllers = Array(navigationController.viewControllers.prefix(upTo: wordsControllerIndex))
                        } else {
                            remainingViewControllers = nil
                        }

                        self?.isVerifying = false
                        component.completion?()

                        guard let navigationController, let remainingViewControllers else {
                            wordsController.dismiss()
                            return
                        }

                        navigationController.setViewControllers(
                            remainingViewControllers,
                            animated: true
                        )
                    }
                )
                if let verificationController = verificationController as? ViewControllerComponentContainer {
                    verificationController.wasDismissed = { [weak self] in
                        self?.isVerifying = false
                    }
                }
                wordsController.push(verificationController)
            } else {
                component.completion?()
                self.dismiss()
            }
        }

        func update(
            component: WalletWordsScreenComponent,
            availableSize: CGSize,
            state: EmptyComponentState,
            environment: Environment<EnvironmentType>,
            transition: ComponentTransition
        ) -> CGSize {
            let environment = environment[EnvironmentType.self].value
            self.environment = environment
            self.component = component

            let theme = environment.theme
            self.backgroundColor = theme.list.plainBackgroundColor

            //TODO:localize
            let titleText = "Your Recovery Phrase"
            //TODO:localize
            let bodyText = "Your Secret Recovery Phrase is the key to\u{00a0}back up your wallet. Keep it secret and\u{00a0}secure at all times."
            //TODO:localize
            let buttonTitle = "Done"

            let buttonInsets = ContainerViewLayout.concentricInsets(
                bottomInset: environment.safeInsets.bottom,
                innerDiameter: 52.0,
                sideInset: 30.0
            )
            let bottomPanelTopInset: CGFloat = 12.0
            let bottomPanelHeight = bottomPanelTopInset + 52.0 + buttonInsets.bottom
            let bottomPanelFrame = CGRect(
                origin: CGPoint(x: 0.0, y: availableSize.height - bottomPanelHeight),
                size: CGSize(width: availableSize.width, height: bottomPanelHeight)
            )

            let sideInset = 30.0 + max(environment.safeInsets.left, environment.safeInsets.right)
            let contentWidth = max(0.0, min(430.0, availableSize.width - sideInset * 2.0))
            var contentHeight = environment.navigationHeight - 28.0

            self.animation.parentState = state
            let animationSize = CGSize(width: 108.0, height: 108.0)
            let _ = self.animation.update(
                transition: transition,
                component: AnyComponent(LottieComponent(
                    content: LottieComponent.AppBundleContent(name: "WalletWordList"),
                    startingPosition: .begin,
                    size: animationSize,
                    loop: false,
                    playOnce: self.playAnimation
                )),
                environment: {},
                containerSize: animationSize
            )
            if let animationView = self.animation.view {
                if animationView.superview == nil {
                    self.scrollView.addSubview(animationView)
                }
                transition.setFrame(
                    view: animationView,
                    frame: CGRect(
                        origin: CGPoint(x: floor((availableSize.width - animationSize.width) / 2.0), y: contentHeight),
                        size: animationSize
                    )
                )
            }
            if !self.didPlayAnimation {
                self.didPlayAnimation = true
                self.playAnimation.invoke(Void())
            }
            contentHeight += animationSize.height + 8.0

            self.title.parentState = state
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: titleText,
                        font: Font.bold(28.0),
                        textColor: theme.list.itemPrimaryTextColor
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.1
                )),
                environment: {},
                containerSize: CGSize(width: contentWidth, height: 1000.0)
            )
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.scrollView.addSubview(titleView)
                }
                transition.setFrame(
                    view: titleView,
                    frame: CGRect(
                        origin: CGPoint(x: floor((availableSize.width - titleSize.width) / 2.0), y: contentHeight),
                        size: titleSize
                    )
                )
            }
            contentHeight += titleSize.height + 5.0
            
            self.text.parentState = state
            let textSize = self.text.update(
                transition: .immediate,
                component: AnyComponent(BalancedTextComponent(
                    text: .plain(NSAttributedString(
                        string: bodyText,
                        font: Font.regular(16.0),
                        textColor: theme.list.itemPrimaryTextColor
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                )),
                environment: {},
                containerSize: CGSize(width: contentWidth, height: 1000.0)
            )
            if let textView = self.text.view {
                if textView.superview == nil {
                    self.scrollView.addSubview(textView)
                }
                transition.setFrame(
                    view: textView,
                    frame: CGRect(
                        origin: CGPoint(x: floor((availableSize.width - textSize.width) / 2.0), y: contentHeight),
                        size: textSize
                    )
                )
            }
            contentHeight += textSize.height
            contentHeight += 33.0

            while self.wordItems.count < component.words.count {
                self.wordItems.append(WordItem())
            }
            if self.wordItems.count > component.words.count {
                for item in self.wordItems[component.words.count...] {
                    item.number.view?.removeFromSuperview()
                    item.word.view?.removeFromSuperview()
                }
                self.wordItems.removeLast(self.wordItems.count - component.words.count)
            }

            let wordListWidth = min(contentWidth, 296.0)
            let minimumColumnWidth: CGFloat = 116.0
            let columnSpacing = min(40.0, max(16.0, wordListWidth - minimumColumnWidth * 2.0))
            let columnWidth = max(0.0, floorToScreenPixels((wordListWidth - columnSpacing) / 2.0))
            let wordListLayoutWidth = columnWidth * 2.0 + columnSpacing
            let wordListX = floorToScreenPixels((availableSize.width - wordListLayoutWidth) / 2.0)
            let numberWidth: CGFloat = 30.0
            let numberWordSpacing: CGFloat = 8.0
            let wordWidth = max(0.0, columnWidth - numberWidth - numberWordSpacing)
            let rowSpacing: CGFloat = 12.0
            let leftCount = min(12, (component.words.count + 1) / 2)
            let rightCount = max(0, component.words.count - leftCount)
            let rowCount = max(leftCount, rightCount)

            for rowIndex in 0 ..< rowCount {
                var layouts: [(index: Int, columnX: CGFloat, numberSize: CGSize, wordSize: CGSize)] = []
                let wordIndices: [Int?] = [
                    rowIndex < leftCount ? rowIndex : nil,
                    rowIndex < rightCount ? rowIndex + leftCount : nil
                ]

                for columnIndex in 0 ..< wordIndices.count {
                    guard let wordIndex = wordIndices[columnIndex] else {
                        continue
                    }

                    let item = self.wordItems[wordIndex]
                    item.number.parentState = state
                    item.word.parentState = state

                    let numberSize = item.number.update(
                        transition: .immediate,
                        component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: "\(wordIndex + 1).",
                                font: Font.with(size: 17.0, traits: .monospacedNumbers),
                                textColor: theme.list.itemSecondaryTextColor
                            )),
                            horizontalAlignment: .right,
                            maximumNumberOfLines: 1
                        )),
                        environment: {},
                        containerSize: CGSize(width: numberWidth, height: 100.0)
                    )
                    let wordSize = item.word.update(
                        transition: .immediate,
                        component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: component.words[wordIndex],
                                font: Font.medium(17.0),
                                textColor: theme.list.itemPrimaryTextColor
                            )),
                            maximumNumberOfLines: 0
                        )),
                        environment: {},
                        containerSize: CGSize(width: wordWidth, height: 1000.0)
                    )

                    if let numberView = item.number.view, numberView.superview == nil {
                        self.scrollView.addSubview(numberView)
                    }
                    if let wordView = item.word.view, wordView.superview == nil {
                        self.scrollView.addSubview(wordView)
                    }

                    layouts.append((
                        index: wordIndex,
                        columnX: wordListX + CGFloat(columnIndex) * (columnWidth + columnSpacing),
                        numberSize: numberSize,
                        wordSize: wordSize
                    ))
                }

                var rowHeight: CGFloat = 0.0
                for layout in layouts {
                    rowHeight = max(rowHeight, max(layout.numberSize.height, layout.wordSize.height))
                }

                for layout in layouts {
                    let item = self.wordItems[layout.index]
                    if let numberView = item.number.view {
                        transition.setFrame(
                            view: numberView,
                            frame: CGRect(
                                origin: CGPoint(
                                    x: layout.columnX + numberWidth - layout.numberSize.width,
                                    y: contentHeight + floor((rowHeight - layout.numberSize.height) / 2.0)
                                ),
                                size: layout.numberSize
                            )
                        )
                    }
                    if let wordView = item.word.view {
                        transition.setFrame(
                            view: wordView,
                            frame: CGRect(
                                origin: CGPoint(
                                    x: layout.columnX + numberWidth + numberWordSpacing,
                                    y: contentHeight + floor((rowHeight - layout.wordSize.height) / 2.0)
                                ),
                                size: layout.wordSize
                            )
                        )
                    }
                }

                contentHeight += rowHeight
                if rowIndex != rowCount - 1 {
                    contentHeight += rowSpacing
                }
            }

            contentHeight += 24.0
            contentHeight += bottomPanelHeight

            transition.setFrame(
                view: self.scrollView,
                frame: CGRect(origin: CGPoint(), size: availableSize)
            )
            let contentSize = CGSize(
                width: availableSize.width,
                height: max(contentHeight, availableSize.height + 1.0)
            )
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            let scrollInsets = UIEdgeInsets(
                top: environment.navigationHeight,
                left: 0.0,
                bottom: bottomPanelHeight,
                right: 0.0
            )
            if self.scrollView.verticalScrollIndicatorInsets != scrollInsets {
                self.scrollView.verticalScrollIndicatorInsets = scrollInsets
            }

            transition.setFrame(view: self.bottomEdgeEffect, frame: bottomPanelFrame)
            self.bottomEdgeEffect.update(
                content: theme.list.blocksBackgroundColor,
                blur: true,
                alpha: 1.0,
                rect: bottomPanelFrame,
                edge: .bottom,
                edgeSize: bottomPanelFrame.height,
                transition: transition
            )

            self.button.parentState = state
            let buttonSize = self.button.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: theme.list.itemCheckColors.fillColor,
                        foreground: theme.list.itemCheckColors.foregroundColor,
                        pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(0),
                        component: AnyComponent(Text(
                            text: buttonTitle,
                            font: Font.semibold(17.0),
                            color: theme.list.itemCheckColors.foregroundColor
                        ))
                    ),
                    isEnabled: true,
                    displaysProgress: false,
                    action: { [weak self] in
                        self?.complete()
                    }
                )),
                environment: {},
                containerSize: CGSize(
                    width: availableSize.width - buttonInsets.left - buttonInsets.right,
                    height: 52.0
                )
            )
            if let buttonView = self.button.view {
                if buttonView.superview == nil {
                    self.addSubview(buttonView)
                }
                transition.setFrame(
                    view: buttonView,
                    frame: CGRect(
                        origin: CGPoint(
                            x: buttonInsets.left,
                            y: availableSize.height - buttonInsets.bottom - buttonSize.height
                        ),
                        size: buttonSize
                    )
                )
            }

            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(
        view: View,
        availableSize: CGSize,
        state: EmptyComponentState,
        environment: Environment<EnvironmentType>,
        transition: ComponentTransition
    ) -> CGSize {
        return view.update(
            component: self,
            availableSize: availableSize,
            state: state,
            environment: environment,
            transition: transition
        )
    }
}

public final class WalletWordsScreen: ViewControllerComponentContainer {
    private let idleTimerExtensionDisposable = MetaDisposable()
    
    public init(context: AccountContext, words: [String], verify: Bool, completion: (() -> Void)?) {
        super.init(
            context: context,
            component: WalletWordsScreenComponent(context: context, words: words, verify: verify, completion: completion),
            navigationBarAppearance: .transparent,
            theme: .default
        )

        self.scrollToTop = { [weak self] in
            guard let self, let componentView = self.node.hostView.componentView as? WalletWordsScreenComponent.View else {
                return
            }
            componentView.scrollToTop()
        }
        
        self.idleTimerExtensionDisposable.set(context.sharedContext.applicationBindings.pushIdleTimerExtension())
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.idleTimerExtensionDisposable.dispose()   
    }
}
