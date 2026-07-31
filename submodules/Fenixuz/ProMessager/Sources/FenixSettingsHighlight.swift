import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import ItemListUI

// Feature #40 (part c): the "you arrived here from a link" animation.
//
// An accent-coloured outline is drawn just inside the target row and traced around it, twice.
// This ONLY runs when the settings screen was opened from a per-feature deep link — opening
// Settings normally never reaches this file.
enum FenixSettingsHighlight {
    // Layer names, so a second link tap can clear a still-running pass.
    private static let fillLayerName = "fenixSettingsHighlightFill"
    private static let strokeLayerName = "fenixSettingsHighlightStroke"

    // One pass = trace the outline, hold it, fade it out.
    private static let cycleDuration: Double = 1.1
    private static let traceFraction: Double = 0.45
    private static let holdFraction: Double = 0.68
    private static let passCount: Float = 2.0

    private static let cornerRadius: CGFloat = 11.0
    private static let lineWidth: CGFloat = 2.0
    private static let outlineInset: CGFloat = 3.0
    private static let fillAlpha: CGFloat = 0.10

    // The row may not exist yet when the screen appears — the list still has to lay out and
    // scroll. Retry for about 2.5 s, then give up quietly.
    private static let retryInterval: Double = 0.2
    private static let retryCount: Int = 12
    private static let scrollSettleDelay: Double = 0.3
    private static let visibleOverflow: CGFloat = 24.0

    /// Waits for the row to exist, makes sure it is fully visible, then traces the outline.
    static func run(controller: ItemListController, feature: FenixSettingsFeature, accentColor: UIColor) {
        self.attempt(controller: controller, feature: feature, accentColor: accentColor, remaining: self.retryCount)
    }

    private static func attempt(controller: ItemListController, feature: FenixSettingsFeature, accentColor: UIColor, remaining: Int) {
        let tag = FenixSettingsItemTag(feature: feature)
        if let itemNode = controller.itemNode(forTag: tag) {
            // The row exists but may be clipped by the navigation bar or the screen edge.
            controller.ensureItemNodeVisible(itemNode, animated: true, overflow: self.visibleOverflow)
            Queue.mainQueue().after(self.scrollSettleDelay, { [weak controller] in
                guard let controller, let itemNode = controller.itemNode(forTag: tag) else {
                    return
                }
                self.play(on: itemNode, listInsets: controller.listInsets, accentColor: accentColor)
            })
            return
        }
        guard remaining > 0 else {
            return
        }
        Queue.mainQueue().after(self.retryInterval, { [weak controller] in
            guard let controller else {
                return
            }
            self.attempt(controller: controller, feature: feature, accentColor: accentColor, remaining: remaining - 1)
        })
    }

    /// Draws the outline inside `itemNode` and animates it. The layers live on the row itself, so
    /// they scroll with it and disappear on their own.
    static func play(on itemNode: ListViewItemNode, listInsets: UIEdgeInsets, accentColor: UIColor) {
        let contentBounds = itemNode.contentBounds
        let rect = CGRect(
            x: listInsets.left + self.outlineInset,
            y: contentBounds.minY + self.outlineInset,
            width: contentBounds.width - listInsets.left - listInsets.right - self.outlineInset * 2.0,
            height: contentBounds.height - self.outlineInset * 2.0
        )
        guard rect.width > 32.0, rect.height > 16.0 else {
            return
        }

        let hostLayer = itemNode.layer
        self.removeExisting(from: hostLayer)

        let path = UIBezierPath(roundedRect: rect, cornerRadius: self.cornerRadius).cgPath

        let fillLayer = CAShapeLayer()
        fillLayer.name = self.fillLayerName
        fillLayer.path = path
        fillLayer.fillColor = accentColor.withAlphaComponent(self.fillAlpha).cgColor
        fillLayer.strokeColor = UIColor.clear.cgColor
        fillLayer.opacity = 0.0

        let strokeLayer = CAShapeLayer()
        strokeLayer.name = self.strokeLayerName
        strokeLayer.path = path
        strokeLayer.fillColor = UIColor.clear.cgColor
        strokeLayer.strokeColor = accentColor.cgColor
        strokeLayer.lineWidth = self.lineWidth
        strokeLayer.lineCap = .round
        strokeLayer.opacity = 0.0

        hostLayer.addSublayer(fillLayer)
        hostLayer.addSublayer(strokeLayer)

        let fillPulse = CAKeyframeAnimation(keyPath: "opacity")
        fillPulse.values = [0.0, 1.0, 1.0, 0.0]
        fillPulse.keyTimes = [0.0, NSNumber(value: self.traceFraction), NSNumber(value: self.holdFraction), 1.0]
        fillPulse.duration = self.cycleDuration
        fillPulse.repeatCount = self.passCount
        fillLayer.add(fillPulse, forKey: "fenixPulse")

        let trace = CABasicAnimation(keyPath: "strokeEnd")
        trace.fromValue = 0.0
        trace.toValue = 1.0
        trace.duration = self.cycleDuration * self.traceFraction
        trace.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let strokeFade = CAKeyframeAnimation(keyPath: "opacity")
        strokeFade.values = [1.0, 1.0, 0.0]
        strokeFade.keyTimes = [0.0, NSNumber(value: self.holdFraction), 1.0]
        strokeFade.duration = self.cycleDuration

        let group = CAAnimationGroup()
        group.animations = [trace, strokeFade]
        group.duration = self.cycleDuration
        group.repeatCount = self.passCount
        strokeLayer.add(group, forKey: "fenixTrace")

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        let lifetime = self.cycleDuration * Double(self.passCount) + 0.1
        Queue.mainQueue().after(lifetime, { [weak fillLayer, weak strokeLayer] in
            fillLayer?.removeFromSuperlayer()
            strokeLayer?.removeFromSuperlayer()
        })
    }

    private static func removeExisting(from layer: CALayer) {
        guard let sublayers = layer.sublayers else {
            return
        }
        for sublayer in sublayers where sublayer.name == self.fillLayerName || sublayer.name == self.strokeLayerName {
            sublayer.removeFromSuperlayer()
        }
    }
}
