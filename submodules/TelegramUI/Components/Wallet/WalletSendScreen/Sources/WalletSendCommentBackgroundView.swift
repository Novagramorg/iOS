import UIKit
import Display
import TelegramPresentationData
import GlassBackgroundComponent

final class WalletSendCommentBackgroundView: UIView {
    private struct Parameters: Equatable {
        let size: CGSize
        let scale: CGFloat
        let maxCornerRadius: CGFloat
        let minCornerRadius: CGFloat
        let backgroundColor: UIColor
        let primaryTextColor: UIColor
        let isDark: Bool
    }

    private let imageView = UIImageView()
    private let glassHighlightRecognizer = GlassHighlightGestureRecognizer(target: nil, action: nil)
    private var parameters: Parameters?

    override var isUserInteractionEnabled: Bool {
        didSet {
            self.glassHighlightRecognizer.isEnabled = self.isUserInteractionEnabled
            if !self.isUserInteractionEnabled {
                self.layer.removeAnimation(forKey: "sublayerTransform")
                self.layer.sublayerTransform = CATransform3DIdentity
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.imageView.contentMode = .scaleToFill
        self.addSubview(self.imageView)
        self.addGestureRecognizer(self.glassHighlightRecognizer)
        self.isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        preconditionFailure()
    }

    func update(size: CGSize, maxCornerRadius: CGFloat, minCornerRadius: CGFloat, theme: PresentationTheme) {
        guard size.width > 0.0, size.height > 0.0 else { return }
        self.imageView.frame = CGRect(origin: .zero, size: size)
        let parameters = Parameters(
            size: size,
            scale: self.window?.screen.scale ?? UIScreen.main.scale,
            maxCornerRadius: maxCornerRadius,
            minCornerRadius: minCornerRadius,
            backgroundColor: theme.list.modalPlainBackgroundColor,
            primaryTextColor: theme.list.itemPrimaryTextColor,
            isDark: theme.overallDarkAppearance
        )
        guard self.parameters != parameters else { return }
        if let image = Self.generateImage(parameters: parameters) {
            self.parameters = parameters
            self.imageView.image = image
        }
    }

    private static func generateImage(parameters: Parameters) -> UIImage? {
        let size = parameters.size
        let bounds = CGRect(origin: .zero, size: size)
        let bubble = messageBubbleImage(
            maxCornerRadius: parameters.maxCornerRadius,
            minCornerRadius: parameters.minCornerRadius,
            incoming: false,
            fillColor: .white,
            strokeColor: .clear,
            neighbors: .none,
            shadow: nil,
            wallpaper: .color(0),
            knockout: false,
            mask: true
        )
        guard let mask = Display.generateImage(size, scale: parameters.scale, rotatedContext: { _, context in
            context.clear(bounds)
            UIGraphicsPushContext(context)
            bubble.draw(in: bounds)
            UIGraphicsPopContext()
        }) else { return nil }

        // Intersect translated silhouettes to inset the actual bubble contour,
        // including its tail, without scaling the corners or stretching a stroke.
        func insetMask(by inset: CGFloat) -> UIImage? {
            return Display.generateImage(size, scale: parameters.scale, rotatedContext: { _, context in
                context.clear(bounds)
                UIGraphicsPushContext(context)
                mask.draw(in: bounds)
                for index in 0 ..< 8 {
                    let angle = CGFloat(index) * .pi / 4.0
                    mask.draw(
                        in: bounds.offsetBy(dx: cos(angle) * inset, dy: sin(angle) * inset),
                        blendMode: .destinationIn,
                        alpha: 1.0
                    )
                }
                UIGraphicsPopContext()
            })
        }
        guard let borderMask = insetMask(by: 1.0 / parameters.scale),
              let rimMask = insetMask(by: 0.65),
              let innerMask = insetMask(by: 1.4) else { return nil }

        let glowRadius = min(10.0, size.height * 0.24)
        let padding = ceil(glowRadius * 2.0)
        let outsideSize = CGSize(width: size.width + padding * 2.0, height: size.height + padding * 2.0)
        guard let outsideMask = Display.generateImage(outsideSize, scale: parameters.scale, rotatedContext: { _, context in
            context.setFillColor(UIColor.white.cgColor)
            context.fill(CGRect(origin: .zero, size: outsideSize))
            UIGraphicsPushContext(context)
            mask.draw(in: bounds.offsetBy(dx: padding, dy: padding), blendMode: .destinationOut, alpha: 1.0)
            UIGraphicsPopContext()
        }) else { return nil }

        // Sampled from the reference: the darker band sits above the midpoint,
        // with a longer, softer transition back to the light lower edge.
        let fillLocations: [CGFloat] = [0.0, 0.10, 0.23, 0.40, 0.54, 0.70, 0.82, 1.0]
        let fillShades: [UInt32] = [0xfafafb, 0xf9f9fa, 0xf6f6f7, 0xf4f4f5, 0xf6f6f7, 0xf8f8f9, 0xf9f9fa, 0xfafafb]
        let fillColors = fillShades.map { shade -> CGColor in
            if parameters.isDark {
                let brightness = CGFloat((shade >> 16) & 0xff)
                return parameters.backgroundColor.mixedWith(.white, alpha: 0.035 + (brightness - 244.0) / 255.0).cgColor
            } else {
                return UIColor(rgb: shade).cgColor
            }
        }
        guard let fillGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: fillColors as CFArray, locations: fillLocations) else { return nil }
        // The reference has a stronger contour at the sides and a lighter one
        // along the top and bottom. Blend theme colors before applying the mask.
        let borderLocations: [CGFloat] = [0.0, 0.20, 0.50, 0.80, 1.0]
        let borderAmounts: [CGFloat] = parameters.isDark ? [0.14, 0.23, 0.30, 0.23, 0.14] : [0.10, 0.24, 0.33, 0.24, 0.11]
        let borderColors = borderAmounts.map { amount in
            parameters.backgroundColor.mixedWith(parameters.primaryTextColor, alpha: amount).cgColor
        }
        guard let borderGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: borderColors as CFArray, locations: borderLocations) else { return nil }
        let glowColor = UIColor.white.withAlphaComponent(parameters.isDark ? 0.14 : 0.9)
        let highlightColor = UIColor.white.withAlphaComponent(parameters.isDark ? 0.24 : 0.94)

        return Display.generateImage(size, scale: parameters.scale, rotatedContext: { _, context in
            // messageBubbleImage includes two points of transparent margin.
            // Keep the gradient anchored to the body, independently of its size.
            let fillInset = min(2.0, size.height * 0.1)
            context.drawLinearGradient(
                fillGradient,
                start: CGPoint(x: 0.0, y: fillInset),
                end: CGPoint(x: 0.0, y: size.height - fillInset),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
            UIGraphicsPushContext(context)

            // The blurred outside silhouette lights the edges and fades smoothly
            // toward the darker center, following the shape on every side.
            context.saveGState()
            context.setShadow(offset: .zero, blur: glowRadius, color: glowColor.cgColor)
            outsideMask.draw(in: CGRect(x: -padding, y: -padding, width: outsideSize.width, height: outsideSize.height))
            context.restoreGState()
            mask.draw(in: bounds, blendMode: .destinationIn, alpha: 1.0)

            func drawRing(outer: UIImage, inner: UIImage, fill: () -> Void) {
                context.saveGState()
                context.beginTransparencyLayer(auxiliaryInfo: nil)
                outer.draw(in: bounds)
                inner.draw(in: bounds, blendMode: .destinationOut, alpha: 1.0)
                context.setBlendMode(.sourceIn)
                fill()
                context.setBlendMode(.normal)
                context.endTransparencyLayer()
                context.restoreGState()
            }
            drawRing(outer: mask, inner: borderMask) {
                context.drawLinearGradient(
                    borderGradient,
                    start: CGPoint(x: 0.0, y: fillInset),
                    end: CGPoint(x: 0.0, y: size.height - fillInset),
                    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
                )
            }
            drawRing(outer: rimMask, inner: innerMask) {
                context.setFillColor(highlightColor.cgColor)
                context.fill(bounds)
            }
            UIGraphicsPopContext()
        })
    }
}
