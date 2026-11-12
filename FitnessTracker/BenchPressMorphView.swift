import SwiftUI
import UIKit

/// Morphs the three Dumbbell Bench Press frames instead of swapping SVGs.
///
/// The source drawings do not share path topology, so a true path interpolator
/// is not possible. Frames are aligned to a shared 256 canvas by the lower-body
/// (torso/bench) centroid. Between frames 2 and 3 — similar stroke layout —
/// pixels travel with nearest-neighbor interpolation. Between frames 1 and 2 the
/// torso and bench stay locked to frame 2 and only the arms/weights crossfade
/// (those drawings cannot correspond cleanly).
struct BenchPressMorphView: UIViewRepresentable {
    let slugs: [String]
    let label: String

    func makeUIView(context: Context) -> BenchPressMorphUIView {
        let view = BenchPressMorphUIView()
        view.accessibilityLabel = label
        view.load(slugs: slugs)
        return view
    }

    func updateUIView(_ uiView: BenchPressMorphUIView, context: Context) {
        uiView.accessibilityLabel = label
    }
}

final class BenchPressMorphUIView: UIView {
    private let imageView = UIImageView()
    private var displayLink: CADisplayLink?
    private var startedAt: CFTimeInterval = 0

    private let canvasSize = 256
    private let chestY = 100
    private let segmentDuration: CFTimeInterval = 0.72

