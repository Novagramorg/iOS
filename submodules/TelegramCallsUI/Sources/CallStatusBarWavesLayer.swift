import Foundation
import UIKit
import Metal
import Display
import MetalEngine
import GlassBackgroundComponent

private protocol CallStatusBarWavesPass {
    static var fragmentFunctionName: String { get }
}

private enum ContentPass: CallStatusBarWavesPass {
    static let fragmentFunctionName = "callStatusBarWavesContentFragment"
}

private enum MultiplyPass: CallStatusBarWavesPass {
    static let fragmentFunctionName = "callStatusBarWavesMultiplyFragment"
}

private enum BackdropMaskPass: CallStatusBarWavesPass {
    static let fragmentFunctionName = "callStatusBarWavesMaskFragment"
}

private enum DisplacementPass: CallStatusBarWavesPass {
    static let fragmentFunctionName = "callStatusBarWavesDisplacementFragment"
}

/// The bar's pipelines, made through MetalEngine's pipeline cache: compiled once per app version (in the background,
/// see `prewarmCallStatusBarWaves`) and loaded from the cache's archive afterwards, so the frame the bar first appears
/// in never compiles them.
private final class CallStatusBarWavesPipelines {
    static let shared = CallStatusBarWavesPipelines()

    /// The passes the bar can use on this OS: the multiply, mask and displacement passes are the iOS 26 glass style.
    static var usedFragmentFunctionNames: [String] {
        if #available(iOS 26.0, *) {
            return [
                ContentPass.fragmentFunctionName,
                MultiplyPass.fragmentFunctionName,
                BackdropMaskPass.fragmentFunctionName,
                DisplacementPass.fragmentFunctionName
            ]
        } else {
            return [ContentPass.fragmentFunctionName]
        }
    }

    private let lock = NSLock()
    private var renderPipelineStates: [String: MTLRenderPipelineState] = [:]
    private var crestPipelineStateValue: MTLComputePipelineState?
    private var isPrewarming = false

    func prewarm(device: MTLDevice, qos: DispatchQoS.QoSClass) {
        self.lock.lock()
        let shouldPrewarm = !self.isPrewarming
        self.isPrewarming = true
        self.lock.unlock()

        if shouldPrewarm {
            DispatchQueue.global(qos: qos).async {
                let _ = self.crestPipelineState(device: device)
                for fragmentFunctionName in CallStatusBarWavesPipelines.usedFragmentFunctionNames {
                    let _ = self.renderPipelineState(device: device, fragmentFunctionName: fragmentFunctionName)
                }
            }
        }
    }

    /// Compiles on the calling thread if the pipeline is not ready yet.
    func renderPipelineState(device: MTLDevice, fragmentFunctionName: String) -> MTLRenderPipelineState? {
        self.lock.lock()
        let cached = self.renderPipelineStates[fragmentFunctionName]
        self.lock.unlock()
        if let cached {
            return cached
        }

        guard let library = telegramCallsUIMetalLibrary(device: device) else {
            return nil
        }
        guard let vertexFunction = library.makeFunction(name: "callStatusBarWavesVertex"), let fragmentFunction = library.makeFunction(name: fragmentFunctionName) else {
            return nil
        }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        // Every pixel of the allocation is written, so no blending.
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        guard let pipelineState = MetalEngine.shared.pipelineCache.makeRenderPipelineState(descriptor: descriptor) else {
            return nil
        }

        self.lock.lock()
        self.renderPipelineStates[fragmentFunctionName] = pipelineState
        self.lock.unlock()
        return pipelineState
    }

    /// Compiles on the calling thread if the pipeline is not ready yet.
    func crestPipelineState(device: MTLDevice) -> MTLComputePipelineState? {
        self.lock.lock()
        let cached = self.crestPipelineStateValue
        self.lock.unlock()
        if let cached {
            return cached
        }

        guard let library = telegramCallsUIMetalLibrary(device: device), let function = library.makeFunction(name: "callStatusBarWavesCrestKernel") else {
            return nil
        }
        let descriptor = MTLComputePipelineDescriptor()
        descriptor.computeFunction = function
        guard let pipelineState = MetalEngine.shared.pipelineCache.makeComputePipelineState(descriptor: descriptor) else {
            return nil
        }

        self.lock.lock()
        self.crestPipelineStateValue = pipelineState
        self.lock.unlock()
        return pipelineState
    }
}

