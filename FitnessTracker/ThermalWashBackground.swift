import AVFoundation
import CoreImage
import SwiftUI
import UIKit

enum WashPlayback {
    /// Full-speed wash behind glass.
    static let rate: Float = 1.0
    static let resourceName = "AdobeStock_621992661"
    static let resourceExtension = "mp4"
}

struct ThermalWashBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geo in
            ThermalPlayerLayer(isActive: !reduceMotion && scenePhase == .active)
                .frame(width: geo.size.height, height: geo.size.width)
                .rotationEffect(.degrees(90))
                .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
                .clipped()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct ThermalPlayerLayer: UIViewRepresentable {
    var isActive: Bool

    func makeUIView(context: Context) -> ThermalPlayerView {
        let view = ThermalPlayerView()
        view.setActive(isActive)
        return view
    }

    func updateUIView(_ uiView: ThermalPlayerView, context: Context) {
        uiView.setActive(isActive)
    }
}

private final class ThermalPlayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    private var player: AVPlayer?
    private var loopObserver: NSObjectProtocol?
    private var statusObserver: NSKeyValueObservation?
    private var wantsPlayback = false
    private var didLoad = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        playerLayer.videoGravity = .resizeAspectFill
        backgroundColor = .black
        isUserInteractionEnabled = false
        loadIfNeeded()
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
        loadIfNeeded()
        wantsPlayback = active
        applyPlaybackState()
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

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        guard let url = Self.videoURL() else { return }

        let asset = AVURLAsset(url: url)
        AVVideoComposition.videoComposition(with: asset, applyingCIFiltersWithHandler: { request in
            let source = request.sourceImage.clampedToExtent()
            let contrasted = source.applyingFilter("CIColorControls", parameters: [
                kCIInputContrastKey: 1.35,
                kCIInputSaturationKey: 0,
                kCIInputBrightnessKey: 0.05,
            ])
            let mapped = contrasted.applyingFilter("CIColorMap", parameters: [
                "inputGradientImage": ThermalLook.colorMap,
            ])
            request.finish(with: mapped.cropped(to: request.sourceImage.extent), context: nil)
        }) { [weak self] composition, error in
            DispatchQueue.main.async {
                guard let self else { return }
                let item = AVPlayerItem(asset: asset)
                if let composition {
                    item.videoComposition = composition
                }
                let player = AVPlayer(playerItem: item)
                player.isMuted = true
                player.actionAtItemEnd = .none
                player.preventsDisplaySleepDuringVideoPlayback = false
                self.player = player
                self.playerLayer.player = player
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

private enum ThermalLook {
    static let colorMap: CIImage = makeColorMap()

    private static func makeColorMap() -> CIImage {
        let width = 256
        var pixels = [UInt8](repeating: 255, count: width * 4)
        for x in 0..<width {
            let color = sample(Double(x) / 255)
            pixels[x * 4 + 0] = UInt8((color.r * 255).rounded())
            pixels[x * 4 + 1] = UInt8((color.g * 255).rounded())
            pixels[x * 4 + 2] = UInt8((color.b * 255).rounded())
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

    /// Black / blue cold → yellow → white-hot.
    private static func sample(_ t: Double) -> (r: Double, g: Double, b: Double) {
        let stops: [(Double, (Double, Double, Double))] = [
            (0.00, (0.00, 0.00, 0.00)),
            (0.18, (0.00, 0.04, 0.42)),
            (0.38, (0.02, 0.38, 1.00)),
            (0.58, (0.15, 0.85, 0.95)),
            (0.72, (1.00, 0.95, 0.05)),
            (0.88, (1.00, 1.00, 0.72)),
            (1.00, (1.00, 1.00, 1.00)),
        ]
        let t = min(max(t, 0), 1)
        for index in 0..<(stops.count - 1) {
            let start = stops[index]
            let end = stops[index + 1]
            if t >= start.0, t <= end.0 {
                let span = end.0 - start.0
                let u = span == 0 ? 0 : (t - start.0) / span
                return (
                    r: start.1.0 + (end.1.0 - start.1.0) * u,
                    g: start.1.1 + (end.1.1 - start.1.1) * u,
                    b: start.1.2 + (end.1.2 - start.1.2) * u
                )
            }
        }
        return stops.last!.1
    }
}
