import AppKit
import AVFoundation
import SwiftUI

/// Renders an AVPlayer inside a clipped container with exact aspect-fill, zoom, and pan
/// matching the CoreImage export pipeline.
public struct SlotVideoPlayerView: NSViewRepresentable {
    public let player: AVPlayer
    public let orientedSize: CGSize
    public let scale: CGFloat
    public let offsetX: CGFloat
    public let offsetY: CGFloat

    public init(
        player: AVPlayer,
        orientedSize: CGSize,
        scale: CGFloat,
        offsetX: CGFloat,
        offsetY: CGFloat
    ) {
        self.player = player
        self.orientedSize = orientedSize
        self.scale = scale
        self.offsetX = offsetX
        self.offsetY = offsetY
    }

    public func makeNSView(context: Context) -> PlayerContainerNSView {
        let view = PlayerContainerNSView()
        view.update(
            player: player,
            orientedSize: orientedSize,
            scale: scale,
            offsetX: offsetX,
            offsetY: offsetY
        )
        return view
    }

    public func updateNSView(_ nsView: PlayerContainerNSView, context: Context) {
        nsView.update(
            player: player,
            orientedSize: orientedSize,
            scale: scale,
            offsetX: offsetX,
            offsetY: offsetY
        )
    }
}

public final class PlayerContainerNSView: NSView {
    private let playerLayer = AVPlayerLayer()
    private var orientedSize: CGSize = .zero
    private var zoomScale: CGFloat = 1.0
    private var offsetX: CGFloat = 0.0
    private var offsetY: CGFloat = 0.0

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
        playerLayer.videoGravity = .resize
        layer?.addSublayer(playerLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func update(
        player: AVPlayer,
        orientedSize: CGSize,
        scale: CGFloat,
        offsetX: CGFloat,
        offsetY: CGFloat
    ) {
        if playerLayer.player !== player {
            playerLayer.player = player
        }
        self.orientedSize = orientedSize
        self.zoomScale = max(1.0, scale)
        self.offsetX = max(-1.0, min(1.0, offsetX))
        self.offsetY = max(-1.0, min(1.0, offsetY))
        needsLayout = true
        layoutSublayers()
    }

    public override func layout() {
        super.layout()
        layoutSublayers()
    }

    private func layoutSublayers() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let bounds = self.bounds
        guard bounds.width > 0, bounds.height > 0 else {
            CATransaction.commit()
            return
        }

        guard orientedSize.width > 0, orientedSize.height > 0 else {
            playerLayer.frame = bounds
            CATransaction.commit()
            return
        }

        let baseScale = max(bounds.width / orientedSize.width, bounds.height / orientedSize.height)
        let finalScale = baseScale * zoomScale
        let scaledW = orientedSize.width * finalScale
        let scaledH = orientedSize.height * finalScale

        let maxPanX = max(0, (scaledW - bounds.width) / 2.0)
        let maxPanY = max(0, (scaledH - bounds.height) / 2.0)

        // NSView default coordinate system is bottom-left (same as CoreImage):
        // positive UI offsetY (drag down) shifts frame downward (-Y).
        let panX = offsetX * maxPanX
        let panY = -offsetY * maxPanY

        let originX = (bounds.width - scaledW) / 2.0 + panX
        let originY = (bounds.height - scaledH) / 2.0 + panY

        playerLayer.frame = CGRect(x: originX, y: originY, width: scaledW, height: scaledH)
        CATransaction.commit()
    }
}
