import Foundation
import CoreGraphics
import CoreImage
import CoreVideo
import Metal

// Composes one portrait recording frame: the other side aspect-fit on black, full frame, and our own video as a
// picture-in-picture with rounded corners in the top-right corner. When only one side has video it fills the frame.
// Renders through a Metal-backed CIContext. Used on the recorder queue only.
final class NovagramCallVideoCompositor {
    static let width = 720
    static let height = 1280
    static let pipWidthFraction: CGFloat = 0.28
    static let pipMargin: CGFloat = 24
    static let pipCornerRadius: CGFloat = 18
    // The picture-in-picture keeps its own aspect ratio within these height-to-width limits.
    static let pipMinAspect: CGFloat = 0.5
    static let pipMaxAspect: CGFloat = 2.0

    private let context: CIContext
    private let colorSpace: CGColorSpace
    private let background: CIImage

    init() {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        self.colorSpace = colorSpace
        let options: [CIContextOption: Any] = [.workingColorSpace: colorSpace, .cacheIntermediates: false]
        if let device = MTLCreateSystemDefaultDevice() {
            self.context = CIContext(mtlDevice: device, options: options)
        } else {
            self.context = CIContext(options: options)
        }
        self.background = CIImage(color: CIColor(red: 0, green: 0, blue: 0)).cropped(to: NovagramCallVideoCompositor.canvas)
    }

    static var canvas: CGRect {
        return CGRect(x: 0, y: 0, width: NovagramCallVideoCompositor.width, height: NovagramCallVideoCompositor.height)
    }

    func render(remote: CIImage?, local: CIImage?, into pixelBuffer: CVPixelBuffer) {
        let image = NovagramCallVideoCompositor.compose(remote: remote, local: local, background: self.background)
        self.context.render(image, to: pixelBuffer, bounds: NovagramCallVideoCompositor.canvas, colorSpace: self.colorSpace)
    }

    static func compose(remote: CIImage?, local: CIImage?, background: CIImage) -> CIImage {
        let canvas = NovagramCallVideoCompositor.canvas
        var result = background
        let main = remote ?? local
        let pip = remote != nil ? local : nil
        if let main {
            result = NovagramCallVideoCompositor.place(main, in: canvas, fill: false).composited(over: result)
        }
        if let pip {
            let rect = NovagramCallVideoCompositor.pipRect(for: pip.extent.size)
            let placed = NovagramCallVideoCompositor.place(pip, in: rect, fill: true).cropped(to: rect)
            let mask = CIFilter(name: "CIRoundedRectangleGenerator", parameters: [
                "inputExtent": CIVector(cgRect: rect),
                "inputRadius": NovagramCallVideoCompositor.pipCornerRadius,
                "inputColor": CIColor(red: 1, green: 1, blue: 1)
            ])?.outputImage
            if let mask, let blended = CIFilter(name: "CIBlendWithMask", parameters: [
                kCIInputImageKey: placed,
                kCIInputBackgroundImageKey: result,
                kCIInputMaskImageKey: mask
            ])?.outputImage {
                result = blended
            } else {
                result = placed.composited(over: result)
            }
        }
        return result.cropped(to: canvas)
    }

    // Top-right corner, in Core Image coordinates (y up).
    static func pipRect(for size: CGSize) -> CGRect {
        let canvas = NovagramCallVideoCompositor.canvas
        let width = (canvas.width * NovagramCallVideoCompositor.pipWidthFraction).rounded()
        var aspect = size.width > 0 ? size.height / size.width : 1
        aspect = min(max(aspect, NovagramCallVideoCompositor.pipMinAspect), NovagramCallVideoCompositor.pipMaxAspect)
        let height = (width * aspect).rounded()
        return CGRect(x: canvas.maxX - NovagramCallVideoCompositor.pipMargin - width, y: canvas.maxY - NovagramCallVideoCompositor.pipMargin - height, width: width, height: height)
    }

    // Scales `image` to fit (or fill) `rect` and centres it there.
    static func place(_ image: CIImage, in rect: CGRect, fill: Bool) -> CIImage {
        let extent = image.extent
        guard extent.width > 0, extent.height > 0 else {
            return image
        }
        let scaleX = rect.width / extent.width
        let scaleY = rect.height / extent.height
        let scale = fill ? max(scaleX, scaleY) : min(scaleX, scaleY)
        let width = extent.width * scale
        let height = extent.height * scale
        let transform = CGAffineTransform(translationX: -extent.minX, y: -extent.minY)
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: rect.midX - width / 2, y: rect.midY - height / 2))
        return image.transformed(by: transform)
    }
}
