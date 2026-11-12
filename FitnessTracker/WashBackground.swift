import AVFoundation
import CoreImage
import SwiftUI
import UIKit

enum WashPlayback {
    /// Full-speed wash behind glass.
    static let rate: Float = 1.0
    static let resourceName = "AdobeStock_621992661"
    static let resourceExtension = "mp4"

    static var screenSize: CGSize {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        return scene?.screen.bounds.size ?? .zero
    }
}

enum WashGrade: Hashable {
    case grayscale
    case thermal
    case purpleOrange
    case redYellow
    case blackGreen

    static func forRoutine(_ id: String) -> WashGrade {
        switch id {
        case "A": return .thermal
        case "B": return .purpleOrange
        case "C": return .redYellow
        case "D": return .blackGreen
        default: return .thermal
        }
    }
}

@Observable
final class WashTheme {
    var grade: WashGrade = .grayscale
}

struct WashBackground: View {
    var grade: WashGrade
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Color.black
            GeometryReader { geo in
                WashPlayerLayer(isActive: !reduceMotion && scenePhase != .background, grade: grade)
                    .frame(width: geo.size.height, height: geo.size.width)
                    .rotationEffect(.degrees(90))
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
                    .clipped()
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct ThermalWashBackground: View {
    var body: some View {
        WashBackground(grade: .thermal)
    }
}

/// Home-tile portal: the full-screen wash, clipped to this view, graded per routine.
struct WashWindow: View {
    var grade: WashGrade
    @Environment(WashTheme.self) private var wash
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { tile in
            let screen = WashPlayback.screenSize
            let frame = tile.frame(in: .global)
            WashPlayerLayer(
                isActive: isActive,
                grade: grade
            )
            .frame(width: screen.height, height: screen.width)
            .rotationEffect(.degrees(90))
            .frame(width: screen.width, height: screen.height, alignment: .center)
            .offset(x: -frame.minX, y: -frame.minY)
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var isActive: Bool {
        !reduceMotion && scenePhase != .background && wash.grade == .grayscale
    }
}

private struct WashPlayerLayer: UIViewRepresentable {
    var isActive: Bool
    var grade: WashGrade

    func makeUIView(context: Context) -> WashPlayerView {
        let view = WashPlayerView()
        view.backgroundColor = .black
        DispatchQueue.main.async {
            view.setGrade(grade)
            view.setActive(isActive)
        }
        return view
    }

    func updateUIView(_ uiView: WashPlayerView, context: Context) {
        DispatchQueue.main.async {
            uiView.setGrade(grade)
            uiView.setActive(isActive)
        }
    }
}

private final class WashPlayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    private var player: AVPlayer?
    private var loopObserver: NSObjectProtocol?
    private var statusObserver: NSKeyValueObservation?
    private var wantsPlayback = false
    private var grade: WashGrade = .thermal
    private var asset: AVURLAsset?

    override init(frame: CGRect) {
        super.init(frame: frame)
        playerLayer.videoGravity = .resizeAspectFill
        backgroundColor = .black
        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let loopObserver {
            NotificationCenter.default.removeObserver(loopObserver)
        }
        statusObserver = nil
        player?.pause()
    }

    func setActive(_ active: Bool) {
        wantsPlayback = active
        applyPlaybackState()
    }

    func setGrade(_ newGrade: WashGrade) {
        if newGrade == grade, player != nil { return }
        grade = newGrade
        rebuild()
    }

    private func applyPlaybackState() {
        guard let player else { return }
        if wantsPlayback {
            player.playImmediately(atRate: WashPlayback.rate)
        } else {
            player.pause()
        }
    }

    private func observe(_ item: AVPlayerItem) {
        statusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard item.status == .readyToPlay else { return }
            DispatchQueue.main.async {
                self?.applyPlaybackState()
            }
        }
        if let loopObserver {
            NotificationCenter.default.removeObserver(loopObserver)
        }
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.player?.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
                guard finished else { return }
                self?.applyPlaybackState()
            }
        }
    }

    private func rebuild() {
        guard let url = Self.videoURL() else { return }
        let asset = AVURLAsset(url: url)
        self.asset = asset
        let mappedGrade = grade
        let colorMap = WashLook.colorMap(for: mappedGrade)
        let contrast: CGFloat = mappedGrade == .grayscale ? 1.7 : 1.35
        let brightness: CGFloat = mappedGrade == .grayscale ? -0.12 : 0.05
        if player == nil {
            let placeholder = AVPlayerItem(asset: asset)
            let player = AVPlayer(playerItem: placeholder)
            player.isMuted = true
            player.actionAtItemEnd = .none
            player.preventsDisplaySleepDuringVideoPlayback = false
            self.player = player
            playerLayer.player = player
            observe(placeholder)
            applyPlaybackState()
        }
        AVVideoComposition.videoComposition(with: asset, applyingCIFiltersWithHandler: { request in
            let source = request.sourceImage.clampedToExtent()
            let contrasted = source.applyingFilter("CIColorControls", parameters: [
                kCIInputContrastKey: contrast,
                kCIInputSaturationKey: 0,
                kCIInputBrightnessKey: brightness,
            ])
            let graded = contrasted.applyingFilter("CIColorMap", parameters: [
                "inputGradientImage": colorMap,
            ])
            request.finish(with: graded.cropped(to: request.sourceImage.extent), context: nil)
        }) { [weak self] composition, _ in
            DispatchQueue.main.async {
                guard let self, self.grade == mappedGrade else { return }
                let item = AVPlayerItem(asset: asset)
                if let composition {
                    item.videoComposition = composition
                }
                if let player = self.player {
                    player.replaceCurrentItem(with: item)
                } else {
                    let player = AVPlayer(playerItem: item)
                    player.isMuted = true
                    player.actionAtItemEnd = .none
                    player.preventsDisplaySleepDuringVideoPlayback = false
                    self.player = player
                    self.playerLayer.player = player
                }
                self.observe(item)
                self.applyPlaybackState()
            }
        }
    }

    private static func videoURL() -> URL? {
        let bundle = Bundle.main
        return bundle.url(
            forResource: WashPlayback.resourceName,
            withExtension: WashPlayback.resourceExtension,
            subdirectory: "background-videos"
        ) ?? bundle.url(forResource: WashPlayback.resourceName, withExtension: WashPlayback.resourceExtension)
    }
}

