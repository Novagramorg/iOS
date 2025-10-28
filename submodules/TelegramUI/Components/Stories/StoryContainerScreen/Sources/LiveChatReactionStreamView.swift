import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramCore
import AvatarNode
import AppBundle
import AccountContext
import HierarchyTrackingLayer
import LokiRng

private let gradientColors: [NSArray] = [
    [UIColor(rgb: 0xff516a).cgColor, UIColor(rgb: 0xff885e).cgColor],
    [UIColor(rgb: 0xffa85c).cgColor, UIColor(rgb: 0xffcd6a).cgColor],
    [UIColor(rgb: 0x665fff).cgColor, UIColor(rgb: 0x82b1ff).cgColor],
    [UIColor(rgb: 0x54cb68).cgColor, UIColor(rgb: 0xa0de7e).cgColor],
    [UIColor(rgb: 0x4acccd).cgColor, UIColor(rgb: 0x00fcfd).cgColor],
    [UIColor(rgb: 0x2a9ef1).cgColor, UIColor(rgb: 0x72d5fd).cgColor],
    [UIColor(rgb: 0xd669ed).cgColor, UIColor(rgb: 0xe0a2f3).cgColor],
]

private func avatarViewLettersImage(size: CGSize, peerId: EnginePeer.Id, letters: [String], isStory: Bool) -> UIImage? {
    UIGraphicsBeginImageContextWithOptions(size, false, 2.0)
    let context = UIGraphicsGetCurrentContext()

    context?.beginPath()
    if isStory {
        context?.addEllipse(in: CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height).insetBy(dx: 4.0, dy: 4.0))
    } else {
        context?.addEllipse(in: CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height))
    }
    context?.clip()

    let colorIndex: Int
    if peerId.namespace == .max {
        colorIndex = 0
    } else {
        colorIndex = abs(Int(clamping: peerId.id._internalGetInt64Value()))
    }

    let colorsArray = gradientColors[colorIndex % gradientColors.count]
    var locations: [CGFloat] = [1.0, 0.0]
    let gradient = CGGradient(colorsSpace: deviceColorSpace, colors: colorsArray, locations: &locations)!

    context?.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())

    context?.setBlendMode(.normal)

    let string = letters.count == 0 ? "" : (letters[0] + (letters.count == 1 ? "" : letters[1]))
    let attributedString = NSAttributedString(string: string, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 8.0), NSAttributedString.Key.foregroundColor: UIColor.white])

    let line = CTLineCreateWithAttributedString(attributedString)
    let lineBounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)

    let lineOffset = CGPoint(x: string == "B" ? 1.0 : 0.0, y: 0.0)
    let lineOrigin = CGPoint(x: floor(-lineBounds.origin.x + (size.width - lineBounds.size.width) / 2.0) + lineOffset.x, y: floor(-lineBounds.origin.y + (size.height - lineBounds.size.height) / 2.0))

    context?.translateBy(x: size.width / 2.0, y: size.height / 2.0)
    context?.scaleBy(x: 1.0, y: -1.0)
    context?.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)

    context?.translateBy(x: lineOrigin.x, y: lineOrigin.y)
    if let context = context {
        CTLineDraw(line, context)
    }
    context?.translateBy(x: -lineOrigin.x, y: -lineOrigin.y)
    
    if isStory {
        context?.resetClip()
        
        let lineWidth: CGFloat = 2.0
        context?.setLineWidth(lineWidth)
        context?.addEllipse(in: CGRect(origin: CGPoint(x: size.width * 0.5, y: size.height * 0.5), size: CGSize(width: size.width, height: size.height)).insetBy(dx: lineWidth * 0.5, dy: lineWidth * 0.5))
        context?.replacePathWithStrokedPath()
        context?.clip()
        
        let colors: [CGColor] = [
            UIColor(rgb: 0x34C76F).cgColor,
            UIColor(rgb: 0x3DA1FD).cgColor
        ]
        var locations: [CGFloat] = [0.0, 1.0]
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
        
        context?.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
    }

    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return image
}