/// Makes the call status bar's pipelines in the background: when a call starts, well before the bar can appear, and at
/// a lower priority on the first start after an update, so that they are in the pipeline cache before any call.
public func prewarmCallStatusBarWaves(qos: DispatchQoS.QoSClass = .userInitiated) {
    CallStatusBarWavesPipelines.shared.prewarm(device: MetalEngine.shared.device, qos: qos)
}

/// MetalEngine keeps one render state per type, so each pass is its own specialization.
private final class CallStatusBarWavesRenderState<Pass: CallStatusBarWavesPass>: RenderToLayerState {
    let pipelineState: MTLRenderPipelineState

    init?(device: MTLDevice) {
        guard let pipelineState = CallStatusBarWavesPipelines.shared.renderPipelineState(device: device, fragmentFunctionName: Pass.fragmentFunctionName) else {
            return nil
        }
        self.pipelineState = pipelineState
    }
}

private final class CrestComputeState: ComputeState {
    let pipelineState: MTLComputePipelineState

    init?(device: MTLDevice) {
        guard let pipelineState = CallStatusBarWavesPipelines.shared.crestPipelineState(device: device) else {
            return nil
        }
        self.pipelineState = pipelineState
    }
}

private func colorVector(_ color: UIColor) -> SIMD4<Float> {
    var red: CGFloat = 0.0
    var green: CGFloat = 0.0
    var blue: CGFloat = 0.0
    var alpha: CGFloat = 0.0
    color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    return SIMD4<Float>(Float(red), Float(green), Float(blue), Float(alpha))
}

/// Renders the call status bar background: three morphing waves filled with the call state gradient.
///
/// The look follows the WaveLab prototype. On iOS 26 and later the waves are liquid glass: a slightly blurred backdrop layer
/// refracts the content behind the bar along each crest through a `displacementMap` filter, and the waves'
/// fills, a multiplied state color and a highlight along each crest are drawn over it. Earlier versions draw
/// the state gradient masked by the waves.
///
/// Everything is rendered by MetalEngine: a compute kernel builds the crests from each wave's points, and the layer
/// stack is evaluated per pixel as an affine function of the content behind the bar, which a multiply layer and an
/// additive layer reproduce exactly. The CPU only times the shapes and smooths the audio level.
final class CallStatusBarWavesLayer: SimpleLayer, MetalEngineSubject {
    /// Space below the bar that the layer extends into. The crests rest on the bar's bottom edge. The random points
    /// reach a quarter of the randomness (in amplitudes) below it, the curve through them overshoots them by up to
    /// about a quarter more (10.7 pt at most for the deepest wave, over 200k random shapes), the wave sinks by its
    /// level travel, and its shadow and rim reach a little further.
    static let bottomOverflow: CGFloat = {
        let maxRandomness = CallStatusBarWavesLayer.waveMotions.map(\.maxRandomness).max() ?? 0.0
        let maxOffset = CallStatusBarWavesLayer.waveMotions.map(\.maxOffset).max() ?? 0.0
        let deepestCrest = Constants.amplitude * maxRandomness * 0.25 * 1.3 + Constants.travel * maxOffset
        let shadowReach = CGFloat(Constants.shadowDrop + 3.0 * Constants.shadowBlur)
        return ceil(deepestCrest + shadowReach + CGFloat(Constants.rimWidth) * 0.5)
    }()

    private enum Constants {
        /// Must match `callStatusBarCrestPointCount` in CallStatusBarWaves.metal.
        static let pointsCount: Int = 6
        static let smoothness: CGFloat = 0.5
        static let amplitude: CGFloat = 20.0
        /// How far the lower waves sink at the full audio level.
        static let travel: CGFloat = 16.0
        /// Per-frame smoothing of the audio level at 60 fps.
        static let levelSmoothing: CGFloat = 0.93
        static let maxLevel: CGFloat = 1.5
        static let speedMultiplier: CGFloat = 0.85