private enum WashLook {
    static func colorMap(for grade: WashGrade) -> CIImage {
        switch grade {
        case .grayscale: return grayscaleMap
        case .thermal: return thermalMap
        case .purpleOrange: return purpleOrangeMap
        case .redYellow: return redYellowMap
        case .blackGreen: return blackGreenMap
        }
    }

    private static let grayscaleMap = makeColorMap(sampleGray)
    private static let thermalMap = makeColorMap(sampleThermal)
    private static let purpleOrangeMap = makeColorMap(samplePurpleOrange)
    private static let redYellowMap = makeColorMap(sampleRedYellow)
    private static let blackGreenMap = makeColorMap(sampleBlackGreen)

    private static func channel(_ value: Double) -> UInt8 {
        UInt8(clamping: Int((min(max(value, 0), 1) * 255).rounded()))
    }

    private static func makeColorMap(_ sample: (Double) -> (Double, Double, Double)) -> CIImage {
        let width = 256
        var pixels = [UInt8](repeating: 255, count: width * 4)
        for x in 0..<width {
            let color = sample(Double(x) / 255)
            pixels[x * 4 + 0] = channel(color.0)
            pixels[x * 4 + 1] = channel(color.1)
            pixels[x * 4 + 2] = channel(color.2)
            pixels[x * 4 + 3] = 255
        }
        let space = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: &pixels,
            width: width,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        guard let image = context?.makeImage() else {
            return CIImage(color: .black)
        }
        return CIImage(cgImage: image)
    }

    private static func lerp(
        _ t: Double,
        _ stops: [(Double, (Double, Double, Double))]
    ) -> (Double, Double, Double) {
        let t = min(max(t, 0), 1)
        for index in 0..<(stops.count - 1) {
            let start = stops[index]
            let end = stops[index + 1]
            if t >= start.0, t <= end.0 {
                let span = end.0 - start.0
                let u = span == 0 ? 0 : (t - start.0) / span
                return (
                    start.1.0 + (end.1.0 - start.1.0) * u,
                    start.1.1 + (end.1.1 - start.1.1) * u,
                    start.1.2 + (end.1.2 - start.1.2) * u
                )
            }
        }
        return stops.last!.1
    }

    private static let white: (Double, Double, Double) = (1.00, 1.00, 1.00)

    /// Dark primary holds, bright secondary hits, then snaps to pure white.
    private static func triple(
        primary: (Double, Double, Double),
        secondary: (Double, Double, Double)
    ) -> (Double) -> (Double, Double, Double) {
        { t in
            lerp(t, [
                (0.00, primary),
                (0.40, primary),
                (0.68, secondary),
                (0.78, secondary),
                (0.86, white),
                (1.00, white),
            ])
        }
    }

    private static func sampleGray(_ t: Double) -> (Double, Double, Double) {
        triple(primary: (0.00, 0.00, 0.00), secondary: (0.52, 0.52, 0.55))(t)
    }

    /// Blue primary, lime secondary, white tertiary.
    private static func sampleThermal(_ t: Double) -> (Double, Double, Double) {
        triple(primary: (0.02, 0.38, 1.00), secondary: (1.00, 0.95, 0.05))(t)
    }

    /// Deep purple primary, orange secondary, white tertiary.
    private static func samplePurpleOrange(_ t: Double) -> (Double, Double, Double) {
        triple(primary: (0.36, 0.00, 0.62), secondary: (1.00, 0.48, 0.00))(t)
    }

    /// Red primary, yellow secondary, white tertiary.
    private static func sampleRedYellow(_ t: Double) -> (Double, Double, Double) {
        triple(primary: (0.92, 0.04, 0.04), secondary: (1.00, 0.92, 0.05))(t)
    }

    /// Black primary, green secondary, white tertiary.
    private static func sampleBlackGreen(_ t: Double) -> (Double, Double, Double) {
        triple(primary: (0.00, 0.00, 0.00), secondary: (0.12, 1.00, 0.18))(t)
    }
}
