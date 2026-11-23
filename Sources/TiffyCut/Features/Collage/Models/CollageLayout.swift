import CoreGraphics
import Foundation

/// A collage template defined by normalized [0...1] slot rectangles in top-left origin space.
public enum CollageLayout: String, CaseIterable, Identifiable, Codable {
    case splitVertical
    case splitHorizontal
    case threeRows
    case threeTopBig
    case threeBottomBig
    case threeColumns
    case grid2x2
    case fourRows

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .splitVertical: return "2 บน-ล่าง"
        case .splitHorizontal: return "2 ซ้าย-ขวา"
        case .threeRows: return "3 แถว"
        case .threeTopBig: return "3 บนใหญ่"
        case .threeBottomBig: return "3 ล่างใหญ่"
        case .threeColumns: return "3 คอลัมน์"
        case .grid2x2: return "4 ช่อง (2×2)"
        case .fourRows: return "4 แถว"
        }
    }

    public var slotCount: Int {
        normalizedRects.count
    }

    /// Normalized rectangles in top-left origin [0...1] space.
    public var normalizedRects: [CGRect] {
        switch self {
        case .splitVertical:
            return [
                CGRect(x: 0, y: 0, width: 1, height: 0.5),
                CGRect(x: 0, y: 0.5, width: 1, height: 0.5)
            ]
        case .splitHorizontal:
            return [
                CGRect(x: 0, y: 0, width: 0.5, height: 1),
                CGRect(x: 0.5, y: 0, width: 0.5, height: 1)
            ]
        case .threeRows:
            let h = 1.0 / 3.0
            return [
                CGRect(x: 0, y: 0, width: 1, height: h),
                CGRect(x: 0, y: h, width: 1, height: h),
                CGRect(x: 0, y: h * 2, width: 1, height: h)
            ]
        case .threeTopBig:
            return [
                CGRect(x: 0, y: 0, width: 1, height: 0.5),
                CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5),
                CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5)
            ]
        case .threeBottomBig:
            return [
                CGRect(x: 0, y: 0, width: 0.5, height: 0.5),
                CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5),
                CGRect(x: 0, y: 0.5, width: 1, height: 0.5)
            ]
        case .threeColumns:
            let w = 1.0 / 3.0
            return [
                CGRect(x: 0, y: 0, width: w, height: 1),
                CGRect(x: w, y: 0, width: w, height: 1),
                CGRect(x: w * 2, y: 0, width: w, height: 1)
            ]
        case .grid2x2:
            return [
                CGRect(x: 0, y: 0, width: 0.5, height: 0.5),
                CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5),
                CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5),
                CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5)
            ]
        case .fourRows:
            return [
                CGRect(x: 0, y: 0, width: 1, height: 0.25),
                CGRect(x: 0, y: 0.25, width: 1, height: 0.25),
                CGRect(x: 0, y: 0.5, width: 1, height: 0.25),
                CGRect(x: 0, y: 0.75, width: 1, height: 0.25)
            ]
        }
    }
}