        static let shadowStrength: Float = 0.07
        static let shadowBlur: Float = 6.0
        static let shadowDrop: Float = 2.0

        static let rimWidth: Float = 1.0
        static let rimDarkAppearanceScale: Float = 0.45

        /// Width of the refracting band along each crest.
        static let glassBand: Float = 20.0
        /// How far content is pulled in at the very edge of a crest. Above half of `glassBand` the falloff
        /// folds content back on itself near the edge, mirroring it.
        static let glassShift: Float = 10.0
        /// The displacement map encodes offsets up to this many points. Covers the shifts of overlapping crests.
        static let displacementAmount: CGFloat = 32.0
        /// Blur of the content under the waves.
        static let glassBlurRadius: CGFloat = 1.0
        /// The backdrop is blurred anyway, so it is captured below the screen scale.
        static let backdropScale: CGFloat = min(2.0, UIScreenScale)
        /// Horizontal resolution of the displacement map and the backdrop mask, in pixels per point. Both vary
        /// slowly across the bar, so only their vertical resolution (the screen scale) has to resolve the crest.
        static let glassMapHorizontalScale: CGFloat = 1.0

        static let colorTransitionDuration: Double = 0.3
        /// Must match `callStatusBarCrestSampleCount` in CallStatusBarWaves.metal.
        static let crestSampleCount: Int = 128
    }

    private struct WaveStyle {
        /// Opacity of the wave. Also its alpha in the mask of the non-glass style.
        var alpha: Float
        /// Density of the gradient fill under the color.
        var fill: Float
        /// Strength of the state color multiplied over the wave: keeps it saturated without hiding what is behind.
        var saturation: Float
        /// White matte under the color: multiplied over dark content, the color alone would vanish.
        var matte: Float
        /// Opacity of the highlight along the crest.
        var rim: Float
        var refracts: Bool
    }

    private struct WaveMotion {
        var minRandomness: CGFloat
        var maxRandomness: CGFloat
        var minSpeed: CGFloat
        var maxSpeed: CGFloat
        var minOffset: CGFloat
        var maxOffset: CGFloat
    }

    /// Bottom to top.
    private static let waveStyles: [WaveStyle] = [
        WaveStyle(alpha: 0.35, fill: 0.5, saturation: 0.0, matte: 0.0, rim: 0.3, refracts: true),
        WaveStyle(alpha: 0.55, fill: 0.5, saturation: 0.0, matte: 0.0, rim: 0.3, refracts: true),
        WaveStyle(alpha: 1.0, fill: 0.0, saturation: 1.0, matte: 0.3, rim: 0.3, refracts: true)
    ]

    private static let waveMotions: [WaveMotion] = [
        WaveMotion(minRandomness: 1.2, maxRandomness: 1.7, minSpeed: 1.0, maxSpeed: 5.8, minOffset: 0.1, maxOffset: 1.0),
        WaveMotion(minRandomness: 1.2, maxRandomness: 1.5, minSpeed: 1.0, maxSpeed: 4.4, minOffset: 0.1, maxOffset: 0.55),
        WaveMotion(minRandomness: 1.0, maxRandomness: 1.3, minSpeed: 0.9, maxSpeed: 3.2, minOffset: 0.0, maxOffset: 0.0)
    ]

    /// Must match `CallStatusBarWavesUniforms` in CallStatusBarWaves.metal.
    private struct Uniforms {
        var gradientColor0: SIMD4<Float>
        var gradientColor1: SIMD4<Float>
        var waveStyle: (SIMD4<Float>, SIMD4<Float>, SIMD4<Float>)
        var waveRimGlass: (SIMD4<Float>, SIMD4<Float>, SIMD4<Float>)
        var boundsSize: SIMD2<Float>
        var renderSize: SIMD2<Float>
        var edgeInset: Float
        var gradientLength: Float
        var crestSpacing: Float
        var shadowStrength: Float
        var shadowSigma: Float
        var shadowDrop: Float
        var rimScale: Float
        var rimWidth: Float
        var glassBand: Float
        var glassShift: Float
        var glassAmount: Float
        var mode: Int32
    }

