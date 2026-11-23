import CoreGraphics
import Foundation

public enum MediaKind: String, Codable, Equatable {
    case video
    case audio
    case image
}

public struct MediaItem: Identifiable, Equatable, Codable {
    public let id: UUID
    public var url: URL
    public var name: String
    public var kind: MediaKind
    public var duration: Double
    public var naturalSize: CGSize
    public var hasAudio: Bool

    public init(
        id: UUID = UUID(),
        url: URL,
        name: String? = nil,
        kind: MediaKind,
        duration: Double,
        naturalSize: CGSize = .zero,
        hasAudio: Bool = false
    ) {
        self.id = id
        self.url = url
        self.name = name ?? url.lastPathComponent
        self.kind = kind
        self.duration = duration
        self.naturalSize = naturalSize
        self.hasAudio = hasAudio
    }
}

public enum TrackKind: String, Codable, Equatable {
    case mainVideo
    case overlayVideo
    case text
    case audio
}

public enum FilterPreset: String, CaseIterable, Identifiable, Codable {
    case none = "ปกติ"
    case vivid = "สดใส"
    case warm = "โทนอุ่น"
    case cool = "โทนเย็น"
    case bw = "ขาว-ดำ"
    case cinematic = "ภาพยนตร์"
    case fade = "ฟิล์มฟุ้ง"

    public var id: String { rawValue }
}

public enum TransitionType: String, CaseIterable, Identifiable, Codable {
    case none = "ไม่มี"
    case crossDissolve = "จางซ้อน"
    case fadeBlack = "เฟดดำ"
    case slideLeft = "เลื่อนซ้าย"
    case zoomIn = "ซูมเข้า"

    public var id: String { rawValue }
}

public struct ColorAdjustments: Equatable, Codable, Sendable {
    public var brightness: Double = 0.0   // -0.5 ... 0.5
    public var contrast: Double = 1.0     // 0.5 ... 1.5
    public var saturation: Double = 1.0   // 0.0 ... 2.0
    public var exposure: Double = 0.0     // -2.0 ... 2.0
    public var temperature: Double = 0.0  // -1.0 ... 1.0
    public var filter: FilterPreset = .none

    public init() {}

    public var isDefault: Bool {
        abs(brightness) < 0.001 &&
        abs(contrast - 1.0) < 0.001 &&
        abs(saturation - 1.0) < 0.001 &&
        abs(exposure) < 0.001 &&
        abs(temperature) < 0.001 &&
        filter == .none
    }
}

public struct TextOverlayStyle: Equatable, Codable, Sendable {
    public var text: String = "พิมพ์ข้อความที่นี่"
    public var fontSize: CGFloat = 64
    public var isBold: Bool = true
    public var textColorHex: String = "#FFFFFF"
    public var backgroundColorHex: String = "#000000"
    public var backgroundOpacity: Double = 0.45
    public var hasShadow: Bool = true

    public init(text: String = "พิมพ์ข้อความที่นี่") {
        self.text = text
    }
}

public struct TimelineClip: Identifiable, Equatable, Codable {
    public let id: UUID
    public var trackKind: TrackKind
    public var mediaID: UUID?
    public var mediaURL: URL?
    public var mediaKind: MediaKind?
    public var title: String

    /// Position on the timeline (seconds).
    public var startTime: Double
    /// Source media trim start (seconds).
    public var sourceStart: Double
    /// Source media duration used before speed scaling (seconds).
    public var sourceDuration: Double
    /// Full original media duration (seconds).
    public var fullMediaDuration: Double

    /// Playback speed multiplier (0.25 ... 4.0).
    public var speed: Double = 1.0

    // Visual Transform (normalized to canvas)
    public var scale: CGFloat = 1.0
    public var positionX: CGFloat = 0.0 // -1 ... 1
    public var positionY: CGFloat = 0.0 // -1 ... 1
    public var rotationDegrees: Double = 0.0
    public var opacity: Double = 1.0
    public var isFlippedHorizontal: Bool = false

    // Audio
    public var volume: Float = 1.0      // 0 ... 2.0
    public var isMuted: Bool = false
    public var fadeInDuration: Double = 0.0
    public var fadeOutDuration: Double = 0.0

    // Color & Transition
    public var adjustments: ColorAdjustments = ColorAdjustments()
    public var transitionIn: TransitionType = .none
    public var transitionDuration: Double = 0.5

    // Text
    public var textStyle: TextOverlayStyle?

    public init(
        id: UUID = UUID(),
        trackKind: TrackKind,
        mediaID: UUID? = nil,
        mediaURL: URL? = nil,
        mediaKind: MediaKind? = nil,
        title: String,
        startTime: Double,
        sourceStart: Double = 0,
        sourceDuration: Double,
        fullMediaDuration: Double? = nil,
        textStyle: TextOverlayStyle? = nil
    ) {
        self.id = id
        self.trackKind = trackKind
        self.mediaID = mediaID
        self.mediaURL = mediaURL
        self.mediaKind = mediaKind
        self.title = title
        self.startTime = max(0, startTime)
        self.sourceStart = max(0, sourceStart)
        self.sourceDuration = max(0.1, sourceDuration)
        self.fullMediaDuration = fullMediaDuration ?? sourceDuration
        self.textStyle = textStyle
    }

    /// Effective duration occupied on the timeline after speed scaling.
    public var duration: Double {
        let safeSpeed = max(0.25, min(4.0, speed))
        return max(0.1, sourceDuration / safeSpeed)
    }

    public var endTime: Double {
        startTime + duration
    }
}

public enum ExportResolution: String, CaseIterable, Identifiable, Codable {
    case p720 = "720p"
    case p1080 = "1080p"
    case p2K = "2K"
    case p4K = "4K"

    public var id: String { rawValue }

    public var shortSidePixels: Int {
        switch self {
        case .p720: return 720
        case .p1080: return 1080
        case .p2K: return 1440
        case .p4K: return 2160
        }
    }
}

public enum ExportCodec: String, CaseIterable, Identifiable, Codable {
    case h264 = "H.264"
    case hevc = "HEVC (H.265)"

    public var id: String { rawValue }
}

public struct EditorExportSettings: Equatable, Codable {
    public var fileName: String = "tiffy-cut-video"
    public var resolution: ExportResolution = .p1080
    public var frameRate: Int32 = 30
    public var codec: ExportCodec = .h264

    public init() {}
}

public struct TimelineSnapshot: Codable, Equatable {
    public var projectID: UUID
    public var projectName: String
    public var aspectRatio: AspectRatioPreset
    public var customWidth: Int
    public var customHeight: Int
    public var mediaItems: [MediaItem]
    public var clips: [TimelineClip]
    public var updatedAt: Date

    public init(
        projectID: UUID,
        projectName: String,
        aspectRatio: AspectRatioPreset,
        customWidth: Int,
        customHeight: Int,
        mediaItems: [MediaItem],
        clips: [TimelineClip],
        updatedAt: Date = Date()
    ) {
        self.projectID = projectID
        self.projectName = projectName
        self.aspectRatio = aspectRatio
        self.customWidth = customWidth
        self.customHeight = customHeight
        self.mediaItems = mediaItems
        self.clips = clips
        self.updatedAt = updatedAt
    }
}
