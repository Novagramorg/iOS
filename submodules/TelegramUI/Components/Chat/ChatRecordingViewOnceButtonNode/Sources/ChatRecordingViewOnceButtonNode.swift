import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import GlassBackgroundComponent

public final class ChatRecordingViewOnceButtonNode: HighlightTrackingButtonNode {
    public enum Icon {
        case viewOnce
        case recordMore
    }
    
    private let icon: Icon
    
    private let backgroundView: GlassBackgroundView
    private let iconNode: ASImageNode
    
    private var theme: PresentationTheme?
        
    public init(icon: Icon) {
        self.icon = icon
        
        self.backgroundView = GlassBackgroundView()
        self.backgroundView.isUserInteractionEnabled = false
        
        self.iconNode = ASImageNode()
        self.iconNode.isUserInteractionEnabled = false
        
        super.init(pointerStyle: .default)
        
        self.view.addSubview(self.backgroundView)
        self.addSubnode(self.iconNode)
        
        self.highligthedChanged = { [weak self] highlighted in
            if let self, self.bounds.width > 0.0 {
                let topScale: CGFloat = (self.bounds.width - 8.0) / self.bounds.width
                let maxScale: CGFloat = (self.bounds.width + 2.0) / self.bounds.width
                
                if highlighted {
                    self.layer.removeAnimation(forKey: "sublayerTransform")
                    let transition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut)
                    transition.updateTransformScale(node: self, scale: topScale)
                } else {
                    let transition = ContainedViewLayoutTransition.immediate
                    transition.updateTransformScale(node: self, scale: 1.0)
                    
                    self.layer.animateScale(from: topScale, to: maxScale, duration: 0.13, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false, completion: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        
                        self.layer.animateScale(from: maxScale, to: 1.0, duration: 0.1, timingFunction: CAMediaTimingFunctionName.easeIn.rawValue)
                    })
                }
            }
        }
    }
    
    private var innerIsSelected = false
    public func update(isSelected: Bool, animated: Bool = false) {
        guard let theme = self.theme else {
            return
        }
        
        let updated = self.iconNode.image == nil || self.innerIsSelected != isSelected
        self.innerIsSelected = isSelected
        
        if animated, updated && self.iconNode.image != nil, let snapshot = self.iconNode.view.snapshotContentTree() {
            self.view.addSubview(snapshot)
            snapshot.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                snapshot.removeFromSuperview()
            })
            
            self.iconNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        }
        
        if updated {
            if case .viewOnce = self.icon {
                self.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: self.innerIsSelected ? "Media Gallery/ViewOnceEnabled" : "Media Gallery/ViewOnce"), color: theme.chat.inputPanel.panelControlAccentColor)
            }
        }
    }
    
    public func update(theme: PresentationTheme) -> CGSize {
        let size = CGSize(width: 44.0, height: 44.0)
        let innerSize = CGSize(width: 40.0, height: 40.0)
        
        if self.theme !== theme {
            self.theme = theme
            
            switch self.icon {
            case .viewOnce:
                self.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: self.innerIsSelected ? "Media Gallery/ViewOnceEnabled" : "Media Gallery/ViewOnce"), color: theme.chat.inputPanel.panelControlAccentColor)
            case .recordMore:
                self.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Text/IconMicrophone"), color: theme.chat.inputPanel.panelControlAccentColor)
            }
        }
        
        let backgroundFrame = CGRect(origin: CGPoint(x: floorToScreenPixels(size.width / 2.0 - innerSize.width / 2.0), y: floorToScreenPixels(size.height / 2.0 - innerSize.height / 2.0)), size: innerSize)
        self.backgroundView.frame = backgroundFrame
        self.backgroundView.update(size: backgroundFrame.size, cornerRadius: backgroundFrame.height * 0.5, isDark: theme.overallDarkAppearance, tintColor: .init(kind: .panel, color: theme.chat.inputPanel.inputBackgroundColor.withMultipliedAlpha(0.65)), transition: .immediate)

        if let iconImage = self.iconNode.image {
            let iconFrame = CGRect(origin: CGPoint(x: floorToScreenPixels(size.width / 2.0 - iconImage.size.width / 2.0), y: floorToScreenPixels(size.height / 2.0 - iconImage.size.height / 2.0)), size: iconImage.size)
            self.iconNode.frame = iconFrame
        }
        return size
    }
}