    private typealias CrestPoints = (SIMD2<Float>, SIMD2<Float>, SIMD2<Float>, SIMD2<Float>, SIMD2<Float>, SIMD2<Float>)

    /// Must match `CallStatusBarCrestWave` in CallStatusBarWaves.metal.
    private struct CrestWave {
        var fromPoints: CrestPoints
        var toPoints: CrestPoints
        var progress: Float
        var offset: Float

        /// The resting line.
        static var flat: CrestWave {
            let segment = 1.0 / Float(Constants.pointsCount - 1)
            let points: CrestPoints = (SIMD2(0.0, 0.0), SIMD2(segment, 0.0), SIMD2(segment * 2.0, 0.0), SIMD2(segment * 3.0, 0.0), SIMD2(segment * 4.0, 0.0), SIMD2(1.0, 0.0))
            return CrestWave(fromPoints: points, toPoints: points, progress: 0.0, offset: 0.0)
        }
    }

    /// Must match `CallStatusBarCrestParameters` in CallStatusBarWaves.metal.
    private struct CrestParameters {
        var waves: (CrestWave, CrestWave, CrestWave)
        var width: Float
        var restY: Float
        var amplitude: Float
        var smoothness: Float
    }

    /// One morphing wave: when its crest should be where. The crest itself is built on the GPU by
    /// `callStatusBarWavesCrestKernel` from these points.
    private final class Wave {
        let motion: WaveMotion

        /// Normalized: x in 0...1 across the bar, y in units of the wave amplitude.
        private var fromPoints: [CGPoint]
        private var toPoints: [CGPoint]
        private var elapsed: CGFloat = 0.0
        private var duration: CGFloat = 1.0
        private var speedLevel: CGFloat = 0.0

        init(motion: WaveMotion) {
            self.motion = motion
            self.fromPoints = []
            self.toPoints = []

            self.fromPoints = self.generatePoints()
            self.startNextShape()
        }

        func updateSpeedLevel(_ level: CGFloat) {
            self.speedLevel = max(self.speedLevel, level)
        }

        func advance(by deltaTime: CGFloat) {
            self.elapsed += deltaTime
            while self.elapsed >= self.duration {
                self.elapsed -= self.duration
                self.fromPoints = self.toPoints
                self.startNextShape()
            }
        }

        func crestWave(level: CGFloat) -> CrestWave {
            func crestPoints(_ points: [CGPoint]) -> CrestPoints {
                func point(_ index: Int) -> SIMD2<Float> {
                    return SIMD2<Float>(Float(points[index].x), Float(points[index].y))
                }
                return (point(0), point(1), point(2), point(3), point(4), point(5))
            }

            // easeInEaseOut, as the shape layer animation this replaces.
            let progress = bezierPoint(0.42, 0.0, 0.58, 1.0, max(0.0, min(1.0, self.elapsed / self.duration)))
            var offset: CGFloat = 0.0
            if self.motion.minOffset > 0.0 {
                offset = (self.motion.minOffset + (self.motion.maxOffset - self.motion.minOffset) * level) * Constants.travel
            }
            return CrestWave(fromPoints: crestPoints(self.fromPoints), toPoints: crestPoints(self.toPoints), progress: Float(progress), offset: Float(offset))
        }

        private func startNextShape() {
            self.toPoints = self.generatePoints()
            let speed = (self.motion.minSpeed + (self.motion.maxSpeed - self.motion.minSpeed) * self.speedLevel) * Constants.speedMultiplier
            self.duration = 1.0 / max(speed, 0.05)
            self.speedLevel = 0.0
        }

        private func generatePoints() -> [CGPoint] {
            let randomness = self.motion.minRandomness + (self.motion.maxRandomness - self.motion.minRandomness) * self.speedLevel
            let count = Constants.pointsCount
            let segment = 1.0 / CGFloat(count - 1)
            let rangeStart: CGFloat = 1.0 / (1.0 + randomness / 10.0)

            return (0 ..< count).map { index -> CGPoint in
                if index == 0 {
                    return CGPoint(x: 0.0, y: 0.0)
                } else if index == count - 1 {
                    return CGPoint(x: 1.0, y: 0.0)
                }
                let randomPointOffset = (rangeStart + CGFloat.random(in: 0.0 ..< 1.0) * (1.0 - rangeStart)) / 2.0
                let x = segment * CGFloat(index) + segment - segment * randomPointOffset
                let y = (randomness * CGFloat.random(in: 0.0 ..< 1.0) - randomness * 0.5) * randomPointOffset
                return CGPoint(x: x, y: y)
            }
        }
    }

