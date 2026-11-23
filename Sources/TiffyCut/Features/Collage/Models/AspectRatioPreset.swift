import CoreGraphics
import Foundation

public enum AspectRatioPreset: String, CaseIterable, Identifiable, Codable {
    case tiktok9x16 = "9:16"
    case igPortrait4x5 = "4:5"
    case square1x1 = "1:1"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .tiktok9x16: return "9:16"
        case .igPortrait4x5: return "4:5"
        case .square1x1: return "1:1"
        }
    }

    public var subtitle: String {
        switch self {
        case .tiktok9x16: return "TikTok / Reels"
        case .igPortrait4x5: return "IG Feed"
        case .square1x1: return "Square"
        }
    }

    /// Output pixel dimensions (1080p standard for TikTok & Instagram).
    public var renderSize: CGSize {
        switch self {
        case .tiktok9x16: return CGSize(width: 1080, height: 1920)
        case .igPortrait4x5: return CGSize(width: 1080, height: 1350)
        case .square1x1: return CGSize(width: 1080, height: 1080)
        }
    }

    public var ratio: CGFloat {
        renderSize.width / renderSize.height
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
