import UIKit
import Metal
import MetalEngine
import Display

struct DiamondStyle: Equatable {
    enum AnimationMode: String, CaseIterable, Sendable {
        case continuous
        case reference
        case entrance
    }
    var animationMode: AnimationMode = .entrance
    var rotationSpeed: Float = 2 * .pi / 18 * 1.70775
    var isRotating: Bool = true
    var sparkles: Bool = true
    var backgroundStars: Bool = true
    var refraction: Float = 0.72
    var brightness: Float = 1
    var zoom: Float = 0.72
    init() {}
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
    var lightBackground = false

    private var renderTargets: RenderTargets?
    private var motion = DiamondMotion()
    private let animationStyle = DiamondStyle()
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
        if self.animationStyle.animationMode == .entrance {
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
            self.motion = layer.motion
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

    @objc private func applicationDidBecomeActive() {
        self.isApplicationActive = true
        self.updateAnimationState()
    }

    @objc private func applicationWillResignActive() {
        self.isApplicationActive = false
        self.updateAnimationState()
    }

    @objc private func reduceMotionChanged() {
        self.reduceMotion = UIAccessibility.isReduceMotionEnabled
        self.motion.step(dt: 0, speed: self.animationStyle.rotationSpeed, reduceMotion: self.reduceMotion, mode: self.animationStyle.animationMode, time: self.elapsed)
        self.updateAnimationState()
    }

    private func updateAnimationState() {
        let isVisible = self.isInHierarchy && self.isApplicationActive
        if isVisible && !self.reduceMotion {
            if self.displayLink == nil {
                self.lastTime = nil
                self.displayLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .fps(60), { [weak self] _ in
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
                self.motion.step(dt: 0, speed: self.animationStyle.rotationSpeed, reduceMotion: self.reduceMotion, mode: self.animationStyle.animationMode, time: self.elapsed)
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
        self.motion.step(dt: dt, speed: self.animationStyle.isRotating ? self.animationStyle.rotationSpeed : 0, reduceMotion: self.reduceMotion, mode: self.animationStyle.animationMode, time: self.elapsed)
    }

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended, let view = gesture.view,
              self.isInHierarchy, self.isApplicationActive, !self.motion.isDragging,
              !self.reduceMotion, !UIAccessibility.isReduceMotionEnabled else { return }
        let point = gesture.location(in: view)
        let horizontalOffset = point.x - view.bounds.midX
        guard abs(horizontalOffset) > 20.0 && abs(horizontalOffset) <= 180.0 else { return }

        self.updateMotion(at: CACurrentMediaTime())
        guard let triggersBurst = self.motion.tap(
            direction: horizontalOffset < 0 ? -1 : 1,
            speed: self.animationStyle.isRotating ? self.animationStyle.rotationSpeed : 0,
            mode: self.animationStyle.animationMode,
            time: self.elapsed
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
        guard self.isInHierarchy && self.isApplicationActive else { return }
        let now = CACurrentMediaTime()
        self.updateMotion(at: now)
        switch gesture.state {
        case .began:
            self.motion.begin(at: now)
            gesture.setTranslation(.zero, in: gesture.view)
        case .changed, .ended:
            let translation = gesture.translation(in: gesture.view)
            if translation != .zero {
                self.motion.drag(dx: Float(translation.x), dy: Float(translation.y), scale: Float(min(self.bounds.width, self.bounds.height)), at: now)
                gesture.setTranslation(.zero, in: gesture.view)
            }
            if gesture.state == .ended {
                self.motion.step(dt: 0, speed: self.animationStyle.rotationSpeed, reduceMotion: self.reduceMotion, mode: self.animationStyle.animationMode, time: self.elapsed)
                self.motion.end(at: now)
                let velocity = gesture.velocity(in: gesture.view)
                if abs(velocity.x) > 600.0 && !self.reduceMotion && !UIAccessibility.isReduceMotionEnabled {
                    self.motion.fling(direction: velocity.x < 0 ? -1 : 1)
                    self.addStarBurst()
                    self.hapticFeedback.impact(.medium)
                }
            }
        case .cancelled, .failed:
            self.motion.end(at: now, cancelled: true)
        default:
            break
        }
        self.motion.step(dt: 0, speed: self.animationStyle.rotationSpeed, reduceMotion: self.reduceMotion, mode: self.animationStyle.animationMode, time: self.elapsed)
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
        guard self.isInHierarchy, self.isApplicationActive, !self.bounds.isEmpty else { return }
        let size = RenderSize(width: Int(ceil(self.bounds.width * UIScreen.main.scale)), height: Int(ceil(self.bounds.height * UIScreen.main.scale)))
        let motion = self.motion
        let time = self.elapsed
        let starBursts = self.starBursts
        let reduceMotion = self.reduceMotion
        let lightBackground = self.lightBackground
        let style = self.animationStyle

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
            renderer.encode(encoder: encoder, size: CGSize(width: CGFloat(size.width), height: CGFloat(size.height)), time: time, starBursts: starBursts, motion: motion, style: style, reduceMotion: reduceMotion, lightBackground: lightBackground)
            encoder.endEncoding()
            return RenderedFrame(texture: targets.color, commandBuffer: commandBuffer)
        })

        context.renderToLayer(spec: RenderLayerSpec(size: size), state: CompositeState.self, layer: self, inputs: frame, commands: { [weak self] encoder, placement, frame in
            guard let frame else { return }
            let effectiveRect = placement.effectiveRect
            var rect = SIMD4<Float>(Float(effectiveRect.minX), Float(effectiveRect.minY), Float(effectiveRect.width), Float(effectiveRect.height))
            encoder.setVertexBytes(&rect, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)
            encoder.setFragmentTexture(frame.texture, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            self?.scheduleReady(after: frame.commandBuffer)
        })
    }
}
