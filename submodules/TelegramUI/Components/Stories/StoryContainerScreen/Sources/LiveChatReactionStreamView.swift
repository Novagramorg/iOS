import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramCore
import AvatarNode
import AppBundle
import AccountContext
import HierarchyTrackingLayer

private func makePeerBadgeImage(engine: TelegramEngine, peer: EnginePeer, count: Int) async -> UIImage {
    let avatarSize: CGFloat = 16.0
    let avatarInset: CGFloat = 2.0
    let avatarIconSpacing: CGFloat = 2.0
    let iconTextSpacing: CGFloat = 2.0
    let iconSize: CGFloat = 8.0
    let rightInset: CGFloat = 4.0
    
    let text = NSAttributedString(string: "\(count)", font: Font.semibold(10.0), textColor: .white)
    var textSize = text.boundingRect(with: CGSize(width: 100.0, height: 100.0), options: .usesLineFragmentOrigin, context: nil).size
    textSize.width = ceil(textSize.width)
    textSize.height = ceil(textSize.height)
    
    let size = CGSize(width: avatarInset + avatarSize + avatarIconSpacing + iconSize + iconTextSpacing + textSize.height + rightInset, height: avatarSize + avatarInset * 2.0)
    return generateImage(size, rotatedContext: { size, context in
        UIGraphicsPushContext(context)
        defer {
            UIGraphicsPopContext()
        }
        
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(UIColor(rgb: 0xFFB10D).cgColor)
        context.addPath(UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: size), cornerRadius: size.height * 0.5).cgPath)
        context.fillPath()
        
        text.draw(at: CGPoint(x: avatarInset + avatarSize + avatarIconSpacing + iconSize + iconTextSpacing, y: floorToScreenPixels((size.height - textSize.height) * 0.5)))
    })!
}

private actor LiveChatReactionItemTaskQueue {
    private final class PeerTask {
        let peer: EnginePeer
        let count: Int
        let completion: (UIImage) -> Void
        
        init(peer: EnginePeer, count: Int, completion: @escaping (UIImage) -> Void) {
            self.peer = peer
            self.count = count
            self.completion = completion
        }
    }
    
    private let engine: TelegramEngine
    private var tasks: [PeerTask] = []
    
    init(engine: TelegramEngine) {
        self.engine = engine
    }
    
    func add(peer: EnginePeer, count: Int, completion: @escaping (UIImage) -> Void) {
        self.tasks.append(PeerTask(peer: peer, count: count, completion: completion))
        if self.tasks.count == 1 {
            Task {
                await processTasks()
            }
        }
    }
    
    private func processTasks() async {
        while !self.tasks.isEmpty {
            let task = self.tasks.removeFirst()
            let image = await makePeerBadgeImage(engine: self.engine, peer: task.peer, count: task.count)
            task.completion(image)
        }
    }
}

final class LiveChatReactionStreamView: UIView {
    private final class ItemLayer: SimpleLayer {
        init(image: UIImage) {
            super.init()
            
            self.contents = image.cgImage
        }

        override init(layer: Any) {
            super.init(layer: layer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }

    private var nextId: Int = 0
    private var itemLayers: [Int: ItemLayer] = [:]
    private let itemLayerContainer: SimpleLayer
    private let hierarchyTracker: HierarchyTrackingLayer
    private var previousTimestamp: Double = 0.0
    private var displayLink: SharedDisplayLinkDriver.Link?
    private var previousPhysicsTimestamp: Double = 0.0
    
    private let taskQueue: LiveChatReactionItemTaskQueue

    init(context: AccountContext) {
        self.itemLayerContainer = SimpleLayer()
        self.hierarchyTracker = HierarchyTrackingLayer()
        self.taskQueue = LiveChatReactionItemTaskQueue(engine: context.engine)
        
        super.init(frame: CGRect())
        
        self.layer.addSublayer(self.itemLayerContainer)
        
        self.layer.addSublayer(self.hierarchyTracker)
        self.hierarchyTracker.isInHierarchyUpdated = { [weak self] inHierarchy in
            guard let self else {
                return
            }
            if inHierarchy {
                if self.displayLink == nil {
                    self.displayLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { [weak self] _ in
                        guard let self else {
                            return
                        }
                        self.updatePhysics()
                    })
                }
            } else {
                self.displayLink = nil
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func add(peer: EnginePeer, count: Int) {
        if !self.hierarchyTracker.isInHierarchy {
            return
        }
        let timestamp = CFAbsoluteTimeGetCurrent()
        if timestamp < self.previousTimestamp + 1.0 / 30.0 {
            return
        }
        self.previousTimestamp = timestamp
        Task {
            await self.taskQueue.add(peer: peer, count: count, completion: { [weak self] image in
                Task { @MainActor in
                    guard let self else {
                        return
                    }
                    self.addRenderedItem(image: image)
                }
            })
        }
    }
    
    private func addRenderedItem(image: UIImage) {
        if "".isEmpty {
            return
        }
        
        let id = self.nextId
        self.nextId += 1
        
        let itemLayer = ItemLayer(image: image)
        itemLayer.frame = CGRect(origin: CGPoint(x: -image.size.width - 10.0, y: -image.size.height * 0.5), size: image.size)
        self.itemLayers[id] = itemLayer
        self.itemLayerContainer.addSublayer(itemLayer)
        
        let transition = ComponentTransition(animation: .curve(duration: 2.0, curve: .linear))
        transition.setPosition(layer: itemLayer, position: CGPoint(x: itemLayer.position.x, y: -300.0))
        
        itemLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, delay: 2.0 - 0.18, removeOnCompletion: false, completion: { [weak self] _ in
            guard let self else {
                return
            }
            if let itemLayer = self.itemLayers[id] {
                self.itemLayers.removeValue(forKey: id)
                itemLayer.removeFromSuperlayer()
            }
        })
    }
    
    private func updatePhysics() {
        let timestamp = CACurrentMediaTime()
        let dt = max(1.0 / 120.0, min(1.0 / 30.0, timestamp - self.previousPhysicsTimestamp))
        self.previousPhysicsTimestamp = timestamp
        
        let _ = dt
    }

    func update(size: CGSize, sourcePoint: CGPoint, transition: ComponentTransition) {
        transition.setFrame(layer: self.itemLayerContainer, frame: CGRect(origin: sourcePoint, size: CGSize()))
    }
}
