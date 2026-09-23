import Foundation
import UIKit
import CoreText

struct WalletSendAmountMotionTiming {
    let start: Double
    let duration: Double
    let spin: Bool
    let up: Bool
    let reduced: Bool

    init(spin: Bool, up: Bool, start: Double = CACurrentMediaTime(), reduced: Bool? = nil) {
        self.start = start
        self.reduced = reduced ?? UIAccessibility.isReduceMotionEnabled
        self.duration = self.reduced ? 0.15 : (spin ? 0.46 : 0.22)
        self.spin = spin
        self.up = up
    }

    func progress(at time: Double) -> CGFloat {
        return CGFloat(min(1.0, max(0.0, (time - self.start) / self.duration)))
    }

    static func ease(_ t: CGFloat) -> CGFloat {
        return 1.0 - pow(1.0 - min(1.0, max(0.0, t)), 2.2)
    }
}

struct WalletSendAmountGlyph: Equatable {
    enum Group: Int, CaseIterable {
        case integer, fraction, grouping, suffix, prefix
    }

    var text: String
    var font: UIFont
    var color: UIColor
    var position: CGPoint
    var group: Group

    var leadingEdge: CGFloat {
        return self.position.x - (self.text as NSString).size(withAttributes: [.font: self.font]).width / 2.0
    }

    static func text(_ text: NSAttributedString, origin: CGPoint, group: Group) -> [WalletSendAmountGlyph] {
        guard text.length > 0 else { return [] }
        let line = CTLineCreateWithAttributedString(text)
        var positionsByIndex: [Int: CGPoint] = [:]
        for run in CTLineGetGlyphRuns(line) as! [CTRun] {
            let count = CTRunGetGlyphCount(run)
            var positions = [CGPoint](repeating: .zero, count: count)
            var indices = [CFIndex](repeating: 0, count: count)
            CTRunGetPositions(run, CFRangeMake(0, count), &positions)
            CTRunGetStringIndices(run, CFRangeMake(0, count), &indices)
            for i in 0 ..< count where positionsByIndex[indices[i]] == nil {
                positionsByIndex[indices[i]] = positions[i]
            }
        }
        var offset = 0
        return text.string.map { character in
            let string = String(character)
            let attributes = text.attributes(at: offset, effectiveRange: nil)
            let font = attributes[.font] as? UIFont ?? UIFont.systemFont(ofSize: 13.0)
            let width = (string as NSString).size(withAttributes: [.font: font]).width
            let position = positionsByIndex[offset] ?? CGPoint(x: CTLineGetOffsetForStringIndex(line, offset, nil), y: 0.0)
            offset += string.utf16.count
            return WalletSendAmountGlyph(
                text: string, font: font, color: attributes[.foregroundColor] as? UIColor ?? .black,
                position: CGPoint(x: origin.x + position.x + width / 2.0, y: origin.y - position.y), group: group
            )
        }
    }
}

struct WalletSendAmountSprite {
    var glyph: WalletSendAmountGlyph
    var alpha: CGFloat = 1.0
    var scale: CGFloat = 1.0
    var trail: CGFloat = 0.0
    var spread: CGFloat = 0.0
}

private func amountMotionMix(_ a: CGFloat, _ b: CGFloat, _ p: CGFloat) -> CGFloat {
    return a + (b - a) * p
}

private func amountMotionGroupingAnchor(_ separator: WalletSendAmountGlyph, in glyphs: [WalletSendAmountGlyph], matching: (Int) -> Bool = { _ in true }) -> Int? {
    return glyphs.indices.filter { glyphs[$0].group == .integer && glyphs[$0].position.x > separator.position.x && matching($0) }
        .min { glyphs[$0].position.x < glyphs[$1].position.x }
}

func walletSendAmountMotionRect(_ a: CGRect, _ b: CGRect, _ p: CGFloat) -> CGRect {
    return CGRect(
        x: amountMotionMix(a.minX, b.minX, p), y: amountMotionMix(a.minY, b.minY, p),
        width: amountMotionMix(a.width, b.width, p), height: amountMotionMix(a.height, b.height, p)
    )
}

