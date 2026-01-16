import Foundation
import UIKit
import Display
import ComponentFlow
import ComponentDisplayAdapters
import GlassBackgroundComponent

public class EdgeEffectView: UIView {
    public enum Edge {
        case top
        case bottom
    }

    private let contentView: UIView
    private let contentMaskView: UIImageView
    private var blurView: VariableBlurView?
    
    public override init(frame: CGRect) {
        self.contentView = UIView()
        self.contentMaskView = UIImageView()
        self.contentView.mask = self.contentMaskView
        
        super.init(frame: frame)
        
        self.addSubview(self.contentView)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func update(content: UIColor, blur: Bool = false, alpha: CGFloat = 0.75, rect: CGRect, edge: Edge, edgeSize: CGFloat, transition: ComponentTransition) {
        #if DEBUG && false
        let content: UIColor = .blue
        //let blur: Bool = !"".isEmpty
        #endif
        
        transition.setBackgroundColor(view: self.contentView, color: content)
        transition.setAlpha(view: self.contentView, alpha: alpha)
        
        let bounds = CGRect(origin: CGPoint(), size: rect.size)
        transition.setFrame(view: self.contentView, frame: bounds)
        transition.setFrame(view: self.contentMaskView, frame: bounds)
        
        if self.contentMaskView.image?.size.height != edgeSize {
            if edgeSize > 0.0 {
                self.contentMaskView.image = EdgeEffectView.generateEdgeGradient(baseHeight: edgeSize, isInverted: edge == .bottom)
            } else {
                self.contentMaskView.image = nil
            }
        }
        
        if blur {
            let blurHeight: CGFloat = max(edgeSize, bounds.height - 14.0)
            let blurFrame = CGRect(origin: CGPoint(x: 0.0, y: edge == .bottom ? (bounds.height - blurHeight) : 0.0), size: CGSize(width: bounds.width, height: blurHeight))
            
            let blurView: VariableBlurView
            if let current = self.blurView {
                blurView = current
            } else {
                blurView = VariableBlurView(maxBlurRadius: 1.0)
                self.insertSubview(blurView, at: 0)
                self.blurView = blurView
            }
            
            blurView.update(
                size: blurFrame.size,
                constantHeight: max(1.0, edgeSize - 4.0),
                isInverted: edge == .bottom,
                gradient: EdgeEffectView.generateEdgeGradientData(baseHeight: max(1.0, edgeSize - 4.0)),
                transition: transition.containedViewLayoutTransition
            )
            transition.setFrame(view: blurView, frame: blurFrame)
            blurView.transform = self.contentMaskView.transform
        } else if let blurView = self.blurView {
            self.blurView = nil
            blurView.removeFromSuperview()
        }
    }
    
    public static func generateEdgeGradientData(baseHeight: CGFloat) -> VariableBlurView.Gradient {
        let gradientColors: [CGFloat] = [
            0.8470588235294118,
            0.8431372549019608,
            0.8392156862745098,
            0.8352941176470589,
            0.8313725490196078,
            0.8274509803921568,
            0.8235294117647058,
            0.8196078431372549,
            0.8156862745098039,
            0.8117647058823529,
            0.807843137254902,
            0.803921568627451,
            0.8,
            0.7960784313725491,
            0.792156862745098,
            0.788235294117647,
            0.7843137254901961,
            0.7803921568627451,
            0.7764705882352941,
            0.7725490196078432,
            0.7686274509803921,
            0.7647058823529411,
            0.7607843137254902,
            0.7568627450980392,
            0.7529411764705882,
            0.7490196078431373,
            0.7450980392156863,
            0.7411764705882353,
            0.7372549019607844,
            0.7333333333333334,
            0.7294117647058824,
            0.7254901960784313,
            0.7215686274509804,
            0.7176470588235294,
            0.7137254901960784,
            0.7098039215686274,
            0.7019607843137254,
            0.6941176470588235,
            0.6862745098039216,
            0.6784313725490196,
            0.6705882352941177,
            0.6588235294117647,
            0.6509803921568628,
            0.6431372549019607,
            0.6313725490196078,
            0.6235294117647059,
            0.615686274509804,
            0.603921568627451,
            0.596078431372549,
            0.5882352941176471,
            0.5764705882352941,
            0.5647058823529412,
            0.5529411764705883,
            0.5411764705882354,
            0.5294117647058824,
            0.5176470588235293,
            0.5058823529411764,
            0.49411764705882355,
            0.4862745098039216,
            0.4745098039215686,
            0.4627450980392157,
            0.4549019607843138,
            0.44313725490196076,
            0.43137254901960786,
            0.41960784313725485,
            0.4117647058823529,
            0.4,
            0.388235294117647,
            0.3764705882352941,
            0.3647058823529412,
            0.3529411764705882,
            0.3411764705882353,
            0.3294117647058824,
            0.3176470588235294,
            0.3058823529411765,
            0.2941176470588235,
            0.2823529411764706,
            0.2705882352941177,
            0.2588235294117647,
            0.2431372549019608,
            0.2313725490196078,
            0.21568627450980393,
            0.19999999999999996,
            0.18039215686274512,
            0.16078431372549018,
            0.14117647058823535,
            0.11764705882352944,
            0.09019607843137256,
            0.04705882352941182,
            0.0,
        ]
        
        let gradientColorNorm = gradientColors.max()!

        let gradientLocations: [CGFloat] = [
            0.0,
            0.020905923344947737,
            0.059233449477351915,
            0.08710801393728224,
            0.10801393728222997,
            0.12195121951219512,
            0.13240418118466898,
            0.14285714285714285,
            0.15331010452961671,
            0.1602787456445993,
            0.17073170731707318,
            0.18118466898954705,
            0.1916376306620209,
            0.20209059233449478,
            0.20905923344947736,
            0.21254355400696864,
            0.21951219512195122,
            0.2264808362369338,
            0.23344947735191637,
            0.23693379790940766,
            0.24390243902439024,
            0.24738675958188153,
            0.25435540069686413,
            0.2578397212543554,
            0.2613240418118467,
            0.2682926829268293,
            0.27177700348432055,
            0.27526132404181186,
            0.28222996515679444,
            0.2857142857142857,
            0.289198606271777,
            0.2926829268292683,
            0.2961672473867596,
            0.29965156794425085,
            0.30313588850174217,
            0.30662020905923343,
            0.313588850174216,
            0.3205574912891986,
            0.32752613240418116,
            0.3344947735191638,
            0.34146341463414637,
            0.34843205574912894,
            0.3554006968641115,
            0.3623693379790941,
            0.3693379790940767,
            0.37630662020905925,
            0.3797909407665505,
            0.3867595818815331,
            0.39372822299651566,
            0.397212543554007,
            0.40418118466898956,
            0.41114982578397213,
            0.4181184668989547,
            0.4250871080139373,
            0.43205574912891986,
            0.43902439024390244,
            0.445993031358885,
            0.4529616724738676,
            0.4564459930313589,
            0.4634146341463415,
            0.47038327526132406,
            0.4738675958188153,
            0.4808362369337979,
            0.4878048780487805,
            0.49477351916376305,
            0.49825783972125437,
            0.5052264808362369,
            0.5121951219512195,
            0.519163763066202,
            0.5261324041811847,
            0.5331010452961672,
            0.5400696864111498,
            0.5470383275261324,
            0.554006968641115,
            0.5609756097560976,
            0.5679442508710801,
            0.5749128919860628,
            0.5818815331010453,
            0.5888501742160279,
            0.5993031358885017,
            0.6062717770034843,
            0.6167247386759582,
            0.627177700348432,
            0.6411149825783972,
            0.6585365853658537,
            0.6759581881533101,
            0.6968641114982579,
            0.7282229965156795,
            0.7909407665505227,
            1.0,
        ]
        
        return VariableBlurView.Gradient(
            height: baseHeight,
            alpha: gradientColors.map { $0 / gradientColorNorm },
            positions: gradientLocations
        )
    }
    
    public static func generateEdgeGradient(baseHeight: CGFloat, isInverted: Bool) -> UIImage {
        let gradientColors: [CGFloat] = [
            0.8470588235294118,
            0.8431372549019608,
            0.8392156862745098,
            0.8352941176470589,
            0.8313725490196078,
            0.8274509803921568,
            0.8235294117647058,
            0.8196078431372549,
            0.8156862745098039,
            0.8117647058823529,
            0.807843137254902,
            0.803921568627451,
            0.8,
            0.7960784313725491,
            0.792156862745098,
            0.788235294117647,
            0.7843137254901961,
            0.7803921568627451,
            0.7764705882352941,
            0.7725490196078432,
            0.7686274509803921,
            0.7647058823529411,
            0.7607843137254902,
            0.7568627450980392,
            0.7529411764705882,
            0.7490196078431373,
            0.7450980392156863,
            0.7411764705882353,
            0.7372549019607844,
            0.7333333333333334,
            0.7294117647058824,
            0.7254901960784313,
            0.7215686274509804,
            0.7176470588235294,
            0.7137254901960784,
            0.7098039215686274,
            0.7019607843137254,
            0.6941176470588235,
            0.6862745098039216,
            0.6784313725490196,
            0.6705882352941177,
            0.6588235294117647,
            0.6509803921568628,
            0.6431372549019607,
            0.6313725490196078,
            0.6235294117647059,
            0.615686274509804,
            0.603921568627451,
            0.596078431372549,
            0.5882352941176471,
            0.5764705882352941,
            0.5647058823529412,
            0.5529411764705883,
            0.5411764705882354,
            0.5294117647058824,
            0.5176470588235293,
            0.5058823529411764,
            0.49411764705882355,
            0.4862745098039216,
            0.4745098039215686,
            0.4627450980392157,
            0.4549019607843138,
            0.44313725490196076,
            0.43137254901960786,
            0.41960784313725485,
            0.4117647058823529,
            0.4,
            0.388235294117647,
            0.3764705882352941,
            0.3647058823529412,
            0.3529411764705882,
            0.3411764705882353,
            0.3294117647058824,
            0.3176470588235294,
            0.3058823529411765,
            0.2941176470588235,
            0.2823529411764706,
            0.2705882352941177,
            0.2588235294117647,
            0.2431372549019608,
            0.2313725490196078,
            0.21568627450980393,
            0.19999999999999996,
            0.18039215686274512,
            0.16078431372549018,
            0.14117647058823535,
            0.11764705882352944,
            0.09019607843137256,
            0.04705882352941182,
            0.0,
        ]
        
        let gradientColorNorm = gradientColors.max()!

        let gradientLocations: [CGFloat] = [
            0.0,
            0.020905923344947737,
            0.059233449477351915,
            0.08710801393728224,
            0.10801393728222997,
            0.12195121951219512,
            0.13240418118466898,
            0.14285714285714285,
            0.15331010452961671,
            0.1602787456445993,
            0.17073170731707318,
            0.18118466898954705,
            0.1916376306620209,
            0.20209059233449478,
            0.20905923344947736,
            0.21254355400696864,
            0.21951219512195122,
            0.2264808362369338,
            0.23344947735191637,
            0.23693379790940766,
            0.24390243902439024,
            0.24738675958188153,
            0.25435540069686413,
            0.2578397212543554,
            0.2613240418118467,
            0.2682926829268293,
            0.27177700348432055,
            0.27526132404181186,
            0.28222996515679444,
            0.2857142857142857,
            0.289198606271777,
            0.2926829268292683,
            0.2961672473867596,
            0.29965156794425085,
            0.30313588850174217,
            0.30662020905923343,
            0.313588850174216,
            0.3205574912891986,
            0.32752613240418116,
            0.3344947735191638,
            0.34146341463414637,
            0.34843205574912894,
            0.3554006968641115,
            0.3623693379790941,
            0.3693379790940767,
            0.37630662020905925,
            0.3797909407665505,
            0.3867595818815331,
            0.39372822299651566,
            0.397212543554007,
            0.40418118466898956,
            0.41114982578397213,
            0.4181184668989547,
            0.4250871080139373,
            0.43205574912891986,
            0.43902439024390244,
            0.445993031358885,
            0.4529616724738676,
            0.4564459930313589,
            0.4634146341463415,
            0.47038327526132406,
            0.4738675958188153,
            0.4808362369337979,
            0.4878048780487805,
            0.49477351916376305,
            0.49825783972125437,
            0.5052264808362369,
            0.5121951219512195,
            0.519163763066202,
            0.5261324041811847,
            0.5331010452961672,
            0.5400696864111498,
            0.5470383275261324,
            0.554006968641115,
            0.5609756097560976,
            0.5679442508710801,
            0.5749128919860628,
            0.5818815331010453,
            0.5888501742160279,
            0.5993031358885017,
            0.6062717770034843,
            0.6167247386759582,
            0.627177700348432,
            0.6411149825783972,
            0.6585365853658537,
            0.6759581881533101,
            0.6968641114982579,
            0.7282229965156795,
            0.7909407665505227,
            1.0,
        ]
        
        return generateGradientImage(
            size: CGSize(width: 1.0, height: baseHeight),
            colors: gradientColors.map { UIColor(white: 0.0, alpha: $0 / gradientColorNorm) },
            locations: gradientLocations,
            isInverted: isInverted
        )!.resizableImage(withCapInsets: UIEdgeInsets(top: isInverted ? baseHeight : 0.0, left: 0.0, bottom: isInverted ? 0.0 : baseHeight, right: 0.0), resizingMode: .stretch)
    }
}

public final class EdgeEffectComponent: Component {
    private let color: UIColor
    private let blur: Bool
    private let alpha: CGFloat
    private let size: CGSize
    private let edge: EdgeEffectView.Edge
    private let edgeSize: CGFloat
    