    /// Backdrop of the content behind the bar, warped by a displacement map that MetalEngine renders into a
    /// sibling sublayer: the trick SpaceWarpNode uses for its ripple. The backdrop is slightly blurred and masked
    /// to the waves, so that only the content under them is softened.
    private final class GlassLayers {
        let containerLayer: SimpleLayer
        let backdropLayer: CALayer
        let backdropMaskLayer: MetalEngineSubjectLayer
        let displacementMapLayer: MetalEngineSubjectLayer
        private let backdropLayerDelegate: SimpleLayerDelegate

        init?() {
            guard let displacementMapFilter = CALayer.displacementMap(), let backdropLayer = createBackdropLayer() else {
                return nil
            }
            self.backdropLayer = backdropLayer
            self.backdropLayerDelegate = SimpleLayerDelegate()
            self.containerLayer = SimpleLayer()
            self.backdropMaskLayer = MetalEngineSubjectLayer()
            self.displacementMapLayer = MetalEngineSubjectLayer()

            self.containerLayer.masksToBounds = false
            self.containerLayer.rasterizationScale = UIScreenScale

            backdropLayer.delegate = self.backdropLayerDelegate
            backdropLayer.setValue(Constants.backdropScale as NSNumber, forKey: "scale")
            backdropLayer.rasterizationScale = Constants.backdropScale
            if let blurFilter = CALayer.blur() {
                blurFilter.setValue(Constants.glassBlurRadius as NSNumber, forKey: "inputRadius")
                backdropLayer.filters = [blurFilter]
            }
            self.backdropMaskLayer.magnificationFilter = .linear
            backdropLayer.mask = self.backdropMaskLayer
            self.containerLayer.addSublayer(backdropLayer)

            let displacementMapLayerName = "callStatusBarDisplacementMap"
            self.displacementMapLayer.name = displacementMapLayerName
            self.displacementMapLayer.zPosition = -1.0
            self.displacementMapLayer.magnificationFilter = .linear
            self.containerLayer.addSublayer(self.displacementMapLayer)

            displacementMapFilter.setValue(displacementMapLayerName, forKey: "inputSourceSublayerName")
            displacementMapFilter.setValue((-Constants.displacementAmount) as NSNumber, forKey: "inputAmount")
            displacementMapFilter.setValue(NSValue(cgPoint: CGPoint(x: 0.5, y: 0.5)), forKey: "inputOffset")
            self.containerLayer.filters = [displacementMapFilter]
        }

        func updateFrame(_ frame: CGRect) {
            self.containerLayer.frame = frame
            let bounds = CGRect(origin: CGPoint(), size: frame.size)
            self.backdropLayer.frame = bounds
            self.backdropMaskLayer.frame = bounds
            self.displacementMapLayer.frame = bounds
        }
    }

    private struct ColorTransition {
        var from: (SIMD4<Float>, SIMD4<Float>)
        var startTimestamp: Double
    }

    var internalData: MetalEngineSubjectInternalData?

    /// Nothing animates or renders while the bar is out of the window.
    var isInWindow: Bool = false {
        didSet {
            if self.isInWindow != oldValue {
                self.updateDisplayLink()
                if self.isInWindow {
                    self.setNeedsUpdate()
                }
            }
        }
    }

    /// A still bar without waves, for when animations are disabled to save energy.
    var isFlat: Bool = false {
        didSet {
            if self.isFlat != oldValue {
                self.updateStyle()
                self.updateDisplayLink()
                self.setNeedsUpdate()
            }
        }
    }

    var isDarkAppearance: Bool = false {
        didSet {
            if self.isDarkAppearance != oldValue {
                self.setNeedsUpdate()
            }
        }
    }