    private var body: [SIMD2<Int16>] = []
    private var arms1: [SIMD2<Int16>] = []
    private var arms2: [SIMD2<Int16>] = []
    private var full2: [SIMD2<Int16>] = []
    private var full3: [SIMD2<Int16>] = []
    private var map23: [Int] = []
    private var map32: [Int] = []
    private var ready = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = true
        accessibilityTraits = .image
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .white
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        displayLink?.invalidate()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            displayLink?.invalidate()
            displayLink = nil
        } else if ready, displayLink == nil {
            startAnimating()
        }
    }

    func load(slugs: [String]) {
        let names = slugs
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.prepare(slugs: names)
        }
    }

    private func prepare(slugs: [String]) {
        let images = slugs.compactMap { UIImage(named: $0) }
        guard images.count == 3 else { return }

        let size = canvasSize
        let masks = images.map { Self.alphaMask(from: $0, size: size) }
        let aligned = masks.map { Self.alignToLowerCentroid($0, size: size) }

        func points(_ mask: [UInt8], where predicate: (Int, Int) -> Bool) -> [SIMD2<Int16>] {
            var pts: [SIMD2<Int16>] = []
            pts.reserveCapacity(4096)
            for y in 0..<size {
                for x in 0..<size {
                    if mask[y * size + x] > 40, predicate(x, y) {
                        pts.append(SIMD2(Int16(x), Int16(y)))
                    }
                }
            }
            return pts
        }

        let bodyPts = points(aligned[1]) { _, y in y >= chestY }
        let a1 = points(aligned[0]) { _, y in y < chestY }
        let a2 = points(aligned[1]) { _, y in y < chestY }
        let f2 = points(aligned[1]) { _, _ in true }
        let f3 = points(aligned[2]) { _, _ in true }
        let m23 = Self.nearestMap(from: f2, to: f3, size: size)
        let m32 = Self.nearestMap(from: f3, to: f2, size: size)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.body = bodyPts
            self.arms1 = a1
            self.arms2 = a2
            self.full2 = f2
            self.full3 = f3
            self.map23 = m23
            self.map32 = m32
            self.ready = true
            self.imageView.image = self.frameImage(phase: 0)
            if self.window != nil {
                self.startAnimating()
            }
        }
    }

    private func startAnimating() {
        displayLink?.invalidate()
        startedAt = 0
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func tick(_ link: CADisplayLink) {
        if startedAt == 0 {
            startedAt = link.timestamp
        }
        let elapsed = link.timestamp - startedAt
        let cycle = segmentDuration * 4
        let unit = elapsed.truncatingRemainder(dividingBy: cycle) / segmentDuration
        imageView.image = frameImage(phase: unit)
    }

    private func frameImage(phase: CFTimeInterval) -> UIImage {
        let t: CGFloat
        let alpha = [UInt8](repeating: 0, count: canvasSize * canvasSize)
        var buffer = alpha
        if phase < 1 {
            t = Self.smooth(phase)
            composeLockedArms(t: t, into: &buffer)
        } else if phase < 2 {
            t = Self.smooth(phase - 1)
            composeTravel(from: full2, to: full3, ab: map23, ba: map32, t: t, into: &buffer)
        } else if phase < 3 {
            t = Self.smooth(phase - 2)
            composeTravel(from: full3, to: full2, ab: map32, ba: map23, t: t, into: &buffer)
        } else {
            t = Self.smooth(phase - 3)
            composeLockedArms(t: 1 - t, into: &buffer)
        }
        return Self.templateImage(alpha: buffer, size: canvasSize)
    }

    private func composeLockedArms(t: CGFloat, into buffer: inout [UInt8]) {
        stamp(body, alpha: 255, into: &buffer)
        let a1 = UInt8(max(0, min(255, Int((1 - t) * 255))))
        let a2 = UInt8(max(0, min(255, Int(t * 255))))
        stamp(arms1, alpha: a1, into: &buffer)
        stamp(arms2, alpha: a2, into: &buffer)
    }

    private func composeTravel(
        from src: [SIMD2<Int16>],
        to dst: [SIMD2<Int16>],
        ab: [Int],
        ba: [Int],
        t: CGFloat,
        into buffer: inout [UInt8]
    ) {
        let u = Float(t)
        if !src.isEmpty, !ab.isEmpty {
            for i in src.indices {
                let a = src[i]
                let b = dst[ab[i]]
                stamp(
                    x: CGFloat(a.x) + CGFloat(Float(b.x) - Float(a.x)) * CGFloat(u),
                    y: CGFloat(a.y) + CGFloat(Float(b.y) - Float(a.y)) * CGFloat(u),
                    alpha: 255,
                    into: &buffer
                )
            }
        }
        if !dst.isEmpty, !ba.isEmpty {
            for i in dst.indices {
                let b = dst[i]
                let a = src[ba[i]]
                stamp(
                    x: CGFloat(a.x) + CGFloat(Float(b.x) - Float(a.x)) * CGFloat(u),
                    y: CGFloat(a.y) + CGFloat(Float(b.y) - Float(a.y)) * CGFloat(u),
                    alpha: 255,
                    into: &buffer
                )
            }
        }
    }

    private func stamp(_ points: [SIMD2<Int16>], alpha: UInt8, into buffer: inout [UInt8]) {
        guard alpha > 0 else { return }
        for p in points {
            stamp(x: CGFloat(p.x), y: CGFloat(p.y), alpha: alpha, into: &buffer)
        }
    }

    private func stamp(x: CGFloat, y: CGFloat, alpha: UInt8, into buffer: inout [UInt8]) {
        let xi = Int(x.rounded())
        let yi = Int(y.rounded())
        let size = canvasSize
        for dy in -1...1 {
            for dx in -1...1 {
                let xx = xi + dx
                let yy = yi + dy
                if xx >= 0, yy >= 0, xx < size, yy < size {
                    let i = yy * size + xx
                    if alpha > buffer[i] {
                        buffer[i] = alpha
                    }
                }
            }
        }
    }

    private static func smooth(_ t: CFTimeInterval) -> CGFloat {
        let x = min(1, max(0, CGFloat(t)))
        return x * x * (3 - 2 * x)
    }

    private static func alphaMask(from image: UIImage, size: Int) -> [UInt8] {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)
        let drawn = renderer.image { _ in
            image.draw(in: CGRect(x: 0, y: 0, width: size, height: size))
        }
        guard let cg = drawn.cgImage else {
            return [UInt8](repeating: 0, count: size * size)
        }
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        let space = CGColorSpaceCreateDeviceRGB()
        pixels.withUnsafeMutableBytes { raw in
            guard let ctx = CGContext(
                data: raw.baseAddress,
                width: size,
                height: size,
                bitsPerComponent: 8,
                bytesPerRow: size * 4,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: size, height: size))
        }
        var mask = [UInt8](repeating: 0, count: size * size)
        for i in 0..<(size * size) {
            mask[i] = pixels[i * 4 + 3]
        }
        return mask
    }

    private static func alignToLowerCentroid(_ mask: [UInt8], size: Int) -> [UInt8] {
        var minX = size, minY = size, maxX = 0, maxY = 0
        for y in 0..<size {
            for x in 0..<size {
                if mask[y * size + x] > 40 {
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }
        guard maxX >= minX else { return mask }
        let split = minY + Int(0.62 * Double(maxY - minY))
        var sx = 0, sy = 0, n = 0
        for y in split...maxY {
            for x in minX...maxX {
                if mask[y * size + x] > 40 {
                    sx += x
                    sy += y
                    n += 1
                }
            }
        }
        guard n > 0 else { return mask }
        let dx = 128 - sx / n
        let dy = 168 - sy / n
        var out = [UInt8](repeating: 0, count: size * size)
        for y in 0..<size {
            for x in 0..<size {
                let v = mask[y * size + x]
                if v > 40 {
                    let nx = x + dx
                    let ny = y + dy
                    if nx >= 0, ny >= 0, nx < size, ny < size {
                        out[ny * size + nx] = v
                    }
                }
            }
        }
        return out
    }

    private static func nearestMap(from src: [SIMD2<Int16>], to dst: [SIMD2<Int16>], size: Int) -> [Int] {
        var occ = [Int](repeating: -1, count: size * size)
        for (i, p) in dst.enumerated() {
            occ[Int(p.y) * size + Int(p.x)] = i
        }
        var map = [Int](repeating: 0, count: src.count)
        for (si, p) in src.enumerated() {
            let px = Int(p.x)
            let py = Int(p.y)
            var found = 0
            loop: for r in 0..<size {
                let x0 = max(0, px - r)
                let x1 = min(size - 1, px + r)
                let y0 = max(0, py - r)
                let y1 = min(size - 1, py + r)
                var best = -1
                var bestD = Int.max
                func consider(_ x: Int, _ y: Int) {
                    let j = occ[y * size + x]
                    if j < 0 { return }
                    let d = (x - px) * (x - px) + (y - py) * (y - py)
                    if d < bestD {
                        bestD = d
                        best = j
                    }
                }
                for x in x0...x1 {
                    consider(x, y0)
                    if r > 0 { consider(x, y1) }
                }
                if r > 0 {
                    if y1 > y0 + 1 {
                        for y in (y0 + 1)..<y1 {
                            consider(x0, y)
                            consider(x1, y)
                        }
                    }
                }
                if best >= 0 {
                    found = best
                    break loop
                }
            }
            map[si] = found
        }
        return map
    }

    private static func templateImage(alpha: [UInt8], size: Int) -> UIImage {
        var rgba = [UInt8](repeating: 0, count: size * size * 4)
        for i in 0..<(size * size) {
            let a = alpha[i]
            let o = i * 4
            rgba[o] = a
            rgba[o + 1] = a
            rgba[o + 2] = a
            rgba[o + 3] = a
        }
        let space = CGColorSpaceCreateDeviceRGB()
        let image: CGImage? = rgba.withUnsafeMutableBytes { raw in
            guard let ctx = CGContext(
                data: raw.baseAddress,
                width: size,
                height: size,
                bitsPerComponent: 8,
                bytesPerRow: size * 4,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return nil }
            return ctx.makeImage()
        }
        guard let image else {
            return UIImage()
        }
        return UIImage(cgImage: image, scale: 1, orientation: .up).withRenderingMode(.alwaysTemplate)
    }
}