private func amountMotionColor(_ a: UIColor, _ b: UIColor, _ p: CGFloat) -> UIColor {
    if a.isEqual(b) { return b }
    var ar: CGFloat = 0.0, ag: CGFloat = 0.0, ab: CGFloat = 0.0, aa: CGFloat = 0.0
    var br: CGFloat = 0.0, bg: CGFloat = 0.0, bb: CGFloat = 0.0, ba: CGFloat = 0.0
    a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
    b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
    return UIColor(red: amountMotionMix(ar, br, p), green: amountMotionMix(ag, bg, p), blue: amountMotionMix(ab, bb, p), alpha: amountMotionMix(aa, ba, p))
}

final class WalletSendAmountMotion {
    private struct Cell {
        let from: WalletSendAmountGlyph?
        let to: WalletSendAmountGlyph?
        let column: [String]?
        let delay: Double
        var fromX: CGFloat? = nil
        var toX: CGFloat? = nil
    }

    private(set) var target: [WalletSendAmountGlyph] = []
    private(set) var timing: WalletSendAmountMotionTiming?
    private var cells: [Cell] = []
    private var interrupted: [WalletSendAmountSprite]?

    func isAnimating(at time: Double) -> Bool {
        guard let timing = self.timing else { return false }
        return timing.progress(at: time) < 1.0
    }

    func finish() {
        self.timing = nil
        self.cells.removeAll()
        self.interrupted = nil
    }

    func update(_ glyphs: [WalletSendAmountGlyph], timing: WalletSendAmountMotionTiming?, at now: Double = CACurrentMediaTime()) {
        guard glyphs != self.target else { return }
        let previous = self.target
        let interrupted = self.isAnimating(at: now) ? self.frame(at: now) : nil
        self.target = glyphs
        self.finish()
        guard let timing else { return }
        self.timing = timing
        self.interrupted = interrupted
        if interrupted != nil { return }

        for group in WalletSendAmountGlyph.Group.allCases {
            let old = previous.filter { $0.group == group }
            let new = glyphs.filter { $0.group == group }
            if group == .grouping {
                var used = Set<Int>()
                for separator in new {
                    let anchor = amountMotionGroupingAnchor(separator, in: glyphs).map { glyphs[$0] }
                    let fromAnchor = anchor.flatMap { anchor in self.cells.first { $0.to == anchor }?.from }
                    let match = old.indices.first { i in
                        guard !used.contains(i), old[i].text == separator.text,
                              let index = amountMotionGroupingAnchor(old[i], in: previous) else { return false }
                        return previous[index] == fromAnchor
                    }
                    if let match {
                        used.insert(match)
                        self.cells.append(Cell(from: old[match], to: separator, column: nil, delay: 0.0))
                    } else {
                        self.cells.append(Cell(from: nil, to: separator, column: nil, delay: 0.0, fromX: self.groupingCollapseEdge(separator, appearing: true)))
                    }
                }
                for i in old.indices where !used.contains(i) {
                    self.cells.append(Cell(from: old[i], to: nil, column: nil, delay: 0.0, toX: self.groupingCollapseEdge(old[i], appearing: false)))
                }
                continue
            }
            if timing.spin && !timing.reduced {
                let count = max(old.count, new.count)
                for slot in 0 ..< count {
                    let fromRight = group == .integer
                    let i = fromRight ? old.count - count + slot : slot
                    let j = fromRight ? new.count - count + slot : slot
                    let a = old.indices.contains(i) ? old[i] : nil
                    let b = new.indices.contains(j) ? new[j] : nil
                    let delay = group == .suffix ? min(0.05, 0.46 * 0.25 / Double(max(1, count - 1))) * Double(slot) : 0.0
                    self.cells.append(Cell(from: a, to: b, column: Self.column(a?.text, b?.text, up: timing.up), delay: delay))
                }
            } else {
                var head = 0
                while head < min(old.count, new.count), old[head].text == new[head].text { head += 1 }
                var tail = 0
                while tail < min(old.count, new.count) - head, old[old.count - tail - 1].text == new[new.count - tail - 1].text { tail += 1 }
                for i in 0 ..< head { self.cells.append(Cell(from: old[i], to: new[i], column: nil, delay: 0.0)) }
                for i in head ..< old.count - tail { self.cells.append(Cell(from: old[i], to: nil, column: nil, delay: 0.0)) }
                for i in head ..< new.count - tail { self.cells.append(Cell(from: nil, to: new[i], column: nil, delay: 0.0)) }
                for i in 0 ..< tail { self.cells.append(Cell(from: old[old.count - tail + i], to: new[new.count - tail + i], column: nil, delay: 0.0)) }
            }
        }
    }