    public init(
        color: UIColor,
        blur: Bool,
        alpha: CGFloat,
        size: CGSize,
        edge: EdgeEffectView.Edge,
        edgeSize: CGFloat
    ) {
        self.color = color
        self.blur = blur
        self.alpha = alpha
        self.size = size
        self.edge = edge
        self.edgeSize = edgeSize
    }
    
    public static func == (lhs: EdgeEffectComponent, rhs: EdgeEffectComponent) -> Bool {
        if lhs.color != rhs.color {
            return false
        }
        if lhs.blur != rhs.blur {
            return false
        }
        if lhs.alpha != rhs.alpha {
            return false
        }
        if lhs.size != rhs.size {
            return false
        }
        if lhs.edge != rhs.edge {
            return false
        }
        if lhs.edgeSize != rhs.edgeSize {
            return false
        }
        return true
    }
    
    public final class View: EdgeEffectView {
        func update(component: EdgeEffectComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.update(content: component.color, blur: component.blur, alpha: component.alpha, rect: CGRect(origin: .zero, size: component.size), edge: component.edge, edgeSize: component.edgeSize, transition: transition)
            
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

public final class VariableBlurView: UIView {
    private struct Params: Equatable {
        let size: CGSize
        let constantHeight: CGFloat
        let isInverted: Bool
        let gradient: Gradient
        
        init(size: CGSize, constantHeight: CGFloat, isInverted: Bool, gradient: Gradient) {
            self.size = size
            self.constantHeight = constantHeight
            self.isInverted = isInverted
            self.gradient = gradient
        }
    }
    
    public final class Gradient: Equatable {
        public let height: CGFloat
        public let alpha: [CGFloat]
        public let positions: [CGFloat]
        
        public init(height: CGFloat, alpha: [CGFloat], positions: [CGFloat]) {
            self.height = height
            self.alpha = alpha
            self.positions = positions
        }
        
        public static func ==(lhs: Gradient, rhs: Gradient) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.height != rhs.height {
                return false
            }
            if lhs.alpha != rhs.alpha {
                return false
            }
            if lhs.positions != rhs.positions {
                return false
            }
            return true
        }
    }
    
    public let maxBlurRadius: CGFloat
    
    private let effectLayerDelegate: SimpleLayerDelegate
    private var mainEffectLayer: CALayer?
    private var additionalEffectLayer: CALayer?
    
    private var params: Params?
    private var gradientImage: UIImage?
    private var isAnimating: Bool = false
    
    private let imageSubview: UIImageView
    
    public init(maxBlurRadius: CGFloat = 20.0) {
        self.maxBlurRadius = maxBlurRadius
        
        self.effectLayerDelegate = SimpleLayerDelegate()
        
        self.mainEffectLayer = createBackdropLayer()
        if #available(iOS 26.0, *) {
            if let mainEffectLayer = self.mainEffectLayer, let variableBlur = CALayer.variableBlur() {
                variableBlur.setValue(self.maxBlurRadius, forKey: "inputRadius")
                variableBlur.setValue("mask_source", forKey: "inputSourceSublayerName")
                variableBlur.setValue(true, forKey: "inputNormalizeEdges")
                mainEffectLayer.filters = [variableBlur]
                
                /*#if DEBUG
                if let classValue = NSClassFromString("CAFilter") as AnyObject as? NSObjectProtocol {
                    let makeSelector = NSSelectorFromString("filterWithName:")
                    let filter = classValue.perform(makeSelector, with: "colorMatrix").takeUnretainedValue() as? NSObject
                    
                    if let filter {
                        /// Builds a 4x5 (RGBA) color matrix (20 floats, row-major).
                        /// Applies: Desaturate(s) then TintToward(t, k) in linear RGB.
                        /// - s: saturation in [0,1] (1 = unchanged, 0 = grayscale)
                        /// - k: tint strength in [0,1] (0 = none, 1 = fully "brightness->tint" mapping)
                        /// - t: tint color (linear RGB). Doesn't have to be normalized, but should be non-negative.
                        /// - bias: optional constant "cast" added in the bias column, scaled by tint color.
                        let makeDesatTintMatrix: (Float32, Float32, (Float32, Float32, Float32), Float32) -> [Float32] = { s, k, t, bias in
                            // Rec.709 luma weights (good default for linear RGB)
                            let wr: Float32 = 0.2126
                            let wg: Float32 = 0.7152
                            let wb: Float32 = 0.0722

                            let (tr, tg, tb) = t

                            // --- D = desaturation matrix ---
                            let a = 1 - s

                            let D00 = wr * a + s, D01 = wg * a,     D02 = wb * a
                            let D10 = wr * a,     D11 = wg * a + s, D12 = wb * a
                            let D20 = wr * a,     D21 = wg * a,     D22 = wb * a + s

                            // --- T = outer(t, w): maps luma to tinted RGB (preserves luma per weights) ---
                            let T00 = tr * wr, T01 = tr * wg, T02 = tr * wb
                            let T10 = tg * wr, T11 = tg * wg, T12 = tg * wb
                            let T20 = tb * wr, T21 = tb * wg, T22 = tb * wb

                            // --- A = (1-k)I + kT ---
                            let ik = 1 - k

                            let A00 = ik + k * T00, A01 =      k * T01, A02 =      k * T02
                            let A10 =      k * T10, A11 = ik + k * T11, A12 =      k * T12
                            let A20 =      k * T20, A21 =      k * T21, A22 = ik + k * T22

                            // --- M = A * D (3x3 multiply) ---
                            let M00 = A00 * D00 + A01 * D10 + A02 * D20
                            let M01 = A00 * D01 + A01 * D11 + A02 * D21
                            let M02 = A00 * D02 + A01 * D12 + A02 * D22

                            let M10 = A10 * D00 + A11 * D10 + A12 * D20
                            let M11 = A10 * D01 + A11 * D11 + A12 * D21
                            let M12 = A10 * D02 + A11 * D12 + A12 * D22

                            let M20 = A20 * D00 + A21 * D10 + A22 * D20
                            let M21 = A20 * D01 + A21 * D11 + A22 * D21
                            let M22 = A20 * D02 + A21 * D12 + A22 * D22

                            // Optional constant cast in bias column
                            let bR = bias * tr
                            let bG = bias * tg
                            let bB = bias * tb

                            // 4x5 row-major, alpha passthrough:
                            return [
                                M00, M01, M02, 0, bR,
                                M10, M11, M12, 0, bG,
                                M20, M21, M22, 0, bB,
                                0,   0,   0,   1, 0
                            ]
                        }
                        
                        var matrix: [Float32] = makeDesatTintMatrix(
                            0.1,                // more desaturated
                            0.1,                 // moderate tinting
                            (0.0, 1.0, 0.0),     // warm tint target
                            0.0               // set e.g. 0.03 for a gentle warm cast
                        )
                        filter.setValue(NSValue(bytes: &matrix, objCType: "{CAColorMatrix=ffffffffffffffffffff}"), forKey: "inputColorMatrix")
                        mainEffectLayer.filters = [variableBlur, filter]
                    }
                }
                #endif*/
            }
        } else {
            self.additionalEffectLayer = createBackdropLayer()
        }
        
        self.imageSubview = UIImageView()
        self.imageSubview.layer.name = "mask_source"
        
        super.init(frame: CGRect())
        
        let groupName = "group-\(UInt32.random(in: 0 ... UInt32.max))"

        if let mainEffectLayer = self.mainEffectLayer {
            mainEffectLayer.delegate = self.effectLayerDelegate
            mainEffectLayer.setValue(0.5, forKey: "scale")
            mainEffectLayer.setValue(groupName, forKey: "groupName")
            
            self.layer.addSublayer(mainEffectLayer)
            if #available(iOS 26.0, *) {
                mainEffectLayer.addSublayer(self.imageSubview.layer)
            }
        }
        