    private let contentLayer: MetalEngineSubjectLayer
    private var multiplyLayer: MetalEngineSubjectLayer?
    private var glassLayers: GlassLayers?

    private let waves: [Wave]
    private var audioLevel: CGFloat = 0.0
    private var presentationAudioLevel: CGFloat = 0.0
    private var barHeight: CGFloat = 0.0

    /// Crest samples written by the kernel and read by every pass of the same frame.
    private let crestBuffer: PooledBuffer

    private var colors: (SIMD4<Float>, SIMD4<Float>)
    private var targetColors: (SIMD4<Float>, SIMD4<Float>)
    private var colorTransition: ColorTransition?

    private var displayLink: SharedDisplayLinkDriver.Link?
    private var lastTimestamp: Double?

    init(colors: (UIColor, UIColor)) {
        self.contentLayer = MetalEngineSubjectLayer()
        self.waves = CallStatusBarWavesLayer.waveMotions.map(Wave.init(motion:))
        self.crestBuffer = MetalEngine.shared.pooledBuffer(spec: BufferSpec(length: CallStatusBarWavesLayer.waveMotions.count * Constants.crestSampleCount * MemoryLayout<Float>.size))
        self.colors = (colorVector(colors.0), colorVector(colors.1))
        self.targetColors = self.colors

        super.init()

        prewarmCallStatusBarWaves()

        self.isOpaque = false
        self.addSublayer(self.contentLayer)

        self.updateStyle()
    }

    override init(layer: Any) {
        guard let layer = layer as? CallStatusBarWavesLayer else {
            preconditionFailure()
        }
        self.contentLayer = layer.contentLayer
        self.waves = layer.waves
        self.crestBuffer = layer.crestBuffer
        self.colors = layer.colors
        self.targetColors = layer.targetColors

        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.displayLink?.invalidate()
    }

    /// Lays the waves out for a bar of `barHeight`: their crests rest on its bottom edge. The layer itself is
    /// `bottomOverflow` taller than the bar.
    func update(barHeight: CGFloat) {
        self.barHeight = barHeight

        let bounds = CGRect(origin: CGPoint(), size: self.bounds.size)
        self.contentLayer.frame = bounds
        self.multiplyLayer?.frame = bounds
        self.glassLayers?.updateFrame(bounds)

        self.setNeedsUpdate()
    }

    func updateAudioLevel(_ level: CGFloat) {
        let normalizedLevel = min(1.0, max(level / Constants.maxLevel, 0.0))
        for wave in self.waves {
            wave.updateSpeedLevel(normalizedLevel)
        }
        self.audioLevel = normalizedLevel
    }

    func updateColors(_ colors: (UIColor, UIColor), animated: Bool) {
        let targetColors = (colorVector(colors.0), colorVector(colors.1))
        if targetColors == self.targetColors {
            return
        }
        self.targetColors = targetColors
        if animated && self.isInWindow {
            self.colorTransition = ColorTransition(from: self.colors, startTimestamp: CACurrentMediaTime())
        } else {
            self.colorTransition = nil
            self.colors = targetColors
        }
        self.updateDisplayLink()
        self.setNeedsUpdate()
    }

    /// The liquid glass style needs the refracting backdrop. Without it (before iOS 26, or if the backdrop or
    /// the filter is unavailable) the waves are drawn as the plain masked gradient.
    private var usesLiquidStyle: Bool {
        return self.glassLayers != nil
    }

    private func updateStyle() {
        let bounds = CGRect(origin: CGPoint(), size: self.bounds.size)

        var wantsGlass = false
        if #available(iOS 26.0, *) {
            wantsGlass = !self.isFlat
        }
        if wantsGlass {
            if self.glassLayers == nil, let glassLayers = GlassLayers() {
                glassLayers.updateFrame(bounds)
                self.insertSublayer(glassLayers.containerLayer, at: 0)
                self.glassLayers = glassLayers
            }
        } else if let glassLayers = self.glassLayers {
            // Dropping the layers releases their MetalEngine surfaces.
            self.glassLayers = nil
            glassLayers.containerLayer.removeFromSuperlayer()
        }

