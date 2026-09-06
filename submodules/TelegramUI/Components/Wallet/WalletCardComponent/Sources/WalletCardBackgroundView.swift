import Foundation
import Display
import Metal
import MetalKit
import MetalEngine
import UIKit

struct WalletCardProjectedQuad {
    var bottomLeft = SIMD4<Float>(-1.0, -1.0, 0.0, 1.0)
    var bottomRight = SIMD4<Float>(1.0, -1.0, 0.0, 1.0)
    var topLeft = SIMD4<Float>(-1.0, 1.0, 0.0, 1.0)
    var topRight = SIMD4<Float>(1.0, 1.0, 0.0, 1.0)
}

private final class WalletCardBundleMarker: NSObject {
}

private var walletCardMetalLibraryValue: MTLLibrary?

private func walletCardMetalLibrary(device: MTLDevice) -> MTLLibrary? {
    if let walletCardMetalLibraryValue {
        return walletCardMetalLibraryValue
    }

    let containingBundle = Bundle(for: WalletCardBundleMarker.self)
    guard
        let bundlePath = containingBundle.path(
            forResource: "WalletCardComponentMetalSourcesBundle",
            ofType: "bundle"
        ),
        let resourceBundle = Bundle(path: bundlePath),
        let library = try? device.makeDefaultLibrary(bundle: resourceBundle)
    else {
        return nil
    }

    walletCardMetalLibraryValue = library
    return library
}

private final class WalletCardMetalLayer: MetalEngineSubjectLayer, MetalEngineSubject {
    private struct VertexUniforms {
        var bottomLeft = SIMD4<Float>(-1.0, -1.0, 0.0, 1.0)
        var bottomRight = SIMD4<Float>(1.0, -1.0, 0.0, 1.0)
        var topLeft = SIMD4<Float>(-1.0, 1.0, 0.0, 1.0)
        var topRight = SIMD4<Float>(1.0, 1.0, 0.0, 1.0)
    }

    private struct FragmentUniforms {
        var time: Float = 0.0
        var highlightTiltX: Float = 0.0
        var highlightTiltY: Float = 0.0
        var cornerRadius: Float = 0.0
        var surfaceTilt = SIMD2<Float>(repeating: 0.0)
        var cardSize = SIMD2<Float>(repeating: 1.0)
    }

    private final class RenderState: RenderToLayerState {
        let pipelineState: MTLRenderPipelineState

