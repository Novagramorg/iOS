import UIKit
import Metal
import MetalEngine
import Display

struct DiamondStyle: Equatable {
    enum Appearance: UInt32, CaseIterable, Sendable {
        case blue = 0
        case white = 1
        case cool = 2
    }
    var appearance: Appearance = .blue
    enum AnimationMode: String, CaseIterable, Sendable {
        case continuous
        case reference
        case entrance
    }
    var animationMode: AnimationMode = .entrance
    var rotationSpeed: Float = 2 * .pi / 18 * 1.70775
    var isRotating: Bool = true
    var sparkles: Bool = true
    var mainSparkleOnRotation: Bool = false
    var backgroundStars: Bool = true
    var widthCompensation: Bool = true
    var refraction: Float = 0.72
    var brightness: Float = 1
    var zoom: Float = 0.72
    var whiten: Float = 0
    var swayScale: Float = 0
    var tilt: Float = 0
    var releaseDecay: Float = 0
    var releaseTilt: Float = 0
    var dragGrow: Float = 1
    var growShift: Float = 0
    var growDamping: Float = 0.42
    var widthPoints: Float = 0
    var starOpacity: Float = 1
    var starZoom: Float = 1
    var starEmission: Float = 1
    var burstSize: Float = 1
    var steadyStars: Bool = true
    init() {}
}

struct DiamondPose {
    let yaw: Float
    let pitch: Float
    let grow: Float
    let shift: Float
}

final class InteractiveDiamondLayer: MetalEngineSubjectLayer, MetalEngineSubject {
    private final class CompositeState: RenderToLayerState {
        let pipelineState: MTLRenderPipelineState

        required init?(device: MTLDevice) {
            guard let library = metalLibrary(device: device),
                  let vertex = library.makeFunction(name: "gramDiamondCompositeVertex"),
                  let fragment = library.makeFunction(name: "gramDiamondCompositeFragment") else {
                return nil
            }
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertex
            descriptor.fragmentFunction = fragment
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            descriptor.colorAttachments[0].isBlendingEnabled = true
            descriptor.colorAttachments[0].sourceRGBBlendFactor = .one
            descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
            descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            guard let pipelineState = try? device.makeRenderPipelineState(descriptor: descriptor) else {
                return nil
            }
            self.pipelineState = pipelineState
        }
    }

    private final class RenderTargets {
        let size: RenderSize
        let color: MTLTexture
        let multisampleColor: MTLTexture?
        let depth: MTLTexture

        init?(device: MTLDevice, size: RenderSize, sampleCount: Int) {
            self.size = size
            let colorDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: size.width, height: size.height, mipmapped: false)
            colorDescriptor.storageMode = .private
            colorDescriptor.usage = [.renderTarget, .shaderRead]
            guard let color = device.makeTexture(descriptor: colorDescriptor) else {
                return nil
            }
            self.color = color

            if sampleCount > 1 {
                colorDescriptor.textureType = .type2DMultisample
                colorDescriptor.sampleCount = sampleCount
                colorDescriptor.usage = .renderTarget
                guard let multisampleColor = device.makeTexture(descriptor: colorDescriptor) else {
                    return nil
                }
                self.multisampleColor = multisampleColor
            } else {
                self.multisampleColor = nil
            }