        if self.usesLiquidStyle {
            if self.multiplyLayer == nil {
                let multiplyLayer = MetalEngineSubjectLayer()
                multiplyLayer.compositingFilter = "multiplyBlendMode"
                multiplyLayer.frame = bounds
                self.insertSublayer(multiplyLayer, below: self.contentLayer)
                self.multiplyLayer = multiplyLayer
            }
            self.contentLayer.compositingFilter = "plusL"
        } else {
            if let multiplyLayer = self.multiplyLayer {
                self.multiplyLayer = nil
                multiplyLayer.removeFromSuperlayer()
            }
            self.contentLayer.compositingFilter = nil
        }
    }

    private var isAnimatingWaves: Bool {
        return self.isInWindow && !self.isFlat
    }

    private func updateDisplayLink() {
        if self.isInWindow && (!self.isFlat || self.colorTransition != nil) {
            if self.displayLink == nil {
                self.lastTimestamp = nil
                self.displayLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .fps(60), { [weak self] _ in
                    self?.displayLinkTick()
                })
            }
        } else if let displayLink = self.displayLink {
            self.displayLink = nil
            displayLink.invalidate()
        }
    }

    private func displayLinkTick() {
        let timestamp = CACurrentMediaTime()
        let deltaTime: CGFloat
        if let lastTimestamp = self.lastTimestamp {
            deltaTime = CGFloat(max(0.0, min(0.05, timestamp - lastTimestamp)))
        } else {
            deltaTime = 1.0 / 60.0
        }
        self.lastTimestamp = timestamp

        if self.isAnimatingWaves {
            let smoothing = pow(Constants.levelSmoothing, deltaTime * 60.0)
            self.presentationAudioLevel = self.presentationAudioLevel * smoothing + self.audioLevel * (1.0 - smoothing)
            for wave in self.waves {
                wave.advance(by: deltaTime)
            }
        }

        if let colorTransition = self.colorTransition {
            let t = Float(max(0.0, min(1.0, (timestamp - colorTransition.startTimestamp) / Constants.colorTransitionDuration)))
            self.colors = (
                colorTransition.from.0 + (self.targetColors.0 - colorTransition.from.0) * t,
                colorTransition.from.1 + (self.targetColors.1 - colorTransition.from.1) * t
            )
            if t >= 1.0 {
                self.colorTransition = nil
                self.updateDisplayLink()
            }
        }

        self.setNeedsUpdate()
    }

    func update(context: MetalEngineSubjectContext) {
        let size = self.bounds.size
        if !self.isInWindow || size.width <= 0.0 || size.height <= 0.0 || self.barHeight <= 0.0 {
            return
        }

        // Without crests the passes would clear their layers and draw nothing; skip the frame and keep the last one.
        guard CallStatusBarWavesPipelines.shared.crestPipelineState(device: MetalEngine.shared.device) != nil else {
            return
        }
        guard let crestBuffer = self.crestBuffer.get(context: context) else {
            return
        }

        var crestParameters = CrestParameters(
            waves: (CrestWave.flat, CrestWave.flat, CrestWave.flat),
            width: Float(size.width),
            restY: Float(self.barHeight),
            amplitude: Float(Constants.amplitude),
            smoothness: Float(Constants.smoothness)
        )
        if !self.isFlat {
            crestParameters.waves = (
                self.waves[0].crestWave(level: self.presentationAudioLevel),
                self.waves[1].crestWave(level: self.presentationAudioLevel),
                self.waves[2].crestWave(level: self.presentationAudioLevel)
            )
        }
        let crests = context.compute(state: CrestComputeState.self, inputs: crestBuffer.placeholer, commands: { commandBuffer, state, crestBuffer -> MTLBuffer? in
            guard let crestBuffer, let encoder = commandBuffer.makeComputeCommandEncoder() else {
                return nil
            }
            encoder.setComputePipelineState(state.pipelineState)
            var crestParameters = crestParameters
            encoder.setBytes(&crestParameters, length: MemoryLayout<CrestParameters>.stride, index: 0)
            encoder.setBuffer(crestBuffer, offset: 0, index: 1)
            let threadCount = min(Constants.crestSampleCount, state.pipelineState.maxTotalThreadsPerThreadgroup)
            encoder.dispatchThreadgroups(MTLSize(width: 3, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: threadCount, height: 1, depth: 1))
            encoder.endEncoding()
            return crestBuffer
        })

        let mode: Int32
        if self.isFlat {
            mode = 2
        } else if self.usesLiquidStyle {
            mode = 1
        } else {
            mode = 0
        }

        let styles = CallStatusBarWavesLayer.waveStyles
        func styleVector(_ style: WaveStyle) -> SIMD4<Float> {
            return SIMD4<Float>(style.alpha, style.fill, style.saturation, style.matte)
        }
        func rimGlassVector(_ style: WaveStyle) -> SIMD4<Float> {
            return SIMD4<Float>(style.rim, style.refracts ? 1.0 : 0.0, 0.0, 0.0)
        }

        let edgeInset = 2
        let baseUniforms = Uniforms(
            gradientColor0: self.colors.0,
            gradientColor1: self.colors.1,
            waveStyle: (styleVector(styles[0]), styleVector(styles[1]), styleVector(styles[2])),
            waveRimGlass: (rimGlassVector(styles[0]), rimGlassVector(styles[1]), rimGlassVector(styles[2])),
            boundsSize: SIMD2<Float>(Float(size.width), Float(size.height)),
            renderSize: SIMD2<Float>(),
            edgeInset: Float(edgeInset),
            // The gradient runs over twice the bar width, as a CAGradientLayer ending at x = 2 would.
            gradientLength: Float(size.width * 2.0),
            crestSpacing: Float(size.width / CGFloat(Constants.crestSampleCount - 1)),
            shadowStrength: Constants.shadowStrength,
            shadowSigma: Constants.shadowBlur,
            shadowDrop: Constants.shadowDrop,
            rimScale: self.isDarkAppearance ? Constants.rimDarkAppearanceScale : 1.0,
            rimWidth: Constants.rimWidth,
            glassBand: Constants.glassBand,
            glassShift: Constants.glassShift,
            glassAmount: Float(Constants.displacementAmount),
            mode: mode
        )

        func render<Pass: CallStatusBarWavesPass>(_ pass: Pass.Type, layer: MetalEngineSubjectLayer, horizontalScale: CGFloat) {
            let renderSize = RenderSize(width: max(1, Int(ceil(size.width * horizontalScale))), height: max(1, Int(ceil(size.height * UIScreenScale))))
            var uniforms = baseUniforms
            uniforms.renderSize = SIMD2<Float>(Float(renderSize.width), Float(renderSize.height))

            // Every layer here is rendered on every frame, so a surface of its own is the cheapest place for it.
            let spec = RenderLayerSpec(size: renderSize, edgeInset: edgeInset, prefersDedicatedSurface: true)
            context.renderToLayer(spec: spec, state: CallStatusBarWavesRenderState<Pass>.self, layer: layer, inputs: crests, commands: { encoder, placement, crests in
                guard let crests else {
                    return
                }
                let effectiveRect = placement.effectiveRect
                var rect = SIMD4<Float>(Float(effectiveRect.minX), Float(effectiveRect.minY), Float(effectiveRect.width), Float(effectiveRect.height))
                encoder.setVertexBytes(&rect, length: MemoryLayout<SIMD4<Float>>.size, index: 0)

                var uniforms = uniforms
                encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
                encoder.setFragmentBuffer(crests, offset: 0, index: 1)

                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            })
        }

        render(ContentPass.self, layer: self.contentLayer, horizontalScale: UIScreenScale)
        if let multiplyLayer = self.multiplyLayer {
            render(MultiplyPass.self, layer: multiplyLayer, horizontalScale: UIScreenScale)
        }
        if let glassLayers = self.glassLayers {
            render(BackdropMaskPass.self, layer: glassLayers.backdropMaskLayer, horizontalScale: Constants.glassMapHorizontalScale)
            render(DisplacementPass.self, layer: glassLayers.displacementMapLayer, horizontalScale: Constants.glassMapHorizontalScale)
        }
    }
}