        required init?(device: MTLDevice) {
            guard
                let library = walletCardMetalLibrary(device: device),
                let vertexFunction = library.makeFunction(name: "walletCardBackgroundVertex"),
                let fragmentFunction = library.makeFunction(name: "walletCardBackgroundFragment")
            else {
                return nil
            }

            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.label = "Wallet Card Background Pipeline"
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
            pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
            pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
            pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

            guard let pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor) else {
                return nil
            }
            self.pipelineState = pipelineState
        }
    }

    var internalData: MetalEngineSubjectInternalData?

    private var starsTexture: MTLTexture?
    private var noiseTexture: MTLTexture?
    private var vertexUniforms = VertexUniforms()
    private var fragmentUniforms = FragmentUniforms()

    override init() {
        let textureLoader = MTKTextureLoader(device: MetalEngine.shared.device)
        let textureOptions: [MTKTextureLoader.Option: Any] = [
            .SRGB: false,
            .origin: MTKTextureLoader.Origin.topLeft,
        ]
        if let starsImage = WalletCardTextures.starsImage().cgImage {
            self.starsTexture = try? textureLoader.newTexture(cgImage: starsImage, options: textureOptions)
        }
        if let noiseImage = WalletCardTextures.noiseImage().cgImage {
            self.noiseTexture = try? textureLoader.newTexture(cgImage: noiseImage, options: textureOptions)
        }

        super.init()

        self.isOpaque = false
        self.backgroundColor = nil
        self.contentsScale = UIScreenScale
        self.contentsGravity = .resize
        self.masksToBounds = false
    }

    override init(layer: Any) {
        super.init(layer: layer)

        if let layer = layer as? WalletCardMetalLayer {
            self.starsTexture = layer.starsTexture
            self.noiseTexture = layer.noiseTexture
            self.vertexUniforms = layer.vertexUniforms
            self.fragmentUniforms = layer.fragmentUniforms
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(
        time: Double,
        highlightTiltX: Double,
        highlightTiltY: Double,
        surfaceTiltX: Double,
        surfaceTiltY: Double,
        cardSize: CGSize,
        cornerRadius: CGFloat,
        quad: WalletCardProjectedQuad
    ) {
        self.vertexUniforms = VertexUniforms(
            bottomLeft: quad.bottomLeft,
            bottomRight: quad.bottomRight,
            topLeft: quad.topLeft,
            topRight: quad.topRight
        )
        self.fragmentUniforms = FragmentUniforms(
            time: Float(time),
            highlightTiltX: Float(highlightTiltX),
            highlightTiltY: Float(highlightTiltY),
            cornerRadius: Float(cornerRadius),
            surfaceTilt: SIMD2<Float>(Float(surfaceTiltX), Float(surfaceTiltY)),
            cardSize: SIMD2<Float>(Float(max(cardSize.width, 1.0)), Float(max(cardSize.height, 1.0)))
        )
        self.setNeedsUpdate()
    }

    func update(context: MetalEngineSubjectContext) {
        guard
            !self.bounds.isEmpty,
            let starsTexture = self.starsTexture,
            let noiseTexture = self.noiseTexture
        else {
            return
        }

        let displayScale = UIScreenScale
        let drawableSize = CGSize(
            width: self.bounds.width * displayScale,
            height: self.bounds.height * displayScale
        )
        let currentVertexUniforms = self.vertexUniforms
        let currentFragmentUniforms = self.fragmentUniforms

        context.renderToLayer(
            spec: RenderLayerSpec(
                size: RenderSize(
                    width: max(1, Int(ceil(drawableSize.width))),
                    height: max(1, Int(ceil(drawableSize.height)))
                )
            ),
            state: RenderState.self,
            layer: self,
            commands: { encoder, placement in
                let effectiveRect = placement.effectiveRect
                var rect = SIMD4<Float>(
                    Float(effectiveRect.minX),
                    Float(effectiveRect.minY),
                    Float(effectiveRect.width),
                    Float(effectiveRect.height)
                )
                var vertexUniforms = currentVertexUniforms
                var antialiasingParameters = SIMD4<Float>(
                    Float(drawableSize.width),
                    Float(drawableSize.height),
                    currentFragmentUniforms.cardSize.x * Float(displayScale),
                    currentFragmentUniforms.cardSize.y * Float(displayScale)
                )
                var fragmentUniforms = currentFragmentUniforms

                encoder.setVertexBytes(&rect, length: MemoryLayout<SIMD4<Float>>.size, index: 0)
                encoder.setVertexBytes(
                    &vertexUniforms,
                    length: MemoryLayout<VertexUniforms>.size,
                    index: 1
                )
                encoder.setVertexBytes(
                    &antialiasingParameters,
                    length: MemoryLayout<SIMD4<Float>>.size,
                    index: 2
                )
                encoder.setFragmentBytes(
                    &fragmentUniforms,
                    length: MemoryLayout<FragmentUniforms>.size,
                    index: 0
                )
                encoder.setFragmentTexture(starsTexture, index: 0)
                encoder.setFragmentTexture(noiseTexture, index: 1)
                encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            }
        )
    }
}

private final class WalletCardMetalView: UIView {
    override class var layerClass: AnyClass {
        return WalletCardMetalLayer.self
    }

    var metalLayer: WalletCardMetalLayer {
        return self.layer as! WalletCardMetalLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.isUserInteractionEnabled = false
        self.backgroundColor = .clear
        self.clipsToBounds = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class WalletCardBackgroundView: UIView {
    static let projectionPadding: CGFloat = 56.0

    private let fallbackView = UIView()
    private let fallbackBaseGradient = CAGradientLayer()
    private let fallbackRadialGradient = CAGradientLayer()
    private let metalView = WalletCardMetalView()
    private var cardSize = CGSize.zero
    private var cornerRadius: CGFloat = 0.0

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.isUserInteractionEnabled = false
        self.backgroundColor = .clear
        self.clipsToBounds = false
        self.configureFallback()
        self.addSubview(self.metalView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.layoutContent()
    }

    func update(cardSize: CGSize, cornerRadius: CGFloat) {
        self.cardSize = cardSize
        self.cornerRadius = cornerRadius
        self.layoutContent()
        self.renderStaticFrame()
    }

    func updateFallbackTransform(_ transform: CATransform3D) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.fallbackView.layer.transform = transform
        CATransaction.commit()
    }

    func render(
        time: Double,
        highlightTiltX: Double,
        highlightTiltY: Double,
        surfaceTiltX: Double,
        surfaceTiltY: Double,
        quad: WalletCardProjectedQuad
    ) {
        // The fallback is an alternative to Metal, not a second background to
        // composite through the projected quad. Keeping it visible after the
        // engine has allocated its surface makes any transient uncovered area
        // look like a different card.
        self.fallbackView.isHidden = self.metalView.metalLayer.contents != nil
        self.metalView.metalLayer.update(
            time: time,
            highlightTiltX: highlightTiltX,
            highlightTiltY: highlightTiltY,
            surfaceTiltX: surfaceTiltX,
            surfaceTiltY: surfaceTiltY,
            cardSize: self.cardSize,
            cornerRadius: self.cornerRadius,
            quad: quad
        )
    }

    private func layoutContent() {
        let padding = WalletCardBackgroundView.projectionPadding
        self.fallbackView.bounds = CGRect(origin: .zero, size: self.cardSize)
        self.fallbackView.center = CGPoint(
            x: padding + self.cardSize.width * 0.5,
            y: padding + self.cardSize.height * 0.5
        )
        self.fallbackView.layer.cornerRadius = self.cornerRadius
        if #available(iOS 13.0, *) {
            self.fallbackView.layer.cornerCurve = .continuous
        }
        self.fallbackBaseGradient.frame = self.fallbackView.bounds
        self.fallbackRadialGradient.frame = self.fallbackView.bounds

        self.metalView.frame = CGRect(
            origin: .zero,
            size: CGSize(
                width: self.cardSize.width + padding * 2.0,
                height: self.cardSize.height + padding * 2.0
            )
        )
    }

    private func renderStaticFrame() {
        guard self.cardSize.width > 0.0, self.cardSize.height > 0.0 else {
            return
        }

        let padding = WalletCardBackgroundView.projectionPadding
        let paddedWidth = self.cardSize.width + padding * 2.0
        let paddedHeight = self.cardSize.height + padding * 2.0

        func clipPosition(_ point: CGPoint) -> SIMD4<Float> {
            return SIMD4<Float>(
                Float(((point.x + padding) / paddedWidth) * 2.0 - 1.0),
                Float(1.0 - ((point.y + padding) / paddedHeight) * 2.0),
                0.0,
                1.0
            )
        }

        self.render(
            time: 0.0,
            highlightTiltX: 0.0,
            highlightTiltY: 0.0,
            surfaceTiltX: 0.0,
            surfaceTiltY: 0.0,
            quad: WalletCardProjectedQuad(
                bottomLeft: clipPosition(CGPoint(x: 0.0, y: self.cardSize.height)),
                bottomRight: clipPosition(CGPoint(x: self.cardSize.width, y: self.cardSize.height)),
                topLeft: clipPosition(.zero),
                topRight: clipPosition(CGPoint(x: self.cardSize.width, y: 0.0))
            )
        )
    }

    private func configureFallback() {
        self.fallbackView.backgroundColor = UIColor(
            red: 0x3b / 255.0,
            green: 0x86 / 255.0,
            blue: 0xf7 / 255.0,
            alpha: 1.0
        )
        self.fallbackView.isUserInteractionEnabled = false
        self.fallbackView.clipsToBounds = true
        self.fallbackView.layer.allowsEdgeAntialiasing = true
        self.fallbackView.layer.edgeAntialiasingMask = [.layerLeftEdge, .layerRightEdge, .layerTopEdge, .layerBottomEdge]
        self.addSubview(self.fallbackView)

        self.fallbackBaseGradient.startPoint = CGPoint(x: 0.0, y: 0.0)
        self.fallbackBaseGradient.endPoint = CGPoint(x: 1.0, y: 1.0)
        self.fallbackBaseGradient.colors = [
            UIColor(red: 0x2f / 255.0, green: 0x7d / 255.0, blue: 0xf5 / 255.0, alpha: 1.0).cgColor,
            UIColor(red: 0x47 / 255.0, green: 0x8f / 255.0, blue: 0xf9 / 255.0, alpha: 1.0).cgColor,
        ]
        self.fallbackBaseGradient.locations = [0.0, 1.0]
        self.fallbackView.layer.addSublayer(self.fallbackBaseGradient)

        self.fallbackRadialGradient.type = .radial
        self.fallbackRadialGradient.startPoint = CGPoint(x: 0.42, y: 0.48)
        self.fallbackRadialGradient.endPoint = CGPoint(x: 1.0, y: 1.0)
        self.fallbackRadialGradient.colors = [
            UIColor(red: 0.20, green: 0.68, blue: 1.0, alpha: 0.18).cgColor,
            UIColor.clear.cgColor,
        ]
        self.fallbackRadialGradient.locations = [0.0, 1.0]
        self.fallbackView.layer.addSublayer(self.fallbackRadialGradient)
    }
}