    private func groupingCollapseEdge(_ separator: WalletSendAmountGlyph, appearing: Bool) -> CGFloat? {
        let anchors = self.cells.compactMap { cell -> (x: CGFloat, edge: CGFloat)? in
            guard let from = cell.from, let to = cell.to, from.group == .integer else { return nil }
            let anchor = appearing ? to : from
            guard anchor.position.x > separator.position.x else { return nil }
            return (anchor.position.x, (appearing ? from : to).leadingEdge)
        }
        return anchors.min { $0.x < $1.x }?.edge
    }

    private static func column(_ from: String?, _ to: String?, up: Bool) -> [String]? {
        if from == to { return nil }
        guard let a = from.flatMap(Int.init), let b = to.flatMap(Int.init) else {
            if let b = to.flatMap(Int.init), from == nil {
                return (0 ... 2).map { String((b + (up ? $0 - 2 : 2 - $0) + 10) % 10) }
            }
            if let a = from.flatMap(Int.init), to == nil {
                return (0 ... 2).map { String((a + (up ? $0 : -$0) + 10) % 10) }
            }
            return [from ?? " ", to ?? " "]
        }
        var values = [a]
        var value = a
        while value != b {
            value = (value + (up ? 1 : 9)) % 10
            values.append(value)
        }
        if values.count > 6 {
            values = (0 ... 5).map { values[Int((Double($0) / 5.0 * Double(values.count - 1)).rounded())] }
        }
        return values.map(String.init)
    }

