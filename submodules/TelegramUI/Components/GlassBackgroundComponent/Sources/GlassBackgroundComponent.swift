import Foundation
import UIKit
import Display
import ComponentFlow
import ComponentDisplayAdapters

private func generateForegroundImage(size: CGSize, isDark: Bool, fillColor: UIColor) -> UIImage {
    var size = size
    if size == .zero {
        size = CGSize(width: 1.0, height: 1.0)
    }
    
    return generateImage(size, rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        let maxColor = UIColor(white: 1.0, alpha: isDark ? 0.67 : 0.9)
        let minColor = UIColor(white: 1.0, alpha: 0.0)
        
        context.setFillColor(fillColor.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        
        let lineWidth: CGFloat = isDark ? 0.66 : 0.66
        
        context.saveGState()
        
        let darkShadeColor = UIColor(white: isDark ? 1.0 : 0.0, alpha: 0.035)
        let lightShadeColor = UIColor(white: isDark ? 0.0 : 1.0, alpha: 0.035)
        let innerShadowBlur: CGFloat = 24.0
        
        context.resetClip()
        context.addEllipse(in: CGRect(origin: CGPoint(), size: size).insetBy(dx: lineWidth * 0.5, dy: lineWidth * 0.5))
        context.clip()
        context.addRect(CGRect(origin: CGPoint(), size: size).insetBy(dx: -100.0, dy: -100.0))
        context.addEllipse(in: CGRect(origin: CGPoint(), size: size))
        context.setFillColor(UIColor.black.cgColor)
        context.setShadow(offset: CGSize(width: 10.0, height: -10.0), blur: innerShadowBlur, color: darkShadeColor.cgColor)
        context.fillPath(using: .evenOdd)
        
        context.resetClip()
        context.addEllipse(in: CGRect(origin: CGPoint(), size: size).insetBy(dx: lineWidth * 0.5, dy: lineWidth * 0.5))
        context.clip()
        context.addRect(CGRect(origin: CGPoint(), size: size).insetBy(dx: -100.0, dy: -100.0))
        context.addEllipse(in: CGRect(origin: CGPoint(), size: size))
        context.setFillColor(UIColor.black.cgColor)
        context.setShadow(offset: CGSize(width: -10.0, height: 10.0), blur: innerShadowBlur, color: lightShadeColor.cgColor)
        context.fillPath(using: .evenOdd)
        
        context.restoreGState()
        
        context.setLineWidth(lineWidth)
        
        context.addRect(CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width * 0.5, height: size.height)))
        context.clip()
        context.addEllipse(in: CGRect(origin: CGPoint(), size: size).insetBy(dx: lineWidth * 0.5, dy: lineWidth * 0.5))
        context.replacePathWithStrokedPath()
        context.clip()
        
        do {
            var locations: [CGFloat] = [0.0, 0.5, 0.5 + 0.2, 1.0 - 0.1, 1.0]
            let colors: [CGColor] = [maxColor.cgColor, maxColor.cgColor, minColor.cgColor, minColor.cgColor, maxColor.cgColor]
            
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
            
            context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
        }
        
        context.resetClip()
        context.addRect(CGRect(origin: CGPoint(x: size.width - size.width * 0.5, y: 0.0), size: CGSize(width: size.width * 0.5, height: size.height)))
        context.clip()
        context.addEllipse(in: CGRect(origin: CGPoint(), size: size).insetBy(dx: lineWidth * 0.5, dy: lineWidth * 0.5))
        context.replacePathWithStrokedPath()
        context.clip()
        
        do {
            var locations: [CGFloat] = [0.0, 0.1, 0.5 - 0.2, 0.5, 1.0]
            let colors: [CGColor] = [maxColor.cgColor, minColor.cgColor, minColor.cgColor, maxColor.cgColor, maxColor.cgColor]
            
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
            
            context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
        }
    })!.stretchableImage(withLeftCapWidth: Int(size.width * 0.5), topCapHeight: Int(size.height * 0.5))
}

private final class ContentContainer: UIView {
    private let maskContentView: UIView
    