            let depthDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: size.width, height: size.height, mipmapped: false)
            depthDescriptor.storageMode = .private
            depthDescriptor.usage = .renderTarget
            depthDescriptor.sampleCount = sampleCount
            if sampleCount > 1 {
                depthDescriptor.textureType = .type2DMultisample
            }
            guard let depth = device.makeTexture(descriptor: depthDescriptor) else {
                return nil
            }
            self.depth = depth
        }
    }

    private struct RenderedFrame {
        let texture: MTLTexture
        let commandBuffer: MTLCommandBuffer
    }

    var internalData: MetalEngineSubjectInternalData?
    var onReady: (() -> Void)?
    var onHold: ((Bool) -> Void)?
    var onPoseUpdated: ((DiamondPose) -> Void)?
    var lightBackground = false
    var interactionScale: Float = 1
    var refractionSource: InteractiveDiamondComponent.RefractionSource?
    var refractionStrength: Float = 0
    var usesHighFrameRate = false {
        didSet {
            guard self.usesHighFrameRate != oldValue else { return }
            self.displayLink?.invalidate()
            self.displayLink = nil
            self.updateAnimationState()
        }
    }
    
    var renderSize: CGSize? {
        didSet {
            if self.renderSize != oldValue { self.setNeedsUpdate() }
        }
    }
    
    var isRenderingEnabled = true {
        didSet {
            if self.isRenderingEnabled != oldValue {
                self.updateAnimationState()
            }
        }
    }
    private(set) var diamondStyle = DiamondStyle()

    var pose: DiamondPose {
        return DiamondPose(yaw: self.motion.yaw, pitch: self.motion.pitch,
            grow: self.grow * self.interactionScale, shift: self.diamondStyle.growShift * (self.grow * self.interactionScale - 1))
    }

    private var renderTargets: RenderTargets?
    private var motion = DiamondMotion()
    private var grow: Float = 1
    private var growVelocity: Float = 0
    private let hapticFeedback: HapticFeedback
    private var starBursts: [DiamondStarBurst] = []
    private var nextBurstSeed: UInt32 = 1
    private var elapsed: Float = 0
    private var lastTime: CFTimeInterval?
    private var displayLink: SharedDisplayLinkDriver.Link?
    private var isApplicationActive = UIApplication.shared.applicationState == .active
    private var reduceMotion = false
    private var didSetReady = false
    private var isReadyScheduled = false

    override init() {
        self.hapticFeedback = HapticFeedback()
        super.init()

        self.isOpaque = false
        if self.diamondStyle.animationMode == .entrance {
            self.starBursts.append(DiamondStarBurst(startTime: 0, seed: 0))
        }
        self.didEnterHierarchy = { [weak self] in
            self?.updateAnimationState()
        }
        self.didExitHierarchy = { [weak self] in
            self?.updateAnimationState()
        }
        NotificationCenter.default.addObserver(self, selector: #selector(self.applicationDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.applicationWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        //NotificationCenter.default.addObserver(self, selector: #selector(self.reduceMotionChanged), name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
    }

    override init(layer: Any) {
        self.hapticFeedback = HapticFeedback()
        super.init(layer: layer)
        if let layer = layer as? InteractiveDiamondLayer {
            self.diamondStyle = layer.diamondStyle
            self.motion = layer.motion
            self.grow = layer.grow
            self.growVelocity = layer.growVelocity
            self.interactionScale = layer.interactionScale
            self.refractionSource = layer.refractionSource
            self.refractionStrength = layer.refractionStrength
            self.usesHighFrameRate = layer.usesHighFrameRate
            self.renderSize = layer.renderSize
            self.isRenderingEnabled = layer.isRenderingEnabled
            self.starBursts = layer.starBursts
            self.nextBurstSeed = layer.nextBurstSeed
            self.elapsed = layer.elapsed
            self.lightBackground = layer.lightBackground
            self.reduceMotion = layer.reduceMotion
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.displayLink?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    func update(style: DiamondStyle) {
        guard self.diamondStyle != style else { return }
        if self.lastTime != nil {
            self.updateMotion(at: CACurrentMediaTime())
        }
        let previous = self.diamondStyle
        self.diamondStyle = style
        if previous.animationMode != style.animationMode {
            self.resetAnimation()
        } else {
            self.updateMotionStyle()
            if style.animationMode == .reference && previous.appearance != style.appearance {
                self.motion.changeReferenceAppearance(from: previous.appearance, to: style.appearance, time: self.elapsed)
            }
            self.onPoseUpdated?(self.pose)
            self.setNeedsUpdate()
        }
    }

    private func updateMotionStyle() {
        self.motion.mainSparkleOnRotation = self.diamondStyle.mainSparkleOnRotation
        self.motion.swayScale = self.diamondStyle.swayScale
        self.motion.tilt = self.diamondStyle.tilt
        self.motion.releaseDecay = self.diamondStyle.releaseDecay
        self.motion.releaseTilt = self.diamondStyle.releaseTilt
    }

    func resetAnimation() {
        let wasDragging = self.motion.isDragging
        self.motion = DiamondMotion()
        self.updateMotionStyle()
        self.grow = 1
        self.growVelocity = 0
        self.elapsed = 0
        self.lastTime = nil
        self.starBursts = self.diamondStyle.animationMode == .entrance ? [DiamondStarBurst(startTime: 0, seed: 0)] : []
        self.nextBurstSeed = 1
        if wasDragging { self.onHold?(false) }
        self.onPoseUpdated?(self.pose)
        self.setNeedsUpdate()
    }

    func spin(_ velocity: Float, decay: Float = 0.7) {
        guard self.isInHierarchy, self.isApplicationActive, self.isRenderingEnabled,
              !self.reduceMotion, !UIAccessibility.isReduceMotionEnabled else { return }
        self.updateMotion(at: CACurrentMediaTime())
        self.motion.spin(velocity, decay: decay)
        self.setNeedsUpdate()
    }

    func emitStarBurst() {
        guard self.isInHierarchy, self.isApplicationActive, self.isRenderingEnabled,
              !self.reduceMotion, !UIAccessibility.isReduceMotionEnabled else { return }
        self.updateMotion(at: CACurrentMediaTime())
        self.addStarBurst()
        self.setNeedsUpdate()
    }

    @objc private func applicationDidBecomeActive() {
        self.isApplicationActive = true
        self.updateAnimationState()
    }

    @objc private func applicationWillResignActive() {
        self.isApplicationActive = false
        self.updateAnimationState()
    }

    @objc private func reduceMotionChanged() {
        self.setReduceMotion(UIAccessibility.isReduceMotionEnabled)
    }

    func setReduceMotion(_ enabled: Bool) {
        guard self.reduceMotion != enabled else { return }
        self.reduceMotion = enabled
        self.motion.step(dt: 0, speed: self.diamondStyle.rotationSpeed, reduceMotion: self.reduceMotion, mode: self.diamondStyle.animationMode, time: self.elapsed, appearance: self.diamondStyle.appearance)
        self.updateAnimationState()
    }

    private func updateAnimationState() {
        let isVisible = self.isInHierarchy && self.isApplicationActive && self.isRenderingEnabled
        if isVisible && !self.reduceMotion {
            if self.displayLink == nil {
                self.displayLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: self.usesHighFrameRate ? .max : .fps(60), { [weak self] _ in
                    guard let self else { return }
                    self.updateMotion(at: CACurrentMediaTime())
                    self.setNeedsUpdate()
                })
            }
        } else {
            self.displayLink?.invalidate()
            self.displayLink = nil
            self.lastTime = nil
            if !isVisible && self.motion.isDragging {
                self.motion.end(at: CACurrentMediaTime(), cancelled: true)
                self.motion.step(dt: 0, speed: self.diamondStyle.rotationSpeed, reduceMotion: self.reduceMotion, mode: self.diamondStyle.animationMode, time: self.elapsed, appearance: self.diamondStyle.appearance)
                self.onHold?(false)
                self.onPoseUpdated?(self.pose)
            }
        }
        if isVisible {
            self.setNeedsUpdate()
        }
    }

    private func updateMotion(at time: CFTimeInterval) {
        let dt = Float(self.lastTime.map { min(max(0, time - $0), 0.05) } ?? 0)
        self.lastTime = time
        if !self.reduceMotion {
            self.elapsed += dt
        }
        self.starBursts.removeAll(where: { self.elapsed - $0.startTime >= DiamondStarBurst.lifetime })
        self.motion.step(dt: dt, speed: self.diamondStyle.isRotating ? self.diamondStyle.rotationSpeed : 0, reduceMotion: self.reduceMotion, mode: self.diamondStyle.animationMode, time: self.elapsed, appearance: self.diamondStyle.appearance)
        if self.reduceMotion {
            self.grow = 1
            self.growVelocity = 0
        } else if self.diamondStyle.dragGrow != 1 || self.grow != 1 || self.growVelocity != 0 {
            let target: Float = self.motion.isDragging ? self.diamondStyle.dragGrow : 1
            var remaining = dt
            while remaining > 0 {
                let step = min(remaining, 1 / Float(240))
                self.growVelocity += ((target - self.grow) * 196 - 2 * self.diamondStyle.growDamping * 14 * self.growVelocity) * step
                self.grow += self.growVelocity * step
                remaining = max(0, remaining - step)
            }
            if abs(self.grow - target) < 0.0001 && abs(self.growVelocity) < 0.0001 {
                self.grow = target
                self.growVelocity = 0
            }
        }
        self.onPoseUpdated?(self.pose)
    }

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended, let view = gesture.view,
              self.isInHierarchy, self.isApplicationActive, self.isRenderingEnabled, !self.motion.isDragging,
              !self.reduceMotion, !UIAccessibility.isReduceMotionEnabled else { return }
        let point = gesture.location(in: view)
        let horizontalOffset = point.x - view.bounds.midX
        guard abs(horizontalOffset) > 20.0 && abs(horizontalOffset) <= 180.0 else { return }

        self.updateMotion(at: CACurrentMediaTime())
        guard let triggersBurst = self.motion.tap(
            direction: horizontalOffset < 0 ? -1 : 1,
            speed: self.diamondStyle.isRotating ? self.diamondStyle.rotationSpeed : 0,
            mode: self.diamondStyle.animationMode,
            time: self.elapsed,
            appearance: self.diamondStyle.appearance
        ) else { return }
        if triggersBurst {
            self.addStarBurst()
            self.hapticFeedback.impact(.medium)
        } else {
            self.hapticFeedback.tap()
        }
        self.setNeedsUpdate()
    }

    private func addStarBurst() {
        if self.starBursts.count >= 3 {
            self.starBursts.removeFirst()
        }
        self.starBursts.append(DiamondStarBurst(startTime: self.elapsed, seed: self.nextBurstSeed))
        self.nextBurstSeed = (self.nextBurstSeed + 1) % 65536
    }

    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard self.isInHierarchy && self.isApplicationActive && self.isRenderingEnabled else { return }
        self.updateDrag(
            state: gesture.state,
            translation: gesture.translation(in: gesture.view),
            velocity: gesture.velocity(in: gesture.view),
            scale: min(self.bounds.width, self.bounds.height)
        )
        switch gesture.state {
        case .began, .changed, .ended:
            gesture.setTranslation(.zero, in: gesture.view)
        default:
            break
        }
    }

    func updateDrag(state: UIGestureRecognizer.State, translation: CGPoint = .zero, velocity: CGPoint = .zero, scale: CGFloat = 100.0) {
        if state != .cancelled && state != .failed {
            guard self.isInHierarchy && self.isApplicationActive && self.isRenderingEnabled else { return }
        }
        let now = CACurrentMediaTime()
        self.updateMotion(at: now)
        switch state {
        case .began:
            self.motion.begin(at: now)
            self.onHold?(true)
        case .changed, .ended:
            guard self.motion.isDragging else { break }
            if translation != .zero {
                self.motion.drag(dx: Float(translation.x), dy: Float(translation.y), scale: Float(scale), at: now)
            }
            if state == .ended {
                self.motion.step(dt: 0, speed: self.diamondStyle.rotationSpeed, reduceMotion: self.reduceMotion, mode: self.diamondStyle.animationMode, time: self.elapsed, appearance: self.diamondStyle.appearance)
                self.motion.end(at: now)
                if abs(velocity.x) > 600.0 && !self.reduceMotion && !UIAccessibility.isReduceMotionEnabled {
                    self.motion.fling(direction: velocity.x < 0 ? -1 : 1)
                    self.addStarBurst()
                    self.hapticFeedback.impact(.medium)
                }
                self.onHold?(false)
            }
        case .cancelled, .failed:
            if self.motion.isDragging {
                self.motion.end(at: now, cancelled: true)
                self.onHold?(false)
            }
        default:
            break
        }
        self.motion.step(dt: 0, speed: self.diamondStyle.rotationSpeed, reduceMotion: self.reduceMotion, mode: self.diamondStyle.animationMode, time: self.elapsed, appearance: self.diamondStyle.appearance)
        self.onPoseUpdated?(self.pose)
        self.setNeedsUpdate()
    }

    private func scheduleReady(after commandBuffer: MTLCommandBuffer) {
        guard !self.didSetReady && !self.isReadyScheduled else { return }
        self.isReadyScheduled = true
        commandBuffer.addCompletedHandler { [weak self] commandBuffer in
            let completed = commandBuffer.status == .completed
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isReadyScheduled = false
                if completed && !self.didSetReady {
                    self.didSetReady = true
                    self.onReady?()
                }
            }
        }
    }

    func update(context: MetalEngineSubjectContext) {
        let canvasSize = self.renderSize ?? self.bounds.size
        guard self.isInHierarchy, self.isApplicationActive, self.isRenderingEnabled, canvasSize.width > 0.0, canvasSize.height > 0.0 else { return }
        let pixelsPerPoint = UIScreen.main.scale
        let size = RenderSize(width: Int(ceil(canvasSize.width * pixelsPerPoint)), height: Int(ceil(canvasSize.height * pixelsPerPoint)))
        let motion = self.motion
        let time = self.elapsed
        let starBursts = self.starBursts
        let reduceMotion = self.reduceMotion
        let lightBackground = self.lightBackground
        let style = self.diamondStyle
        let grow = self.grow * self.interactionScale
        let refractionSource = self.refractionSource
        let refractionStrength = self.refractionStrength

        let frame = context.compute(state: DiamondRenderer.self, commands: { [weak self] commandBuffer, renderer -> RenderedFrame? in
            guard let self else { return nil }
            if self.renderTargets?.size != size {
                self.renderTargets = RenderTargets(device: renderer.device, size: size, sampleCount: renderer.sampleCount)
            }
            guard let targets = self.renderTargets else { return nil }

            let pass = MTLRenderPassDescriptor()
            pass.colorAttachments[0].texture = targets.multisampleColor ?? targets.color
            pass.colorAttachments[0].loadAction = .clear
            pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
            if targets.multisampleColor != nil {
                pass.colorAttachments[0].resolveTexture = targets.color
                pass.colorAttachments[0].storeAction = .multisampleResolve
            } else {
                pass.colorAttachments[0].storeAction = .store
            }
            pass.depthAttachment.texture = targets.depth
            pass.depthAttachment.loadAction = .clear
            pass.depthAttachment.clearDepth = 1
            pass.depthAttachment.storeAction = .dontCare
            guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return nil }
            renderer.encode(encoder: encoder, size: CGSize(width: CGFloat(size.width), height: CGFloat(size.height)), time: time, starBursts: starBursts, motion: motion, style: style, grow: grow, pixelsPerPoint: Float(pixelsPerPoint), reduceMotion: reduceMotion, lightBackground: lightBackground, refractionSource: refractionSource, refractionStrength: refractionStrength)
            encoder.endEncoding()
            return RenderedFrame(texture: targets.color, commandBuffer: commandBuffer)
        })

        // Transparent atlas padding keeps ancestor scaling from sampling neighboring allocations.
        let edgeInset = 2
        context.renderToLayer(spec: RenderLayerSpec(size: size, edgeInset: edgeInset), state: CompositeState.self, layer: self, inputs: frame, commands: { [weak self] encoder, placement, frame in
            guard let frame else { return }
            if let self, self.renderSize != nil, self.bounds.size != canvasSize {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                self.bounds = CGRect(origin: .zero, size: canvasSize)
                CATransaction.commit()
            }
            let effectiveRect = placement.effectiveRect
            // MetalEngine clears the full allocation and exposes only this inner rect to the layer.
            let contentRect = effectiveRect.insetBy(
                dx: effectiveRect.width * CGFloat(edgeInset) / CGFloat(size.width + edgeInset * 2),
                dy: effectiveRect.height * CGFloat(edgeInset) / CGFloat(size.height + edgeInset * 2)
            )
            var rect = SIMD4<Float>(Float(contentRect.minX), Float(contentRect.minY), Float(contentRect.width), Float(contentRect.height))
            encoder.setVertexBytes(&rect, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)
            encoder.setFragmentTexture(frame.texture, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            self?.scheduleReady(after: frame.commandBuffer)
        })
    }
}