        if let additionalEffectLayer = self.additionalEffectLayer {
            self.layer.addSublayer(additionalEffectLayer)
            
            additionalEffectLayer.delegate = self.effectLayerDelegate
            additionalEffectLayer.setValue(0.5, forKey: "scale")
            
            if let blurFilter = CALayer.blur() {
                blurFilter.setValue(true, forKey: "inputNormalizeEdges")
                blurFilter.setValue((maxBlurRadius * 2.0) as NSNumber, forKey: "inputRadius")
                additionalEffectLayer.filters = [blurFilter]
            }
        }
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateLegacyEffect() {
        guard let params = self.params else {
            return
        }
        guard let mainEffectLayer = self.mainEffectLayer else {
            return
        }
        guard let variableBlur = CALayer.variableBlur() else {
            return
        }
        guard let gradientImage = self.gradientImage else {
            return
        }
        variableBlur.setValue(self.maxBlurRadius, forKey: "inputRadius")
        variableBlur.setValue(true, forKey: "inputNormalizeEdges")
        
        let image: UIImage? = generateImage(CGSize(width: 1.0, height: min(800.0, params.size.height)), rotatedContext: { size, context in
            UIGraphicsPushContext(context)
            defer {
                UIGraphicsPopContext()
            }
            
            context.clear(CGRect(origin: CGPoint(), size: size))
            
            let mainEffectFrame: CGRect
            let additionalEffectFrame: CGRect
            
            if params.isInverted {
                mainEffectFrame = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: params.constantHeight))
                additionalEffectFrame = CGRect(origin: CGPoint(x: 0.0, y: params.constantHeight), size: CGSize(width: size.width, height: max(0.0, size.height - params.constantHeight)))
            } else {
                mainEffectFrame = CGRect(origin: CGPoint(x: 0.0, y: size.height - params.constantHeight), size: CGSize(width: size.width, height: params.constantHeight))
                additionalEffectFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: max(0.0, size.height - params.constantHeight)))
            }
            