    init(maskContentView: UIView) {
        self.maskContentView = maskContentView
        
        super.init(frame: CGRect())
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let result = super.hitTest(point, with: event) else {
            return nil
        }
        if result === self {
            return nil
        }
        return result
    }
    
    override func didAddSubview(_ subview: UIView) {
        super.didAddSubview(subview)
        
        if let subview = subview as? GlassBackgroundView.ContentView {
            self.maskContentView.addSubview(subview.tintMask)
        }
    }
    
    override func willRemoveSubview(_ subview: UIView) {
        super.willRemoveSubview(subview)
        
        if let subview = subview as? GlassBackgroundView.ContentView {
            subview.tintMask.removeFromSuperview()
        }
    }
}

public class GlassBackgroundView: UIView {
    public protocol ContentView: UIView {
        var tintMask: UIView { get }
    }
    
    open class ContentLayer: SimpleLayer {
        public var targetLayer: CALayer?
        
        override init() {
            super.init()
        }
        
        override init(layer: Any) {
            super.init(layer: layer)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override public var position: CGPoint {
            get {
                return super.position
            } set(value) {
                if let targetLayer = self.targetLayer {
                    targetLayer.position = value
                }
                super.position = value
            }
        }
        
        override public var bounds: CGRect {
            get {
                return super.bounds
            } set(value) {
                if let targetLayer = self.targetLayer {
                    targetLayer.bounds = value
                }
                super.bounds = value
            }
        }
        
        override public var anchorPoint: CGPoint {
            get {
                return super.anchorPoint
            } set(value) {
                if let targetLayer = self.targetLayer {
                    targetLayer.anchorPoint = value
                }
                super.anchorPoint = value
            }
        }
        
        override public var anchorPointZ: CGFloat {
            get {
                return super.anchorPointZ
            } set(value) {
                if let targetLayer = self.targetLayer {
                    targetLayer.anchorPointZ = value
                }
                super.anchorPointZ = value
            }
        }
        
        override public var opacity: Float {
            get {
                return super.opacity
            } set(value) {
                if let targetLayer = self.targetLayer {
                    targetLayer.opacity = value
                }
                super.opacity = value
            }
        }
        
        override public var sublayerTransform: CATransform3D {
            get {
                return super.sublayerTransform
            } set(value) {
                if let targetLayer = self.targetLayer {
                    targetLayer.sublayerTransform = value
                }
                super.sublayerTransform = value
            }
        }
        
        override public var transform: CATransform3D {
            get {
                return super.transform
            } set(value) {
                if let targetLayer = self.targetLayer {
                    targetLayer.transform = value
                }
                super.transform = value
            }
        }
        
        override public func add(_ animation: CAAnimation, forKey key: String?) {
            if let targetLayer = self.targetLayer {
                targetLayer.add(animation, forKey: key)
            }
            
            super.add(animation, forKey: key)
        }
        
        override public func removeAllAnimations() {
            if let targetLayer = self.targetLayer {
                targetLayer.removeAllAnimations()
            }
            
            super.removeAllAnimations()
        }
        
        override public func removeAnimation(forKey: String) {
            if let targetLayer = self.targetLayer {
                targetLayer.removeAnimation(forKey: forKey)
            }
            
            super.removeAnimation(forKey: forKey)
        }
    }
    
    public final class ContentColorView: UIView, ContentView {
        override public static var layerClass: AnyClass {
            return ContentLayer.self
        }
        
        public let tintMask: UIView
        
