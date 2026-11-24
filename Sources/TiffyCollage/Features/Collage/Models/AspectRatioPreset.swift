import CoreGraphics
import Foundation

public enum AspectRatioPreset: String, CaseIterable, Identifiable, Codable {
    case tiktok9x16 = "9:16"
    case igPortrait4x5 = "4:5"
    case square1x1 = "1:1"
    case landscape16x9 = "16:9"
    case custom = "custom"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .tiktok9x16: return "9:16"
        case .igPortrait4x5: return "4:5"
        case .square1x1: return "1:1"
        case .landscape16x9: return "16:9"
        case .custom: return "กำหนดเอง"
        }
    }

    public var subtitle: String {
        switch self {
        case .tiktok9x16: return "TikTok"
        case .igPortrait4x5: return "IG Feed"
        case .square1x1: return "Square"
        case .landscape16x9: return "YouTube"
        case .custom: return "Custom"
        }
    }

    /// Default output pixel dimensions for built-in presets.
    public var renderSize: CGSize {
        switch self {
        case .tiktok9x16: return CGSize(width: 1080, height: 1920)
        case .igPortrait4x5: return CGSize(width: 1080, height: 1350)
        case .square1x1: return CGSize(width: 1080, height: 1080)
        case .landscape16x9: return CGSize(width: 1920, height: 1080)
        case .custom: return CGSize(width: 1080, height: 1920)
        }
    }

    public var ratio: CGFloat {
        renderSize.width / renderSize.height
    }
}

/// Utilities for sanitizing custom video dimensions to valid even H.264 pixel sizes.
public enum CanvasDimensionHelper {
    public static let minDimension: Int = 320
    public static let maxDimension: Int = 3840

    /// Clamps width and height to [320...3840] and rounds to even numbers required by H.264.
    public static func sanitizedSize(width: Int, height: Int) -> CGSize {
        let clampedW = max(minDimension, min(maxDimension, width))
        let clampedH = max(minDimension, min(maxDimension, height))
        let evenW = max(minDimension, (clampedW / 2) * 2)
        let evenH = max(minDimension, (clampedH / 2) * 2)
        return CGSize(width: evenW, height: evenH)
    }

    /// Computes even pixel dimensions for an arbitrary aspect ratio `ratioW : ratioH`,
    /// targeting `baseShortSide` (default 1080px) on the shorter side while keeping the
    /// longer side within `maxDimension`.
    public static func sizeForAspectRatio(
        ratioW: Int,
        ratioH: Int,
        baseShortSide: Int = 1080
    ) -> CGSize {
        let safeW = max(1, min(99, ratioW))
        let safeH = max(1, min(99, ratioH))
        let base = Double(max(minDimension, min(2160, baseShortSide)))

        var w: Double
        var h: Double
        if safeW <= safeH {
            w = base
            h = base * (Double(safeH) / Double(safeW))
        } else {
            h = base
            w = base * (Double(safeW) / Double(safeH))
        }

        let maxSide = Double(maxDimension)
        if max(w, h) > maxSide {
            let scale = maxSide / max(w, h)
            w *= scale
            h *= scale
        }

        return sanitizedSize(width: Int(w.rounded()), height: Int(h.rounded()))
    }
}

public enum DurationMode: String, CaseIterable, Identifiable, Codable {
    case shortest
    case longestLoop

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .shortest: return "Shortest Clip"
        case .longestLoop: return "Longest (Loop)"
        }
    }

    public var description: String {
        switch self {
        case .shortest: return "จบตามคลิปที่สั้นที่สุด"
        case .longestLoop: return "เล่นจนจบคลิปยาวสุด (คลิปสั้นวนลูป)"
        }
    }
}