            context.setFillColor(UIColor(white: 0.0, alpha: 1.0).cgColor)
            context.fill(additionalEffectFrame)
            
            gradientImage.draw(in: mainEffectFrame, blendMode: .normal, alpha: 1.0)
        })
        
        if let cgImage = image?.cgImage {
            variableBlur.setValue(cgImage, forKey: "inputMaskImage")
        }
        
        mainEffectLayer.filters = [variableBlur]
    }
    
    public func update(size: CGSize, constantHeight: CGFloat, isInverted: Bool, gradient: Gradient, transition: ContainedViewLayoutTransition) {
        let params = Params(size: size, constantHeight: constantHeight, isInverted: isInverted, gradient: gradient)
        if params == self.params {
            return
        }
        
        let isGradientUpdated = gradient != self.params?.gradient
        let isHeightUpdated = gradient.height != self.params?.gradient.height || size.height != self.params?.size.height
        
        if isGradientUpdated {
            self.gradientImage = EdgeEffectView.generateEdgeGradient(baseHeight: max(1.0, params.gradient.height), isInverted: params.isInverted)
        }
        
        self.params = params
        
        guard let mainEffectLayer = self.mainEffectLayer else {
            return
        }
        
        let transition = ComponentTransition(transition)
        
        if #available(iOS 26.0, *) {
            if isGradientUpdated {
                self.imageSubview.image = self.gradientImage
            }
            transition.setFrame(layer: mainEffectLayer, frame: CGRect(origin: CGPoint(), size: size))
            transition.setFrame(view: self.imageSubview, frame: CGRect(origin: CGPoint(), size: size))
        } else {
            if isHeightUpdated || isGradientUpdated {
                self.updateLegacyEffect()
                transition.setFrame(layer: mainEffectLayer, frame: CGRect(origin: CGPoint(), size: size))
            } else {
                transition.setFrame(layer: mainEffectLayer, frame: CGRect(origin: CGPoint(), size: size))
            }
        }
    }
}