        override public init(frame: CGRect) {
            self.tintMask = UIView()
            
            super.init(frame: CGRect())
            
            self.tintMask.tintColor = .black
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    public final class ContentImageView: UIImageView, ContentView {
        override public static var layerClass: AnyClass {
            return ContentLayer.self
        }
        
        private let tintImageView: UIImageView
        public var tintMask: UIView {
            return self.tintImageView
        }
        
        override public var image: UIImage? {
            didSet {
                self.tintImageView.image = self.image
            }
        }
        
        override public init(frame: CGRect) {
            self.tintImageView = UIImageView()
            
            super.init(frame: CGRect())
            
            self.tintImageView.tintColor = .black
        }
        
        override public init(image: UIImage?) {
            self.tintImageView = UIImageView()
            
            super.init(image: image)
            
            self.tintImageView.image = image
            self.tintImageView.tintColor = .black
        }
        
        override public init(image: UIImage?, highlightedImage: UIImage?) {
            self.tintImageView = UIImageView()
            
            super.init(image: image, highlightedImage: highlightedImage)
            
            self.tintImageView.image = image
            self.tintImageView.tintColor = .black
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    private struct Params: Equatable {
        let cornerRadius: CGFloat
        let isDark: Bool
        let tintColor: UIColor
        
        init(cornerRadius: CGFloat, isDark: Bool, tintColor: UIColor) {
            self.cornerRadius = cornerRadius
            self.isDark = isDark
            self.tintColor = tintColor
        }
    }
    
    private let backgroundNode: NavigationBackgroundNode?
    private let nativeView: UIVisualEffectView?
    
    private let foregroundView: UIImageView?
    
    public let maskContentView: UIView
    private let contentContainer: ContentContainer
    
    public var contentView: UIView {
        return self.contentContainer
    }
    
    private var params: Params?
    
    public override init(frame: CGRect) {
        if #available(iOS 26.0, *) {
            self.backgroundNode = nil
            let glassEffect = UIGlassEffect(style: .clear)
            glassEffect.isInteractive = false
            let nativeView = UIVisualEffectView(effect: glassEffect)
            self.nativeView = nativeView
            nativeView.overrideUserInterfaceStyle = .light
            nativeView.traitOverrides.userInterfaceStyle = .light
            //self.foregroundView = UIImageView()
            self.foregroundView = nil
        } else {
            self.backgroundNode = NavigationBackgroundNode(color: .black, enableBlur: true, customBlurRadius: 5.0)
            self.nativeView = nil
            self.foregroundView = UIImageView()
        }
        
        self.maskContentView = UIView()
        self.maskContentView.backgroundColor = .white
        if let filter = CALayer.luminanceToAlpha() {
            self.maskContentView.layer.filters = [filter]
        }
        
        self.contentContainer = ContentContainer(maskContentView: self.maskContentView)
        
        super.init(frame: frame)
        
        if let nativeView = self.nativeView {
            self.addSubview(nativeView)
        }
        if let backgroundNode = self.backgroundNode {
            self.addSubview(backgroundNode.view)
        }
        if let foregroundView = self.foregroundView {
            self.addSubview(foregroundView)
            foregroundView.mask = self.maskContentView
        }
        self.addSubview(self.contentContainer)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func update(size: CGSize, cornerRadius: CGFloat, isDark: Bool, tintColor: UIColor, transition: ComponentTransition) {
        if let nativeView = self.nativeView {
            let previousFrame = nativeView.frame
            
            if transition.animation.isImmediate {
                nativeView.layer.cornerRadius = cornerRadius
                nativeView.frame = CGRect(origin: CGPoint(), size: size)
            } else {
                transition.containedViewLayoutTransition.animateView {
                    nativeView.layer.cornerRadius = cornerRadius
                    nativeView.frame = CGRect(origin: CGPoint(), size: size)
                }
                nativeView.layer.animateFrame(from: previousFrame, to: CGRect(origin: CGPoint(), size: size), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
            }
        }
        if let backgroundNode = self.backgroundNode {
            backgroundNode.updateColor(color: .clear, forceKeepBlur: tintColor.alpha != 1.0, transition: transition.containedViewLayoutTransition)
            backgroundNode.update(size: size, cornerRadius: cornerRadius, transition: transition.containedViewLayoutTransition)
            transition.setFrame(view: backgroundNode.view, frame: CGRect(origin: CGPoint(), size: size))
        }
        
        let params = Params(cornerRadius: cornerRadius, isDark: isDark, tintColor: tintColor)
        if self.params != params {
            self.params = params
            
            if let foregroundView = self.foregroundView {
                foregroundView.image = generateForegroundImage(size: CGSize(width: cornerRadius * 2.0, height: cornerRadius * 2.0), isDark: isDark, fillColor: tintColor)
            } else {
                if let nativeView {
                    if #available(iOS 26.0, *) {
                        let glassEffect = UIGlassEffect(style: .regular)
                        glassEffect.tintColor = tintColor//.withMultipliedAlpha(0.1)
                        glassEffect.isInteractive = false
                        
                        nativeView.effect = glassEffect
                    }
                }
            }
        }
        
        transition.setFrame(view: self.maskContentView, frame: CGRect(origin: CGPoint(), size: size))
        if let foregroundView {
            transition.setFrame(view: foregroundView, frame: CGRect(origin: CGPoint(), size: size))
        }
        transition.setFrame(view: self.contentContainer, frame: CGRect(origin: CGPoint(), size: size))
    }
}

public final class VariableBlurView: UIVisualEffectView {
    public let maxBlurRadius: CGFloat
    
    public var gradientMask: UIImage {
        didSet {
            if self.gradientMask !== oldValue {
                self.resetEffect()
            }
        }
    }
    
    public init(gradientMask: UIImage, maxBlurRadius: CGFloat = 20.0) {
        self.gradientMask = gradientMask
        self.maxBlurRadius = maxBlurRadius
        
        super.init(effect: UIBlurEffect(style: .regular))

        self.resetEffect()

        if self.subviews.indices.contains(1) {
            let tintOverlayView = subviews[1]
            tintOverlayView.alpha = 0
        }
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            self.resetEffect()
        }
    }
    
    private func resetEffect() {
        let filterClassStringEncoded = "Q0FGaWx0ZXI="
        let filterClassString: String = {
            if
                let data = Data(base64Encoded: filterClassStringEncoded),
                let string = String(data: data, encoding: .utf8)
            {
                return string
            }

            return ""
        }()
        let filterWithTypeStringEncoded = "ZmlsdGVyV2l0aFR5cGU6"
        let filterWithTypeString: String = {
            if
                let data = Data(base64Encoded: filterWithTypeStringEncoded),
                let string = String(data: data, encoding: .utf8)
            {
                return string
            }

            return ""
        }()

        let filterWithTypeSelector = Selector(filterWithTypeString)

        guard let filterClass = NSClassFromString(filterClassString) as AnyObject as? NSObjectProtocol else {
            return
        }

        guard filterClass.responds(to: filterWithTypeSelector) else {
            return
        }

        let variableBlur = filterClass.perform(filterWithTypeSelector, with: "variableBlur").takeUnretainedValue()

        guard let variableBlur = variableBlur as? NSObject else {
            return
        }
        
        guard let gradientImageRef = self.gradientMask.cgImage else {
            return
        }

        variableBlur.setValue(self.maxBlurRadius, forKey: "inputRadius")
        variableBlur.setValue(gradientImageRef, forKey: "inputMaskImage")
        variableBlur.setValue(true, forKey: "inputNormalizeEdges")
        variableBlur.setValue(UIScreenScale, forKey: "scale")
        
        let backdropLayer = self.subviews.first?.layer
        backdropLayer?.filters = [variableBlur]
    }
}

public final class GlassBackgroundComponent: Component {
    private let size: CGSize
    private let tintColor: UIColor
    
    public init(size: CGSize, tintColor: UIColor) {
        self.size = size
        self.tintColor = tintColor
    }
    
    public static func == (lhs: GlassBackgroundComponent, rhs: GlassBackgroundComponent) -> Bool {
        if lhs.size != rhs.size {
            return false
        }
        if lhs.tintColor != rhs.tintColor {
            return false
        }
        return true
    }
    
    public final class View: GlassBackgroundView {
        func update(component: GlassBackgroundComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.update(size: component.size, cornerRadius: component.size.height / 2.0, isDark: true, tintColor: component.tintColor, transition: transition)
            self.frame = CGRect(origin: .zero, size: component.size)
            
            return component.size
        }
    }
    
    public func makeView() -> View {
        return View()
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