private func makePeerBadgeImage(engine: TelegramEngine, peer: EnginePeer, count: Int) async -> UIImage {
    let avatarSize: CGFloat = 16.0
    let avatarInset: CGFloat = 2.0
    let avatarIconSpacing: CGFloat = 2.0
    let iconTextSpacing: CGFloat = 1.0
    let iconSize: CGFloat = 10.0
    let rightInset: CGFloat = 2.0
    
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
        
        if let image = avatarViewLettersImage(size: CGSize(width: avatarSize, height: avatarSize), peerId: peer.id, letters: peer.displayLetters, isStory: false) {
            image.draw(in: CGRect(origin: CGPoint(x: avatarInset, y: avatarInset), size: CGSize(width: avatarSize, height: avatarSize)))
        }
        
        if let image = generateTintedImage(image: UIImage(bundleImageName: "Premium/Stars/ButtonStar"), color: .white) {
            let iconFrame = CGRect(origin: CGPoint(x: avatarInset + avatarSize + avatarIconSpacing, y: floorToScreenPixels((size.height - iconSize) * 0.5) + 1.0), size: CGSize(width: iconSize, height: iconSize))
            image.draw(in: iconFrame)
        }
        
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
            self.allowsEdgeAntialiasing = true
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
        let id = self.nextId
        self.nextId += 1
        
        let itemLayer = ItemLayer(image: image)
        itemLayer.frame = CGRect(origin: CGPoint(x: -image.size.width - 30.0, y: -image.size.height * 0.5), size: image.size).offsetBy(dx: 20.0 * CGFloat(LokiRng.random(withSeed0: UInt(id), seed1: 0, seed2: 0)) - 0.5, dy: 0.0)
        itemLayer.transform = CATransform3DMakeRotation(CGFloat(LokiRng.random(withSeed0: UInt(id), seed1: 1, seed2: 0) - 0.5) * CGFloat.pi * 0.2, 0.0, 0.0, 1.0)
        self.itemLayers[id] = itemLayer
        self.itemLayerContainer.addSublayer(itemLayer)
        
        //itemLayer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -200.0), duration: 2.0, timingFunction: CAMediaTimingFunctionName.linear.rawValue, removeOnCompletion: false, additive: true)
        
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
        
        let cellSize: CGFloat = 16.0
        let forceScale: CGFloat = 60.0
        let falloffDistance: CGFloat = 24.0

        for (id, itemLayer) in self.itemLayers {
            let px = itemLayer.position.x
            let py = itemLayer.position.y

            // Grid coordinates (no abs; keep sign, use floor)
            let gx = Int(floor(px / cellSize))
            let gy = Int(floor(py / cellSize))

            // Fractional position within the cell
            let fx = (px / cellSize) - CGFloat(gx)
            let fy = (py / cellSize) - CGFloat(gy)

            // Bilinear weights for the 4 corners
            let w00 = (1 - fx) * (1 - fy)
            let w10 = (fx)     * (1 - fy)
            let w01 = (1 - fx) * (fy)
            let w11 = (fx)     * (fy)

            func n(_ ix: Int, _ iy: Int) -> CGFloat {
                // random in [0,1), shift to [-0.5, 0.5)
                let r = LokiRng.random(
                    withSeed0: UInt(abs(ix)),
                    seed1: UInt(abs(iy)),
                    seed2: UInt(id)
                )
                return CGFloat(r) - 0.5
            }

            let n00x = n(gx + 0, gy + 0)
            let n10x = n(gx + 1, gy + 0)
            let n01x = n(gx + 0, gy + 1)
            let n11x = n(gx + 1, gy + 1)

            // Bilinear interpolation (smooth, limited cancellation)
            var fxForce = w00*n00x + w10*n10x + w01*n01x + w11*n11x

            // Optional local radial falloff from the nearest lattice center
            // (invert the original: strongest at center)
            let cx = (CGFloat(gx) + 0.5) * cellSize
            let cy = (CGFloat(gy) + 0.5) * cellSize
            let d = hypot(px - cx, py - cy)
            let t = max(0.0, 1.0 - d / falloffDistance)
            let weight = t * t
            fxForce *= weight

            // Apply force directly to position (or integrate velocity if you have it)
            itemLayer.position.x += fxForce * forceScale * dt
            itemLayer.position.y -= dt * 100.0
        }
    }

    func update(size: CGSize, sourcePoint: CGPoint, transition: ComponentTransition) {
        transition.setFrame(layer: self.itemLayerContainer, frame: CGRect(origin: sourcePoint, size: CGSize()))
    }
}
