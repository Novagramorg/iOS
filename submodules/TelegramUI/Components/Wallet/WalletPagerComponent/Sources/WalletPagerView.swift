import Foundation
import UIKit
import ComponentFlow
import Display
import ViewControllerComponent

public final class WalletPagerView: UIView, UIScrollViewDelegate {
    public typealias EnvironmentType = ViewControllerComponentContainer.Environment

    private let dimView: UIView
    private let scrollView: UIScrollView
    private var itemViews: [String: ComponentHostView<EnvironmentType>] = [:]
    private var pagerState = WalletPagerState()
    private var environment: Environment<EnvironmentType>?
    private var makeContent: ((Int, Bool) -> AnyComponent<EnvironmentType>)?
    private var indexUpdated: ((Int) -> Void)?
    private var draggingBegan: ((Int) -> Void)?
    private var previousIsDisplaying = false
    private var lastReportedIndex: Int?
    private var isUpdating = false
    private var ignoreContentOffsetChange = false
    private var isSwiping = false
    private var lastScrollTime: TimeInterval = 0.0

    public override init(frame: CGRect) {
        self.dimView = UIView()
        self.dimView.backgroundColor = UIColor(white: 0.0, alpha: 0.4)

        self.scrollView = UIScrollView(frame: frame)
        self.scrollView.clipsToBounds = true
        self.scrollView.isPagingEnabled = true
        self.scrollView.showsHorizontalScrollIndicator = false
        self.scrollView.showsVerticalScrollIndicator = false
        self.scrollView.alwaysBounceHorizontal = true
        self.scrollView.bounces = true
        self.scrollView.layer.cornerRadius = 10.0
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.scrollView.contentInsetAdjustmentBehavior = .never
        }

        super.init(frame: frame)

        self.addSubview(self.dimView)
        self.scrollView.delegate = self
        self.addSubview(self.scrollView)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func reportCurrentIndex(force: Bool = false) {
        guard !self.pagerState.itemIds.isEmpty, self.pagerState.layout.isValid else {
            return
        }
        let index = self.pagerState.layout.currentIndex(at: self.scrollView.contentOffset.x)
        if force || self.lastReportedIndex != index {
            self.lastReportedIndex = index
            self.indexUpdated?(index)
        }
    }

    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard !self.pagerState.itemIds.isEmpty, self.pagerState.layout.isValid else {
            return
        }
        self.isSwiping = true
        self.lastScrollTime = CACurrentMediaTime()
        self.draggingBegan?(self.pagerState.layout.currentIndex(at: scrollView.contentOffset.x))
    }

    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            self.isSwiping = false
            self.reportCurrentIndex(force: true)
        }
    }

    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.isSwiping = false
        self.reportCurrentIndex(force: true)
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !self.ignoreContentOffsetChange, !self.isUpdating else {
            return
        }
        if self.isSwiping {
            self.lastScrollTime = CACurrentMediaTime()
        }
        self.isUpdating = true
        self.updateVisiblePages(transition: .immediate)
        self.isUpdating = false
        self.reportCurrentIndex()
    }

    private func updateVisiblePages(transition: ComponentTransition) {
        guard let environment = self.environment, let makeContent = self.makeContent else {
            return
        }
        let layout = self.pagerState.layout
        let offset = self.scrollView.contentOffset.x
        let currentIndex = layout.currentIndex(at: offset)
        let isSwipingActive = self.isSwiping || CACurrentMediaTime() - self.lastScrollTime < 0.5
        var validIds = Set<String>()

        for index in layout.candidateIndices(at: offset, isSwipingActive: isSwipingActive) {
            guard layout.isVisible(at: index, offset: offset, isSwipingActive: isSwipingActive) else {
                continue
            }
            let id = self.pagerState.itemIds[index]
            validIds.insert(id)
            let itemView: ComponentHostView<EnvironmentType>
            var itemTransition = transition
            if let current = self.itemViews[id] {
                itemView = current
            } else {
                itemTransition = transition.withAnimation(.none)
                itemView = ComponentHostView<EnvironmentType>()
                self.itemViews[id] = itemView
                self.scrollView.addSubview(itemView)
            }

            let _ = itemView.update(
                transition: itemTransition,
                component: makeContent(index, index == currentIndex),
                environment: { environment[EnvironmentType.self] },
                containerSize: layout.size
            )
            itemView.frame = layout.itemFrame(at: index)
        }

        var removeIds: [String] = []
        for (id, itemView) in self.itemViews where !validIds.contains(id) {
            removeIds.append(id)
            itemView.removeFromSuperview()
        }
        for id in removeIds {
            self.itemViews.removeValue(forKey: id)
        }
    }

    public func update(
        itemIds: [String],
        initialIndex: Int,
        itemSpacing: CGFloat,
        availableSize: CGSize,
        environment: Environment<EnvironmentType>,
        transition: ComponentTransition,
        makeContent: @escaping (Int, Bool) -> AnyComponent<EnvironmentType>,
        indexUpdated: @escaping (Int) -> Void,
        draggingBegan: @escaping (Int) -> Void
    ) -> CGSize {
        let wasUpdating = self.isUpdating
        self.isUpdating = true
        defer {
            self.isUpdating = wasUpdating
        }

        let wasInitialized = self.pagerState.isInitialized
        let targetOffset = self.pagerState.update(
            itemIds: itemIds,
            initialIndex: initialIndex,
            size: availableSize,
            itemSpacing: itemSpacing,
            offset: self.scrollView.contentOffset.x,
            isSwiping: self.isSwiping
        )
        self.environment = environment
        self.makeContent = makeContent
        self.indexUpdated = indexUpdated
        self.draggingBegan = draggingBegan

        transition.setFrame(view: self.dimView, frame: CGRect(origin: .zero, size: availableSize))
        let layout = self.pagerState.layout
        if self.scrollView.contentSize != layout.contentSize {
            self.scrollView.contentSize = layout.contentSize
        }
        if self.scrollView.frame != layout.scrollFrame {
            self.scrollView.frame = layout.scrollFrame
        }
        if self.scrollView.contentOffset != CGPoint(x: targetOffset, y: 0.0) {
            self.ignoreContentOffsetChange = true
            self.scrollView.contentOffset = CGPoint(x: targetOffset, y: 0.0)
            self.ignoreContentOffsetChange = false
        }
        self.updateVisiblePages(transition: transition)

        if let _ = transition.userData(ViewControllerComponentContainer.AnimateInTransition.self) {
            self.dimView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        } else if self.previousIsDisplaying,
                  let _ = transition.userData(ViewControllerComponentContainer.AnimateOutTransition.self) {
            self.dimView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
        }
        self.previousIsDisplaying = environment[EnvironmentType.self].value.isVisible

        if !wasInitialized && self.pagerState.isInitialized {
            self.reportCurrentIndex(force: true)
        }
        return availableSize
    }
}