    func frame(at time: Double, frameDuration: Double = 1.0 / 60.0) -> [WalletSendAmountSprite] {
        guard let timing = self.timing, timing.progress(at: time) < 1.0 else {
            return self.target.map { WalletSendAmountSprite(glyph: $0) }
        }
        let progress = WalletSendAmountMotionTiming.ease(timing.progress(at: time))
        if let source = self.interrupted {
            var used = Set<Int>()
            var matches: [Int: Int] = [:]
            let sourceGlyphs = source.map { $0.glyph }
            for (index, target) in self.target.enumerated() where target.group != .grouping {
                let match = source.indices.filter { !used.contains($0) && source[$0].glyph.text == target.text && source[$0].glyph.group == target.group }
                    .min { abs(source[$0].glyph.position.x - target.position.x) < abs(source[$1].glyph.position.x - target.position.x) }
                if let match {
                    matches[index] = match
                    used.insert(match)
                }
            }
            for (index, target) in self.target.enumerated() where target.group == .grouping {
                guard let anchor = amountMotionGroupingAnchor(target, in: self.target), let sourceAnchor = matches[anchor] else { continue }
                let match = source.indices.filter {
                    !used.contains($0) && source[$0].glyph.group == .grouping && source[$0].glyph.text == target.text
                        && amountMotionGroupingAnchor(source[$0].glyph, in: sourceGlyphs) == sourceAnchor
                }.min { abs(source[$0].glyph.position.x - target.position.x) < abs(source[$1].glyph.position.x - target.position.x) }
                if let match {
                    matches[index] = match
                    used.insert(match)
                }
            }
            let targetsBySource = Dictionary(uniqueKeysWithValues: matches.map { ($0.value, $0.key) })
            var result: [WalletSendAmountSprite] = []
            for (index, target) in self.target.enumerated() {
                if let match = matches[index] {
                    var sprite = source[match]
                    sprite.glyph.position.x = amountMotionMix(sprite.glyph.position.x, target.position.x, progress)
                    sprite.glyph.position.y = amountMotionMix(sprite.glyph.position.y, target.position.y, progress)
                    sprite.glyph.color = amountMotionColor(sprite.glyph.color, target.color, progress)
                    sprite.alpha = amountMotionMix(sprite.alpha, 1.0, progress)
                    sprite.scale = amountMotionMix(sprite.scale, 1.0, progress)
                    sprite.trail *= 1.0 - progress
                    sprite.spread *= 1.0 - progress
                    result.append(sprite)
                } else {
                    var glyph = target
                    if target.group == .grouping, let anchor = amountMotionGroupingAnchor(target, in: self.target, matching: { matches[$0] != nil }), let sourceAnchor = matches[anchor] {
                        glyph.position.x = amountMotionMix(source[sourceAnchor].glyph.leadingEdge, target.position.x, progress)
                    }
                    result.append(WalletSendAmountSprite(glyph: glyph, alpha: progress, scale: timing.reduced ? 1.0 : (target.group == .grouping ? progress : 0.86 + 0.14 * progress)))
                }
            }
            for i in source.indices where !used.contains(i) {
                var sprite = source[i]
                sprite.alpha *= 1.0 - progress
                if sprite.glyph.group == .grouping {
                    if let anchor = amountMotionGroupingAnchor(sprite.glyph, in: sourceGlyphs, matching: { targetsBySource[$0] != nil }), let targetAnchor = targetsBySource[anchor] {
                        sprite.glyph.position.x = amountMotionMix(sprite.glyph.position.x, self.target[targetAnchor].leadingEdge, progress)
                    }
                    if !timing.reduced { sprite.scale *= 1.0 - progress }
                }
                result.append(sprite)
            }
            return result
        }

        var result: [WalletSendAmountSprite] = []
        for cell in self.cells {
            guard var glyph = cell.to ?? cell.from else { continue }
            let raw = CGFloat(min(1.0, max(0.0, (time - timing.start - cell.delay) / (timing.duration - cell.delay))))
            let p = WalletSendAmountMotionTiming.ease(raw)
            let was = WalletSendAmountMotionTiming.ease(CGFloat(max(0.0, (time - frameDuration - timing.start - cell.delay) / (timing.duration - cell.delay))))
            if let a = cell.from, let b = cell.to {
                glyph.position.x = amountMotionMix(a.position.x, b.position.x, p)
                glyph.position.y = amountMotionMix(a.position.y, b.position.y, p)
                glyph.color = amountMotionColor(a.color, b.color, p)
            }
            if let fromX = cell.fromX {
                glyph.position.x = amountMotionMix(fromX, glyph.position.x, p)
            } else if let toX = cell.toX {
                glyph.position.x = amountMotionMix(glyph.position.x, toX, p)
            }
            if let column = cell.column, column.count > 1 {
                let pitch = glyph.font.capHeight * 0.8
                let steps = CGFloat(column.count - 1)
                let direction: CGFloat = timing.up ? 1.0 : -1.0
                let open = cell.from == nil ? p : (cell.to == nil ? 1.0 - p : 1.0)
                let pace = pow(1.0 - raw, 1.2)
                for (i, text) in column.enumerated() {
                    let dy = (CGFloat(i) - p * steps) * pitch * direction
                    let k = abs(dy) / (pitch * 0.58)
                    guard k < 1.0, text != " " else { continue }
                    var item = glyph
                    item.text = text
                    item.position.y += dy
                    let travel = (p - was) * steps * pitch * direction
                    let trail = raw == 0.0 ? 0.0 : direction * min(pitch * 1.4, max(abs(travel), glyph.font.capHeight * 0.45 * pace * pace))
                    result.append(WalletSendAmountSprite(glyph: item, alpha: (1.0 - pow(k, 2.2)) * pow(open, 2.2), trail: trail, spread: (1.0 - open) * glyph.font.capHeight * 0.65))
                }
            } else if cell.from?.text == cell.to?.text {
                result.append(WalletSendAmountSprite(glyph: glyph))
            } else {
                if var old = cell.from {
                    old.position = glyph.position
                    result.append(WalletSendAmountSprite(glyph: old, alpha: pow(1.0 - p, 1.2), scale: timing.reduced ? 1.0 : (old.group == .grouping ? 1.0 - p : 1.0 - 0.14 * p)))
                }
                if var new = cell.to {
                    new.position = glyph.position
                    result.append(WalletSendAmountSprite(glyph: new, alpha: pow(p, 1.2), scale: timing.reduced ? 1.0 : (new.group == .grouping ? p : 0.86 + 0.14 * p)))
                }
            }
        }
        return result
    }
}

