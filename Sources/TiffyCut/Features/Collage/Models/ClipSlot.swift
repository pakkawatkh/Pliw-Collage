import CoreGraphics
import Foundation

public struct ClipSlot: Identifiable, Equatable {
    public let id: Int
    public var url: URL?
    public var duration: Double = 0
    public var naturalSize: CGSize = .zero
    public var preferredTransform: CGAffineTransform = .identity
    public var hasAudio: Bool = false

    public var trimStart: Double = 0
    public var trimEnd: Double = 0
    public var isMuted: Bool = false
    public var volume: Float = 1.0

    /// Zoom multiplier (>= 1.0). 1.0 means standard aspect-fill.
    public var scale: CGFloat = 1.0
    /// Normalized pan offset in [-1...1], where 0 is centered.
    public var offsetX: CGFloat = 0.0
    public var offsetY: CGFloat = 0.0

    public init(id: Int) {
        self.id = id
    }

    public var hasVideo: Bool {
        url != nil && duration > 0
    }

    public var fileName: String {
        url?.lastPathComponent ?? "Empty Slot"
    }

    /// Effective trimmed duration in seconds (clamped to >= 0.1 when video exists).
    public var trimmedDuration: Double {
        guard hasVideo else { return 0 }
        let start = max(0, min(trimStart, duration))
        let end = max(start, min(trimEnd > 0 ? trimEnd : duration, duration))
        return max(0.1, end - start)
    }

    /// Display size after applying preferredTransform.
    public var orientedSize: CGSize {
        guard naturalSize.width > 0 && naturalSize.height > 0 else { return .zero }
        let rect = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
        return CGSize(width: abs(rect.width), height: abs(rect.height))
    }

    public mutating func resetFraming() {
        scale = 1.0
        offsetX = 0.0
        offsetY = 0.0
    }

    public mutating func clear() {
        url = nil
        duration = 0
        naturalSize = .zero
        preferredTransform = .identity
        hasAudio = false
        trimStart = 0
        trimEnd = 0
        isMuted = false
        volume = 1.0
        resetFraming()
    }
}
