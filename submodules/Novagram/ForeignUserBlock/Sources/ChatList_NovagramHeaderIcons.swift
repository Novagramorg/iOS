import Foundation
import UIKit
import AppBundle

/// Images for the Novagram buttons in the chat-list header (the fold chevron and ghost mode). The glass bar
/// draws an image button at the image's own size and tints it only when it is a template image. Each image is
/// made once: a new UIImage on every header update would count as a changed button.
public enum NovagramHeaderIcons {
    // The ghost PDFs have a large artboard; the old bar button clamped them to this size.
    private static let maxGhostSize: CGFloat = 28.0

    private static let foldedImage = symbol("chevron.left")
    private static let expandedImage = symbol("chevron.right")
    private static let ghostActiveImage = bundleImage("Contact List/NovagramGhostActive", template: false)
    private static let ghostInactiveImage = bundleImage("Contact List/NovagramGhostInactive", template: true)

    /// The fold chevron (`NovagramHeaderFold.iconName`), tinted with the bar's button colour.
    public static func fold(isExpanded: Bool) -> UIImage {
        return isExpanded ? self.expandedImage : self.foldedImage
    }

    /// Ghost mode on: the purple PDF in its own colours. Off: the outline, tinted with the button colour.
    public static func ghostMode(isActive: Bool) -> UIImage {
        return isActive ? self.ghostActiveImage : self.ghostInactiveImage
    }

    private static func symbol(_ name: String) -> UIImage {
        let configuration = UIImage.SymbolConfiguration(pointSize: 20.0, weight: .medium)
        return (UIImage(systemName: name, withConfiguration: configuration) ?? UIImage()).withRenderingMode(.alwaysTemplate)
    }

    private static func bundleImage(_ name: String, template: Bool) -> UIImage {
        guard let image = UIImage(bundleImageName: name) else {
            return UIImage()
        }
        var size = image.size
        let largest = max(size.width, size.height)
        if largest > self.maxGhostSize {
            let scale = self.maxGhostSize / largest
            size = CGSize(width: floor(size.width * scale), height: floor(size.height * scale))
        }
        let scaled = UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return scaled.withRenderingMode(template ? .alwaysTemplate : .alwaysOriginal)
    }
}