final class WalletSendAmountCanvas: UIView {
    var sprites: [WalletSendAmountSprite] = [] {
        didSet { self.setNeedsDisplay() }
    }
    var frameDuration: Double = 1.0 / 60.0
    private var paths: [String: CGPath] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.isOpaque = false
        self.isUserInteractionEnabled = false
        self.accessibilityElementsHidden = true
        self.contentMode = .redraw
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        for sprite in self.sprites where sprite.alpha > 0.006 {
            let glyph = sprite.glyph
            let width = (glyph.text as NSString).size(withAttributes: [.font: glyph.font]).width
            let key = "\(glyph.font.fontName):\(glyph.font.pointSize):\(glyph.text)"
            var path = self.paths[key]
            if path == nil {
                let attributed = NSAttributedString(string: glyph.text, attributes: [.font: glyph.font])
                let line = CTLineCreateWithAttributedString(attributed)
                let combined = CGMutablePath()
                for run in CTLineGetGlyphRuns(line) as! [CTRun] {
                    let count = CTRunGetGlyphCount(run)
                    let font = (CTRunGetAttributes(run) as NSDictionary)[kCTFontAttributeName] as! CTFont
                    var glyphs = [CGGlyph](repeating: 0, count: count)
                    var positions = [CGPoint](repeating: .zero, count: count)
                    CTRunGetGlyphs(run, CFRangeMake(0, count), &glyphs)
                    CTRunGetPositions(run, CFRangeMake(0, count), &positions)
                    for i in 0 ..< count {
                        if let outline = CTFontCreatePathForGlyph(font, glyphs[i], nil) {
                            let transform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: positions[i].x, ty: -positions[i].y)
                            combined.addPath(outline, transform: transform)
                        }
                    }
                }
                path = combined
                self.paths[key] = combined
            }
            let span = max(abs(sprite.trail), sprite.spread)
            let density = min(1.0, (1.0 / 90.0) / max(self.frameDuration, 1.0 / 120.0))
            let count = span > 1.0 ? max(3, Int(Double(min(18, 2 + Int(span))) * density)) : 1
            let weights = (0 ..< count).map { i -> CGFloat in
                let k = count == 1 ? 0.0 : CGFloat(i) / CGFloat(count - 1) * 2.0 - 1.0
                return 1.0 - 0.55 * k * k
            }
            let total = weights.reduce(0.0, +)
            for i in 0 ..< count {
                let k = count == 1 ? 1.0 : CGFloat(i) / CGFloat(count - 1)
                context.saveGState()
                context.setAlpha(sprite.alpha * weights[i] / total)
                context.setFillColor(glyph.color.cgColor)
                context.translateBy(x: glyph.position.x + (k - 0.5) * sprite.spread, y: glyph.position.y + (1.0 - k) * sprite.trail - glyph.font.capHeight / 2.0)
                context.scaleBy(x: sprite.scale, y: sprite.scale)
                context.translateBy(x: -width / 2.0, y: glyph.font.capHeight / 2.0)
                if let path {
                    context.addPath(path)
                    context.fillPath()
                }
                context.restoreGState()
            }
        }
    }
}
