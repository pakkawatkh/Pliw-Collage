import SwiftUI

public struct HomeView: View {
    @ObservedObject var collageProject: CollageProject
    let onSelectFeature: (TiffyCutFeature) -> Void

    private let gridColumns = [
        GridItem(.adaptive(minimum: 250, maximum: 320), spacing: 18)
    ]

    public init(
        collageProject: CollageProject,
        onSelectFeature: @escaping (TiffyCutFeature) -> Void
    ) {
        self.collageProject = collageProject
        self.onSelectFeature = onSelectFeature
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Minimal top bar
            HStack(spacing: 10) {
                Image(systemName: "scissors")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                Text("tiffy-cut")
                    .font(.headline)
                Text("v1.0.1")
                    .font(.caption2.monospacedDigit())
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.14), in: Capsule())
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Hero header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("เลือกเครื่องมือตัดต่อ")
                            .font(.system(size: 28, weight: .bold))
                        Text("เริ่มงานตัดต่อวิดีโอสำหรับ TikTok และ Instagram ได้ทันทีบน Mac")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)

                    // Available Features
                    VStack(alignment: .leading, spacing: 14) {
                        Text("ฟีเจอร์ที่พร้อมใช้งาน")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 18) {
                            FeatureMenuCard(
                                title: "Collage",
                                subtitle: "รวม 2–4 คลิปเป็นตารางแนวตั้ง 9:16, 4:5 หรือ 1:1 ปรับขอบ ซูม ตัดช่วงเวลา และ Export MP4 1080p",
                                iconName: "rectangle.split.2x2.fill",
                                accentColors: [Color(red: 0.96, green: 0.28, blue: 0.52), Color(red: 0.42, green: 0.36, blue: 0.96)],
                                statusBadge: activeCollageBadge,
                                isAvailable: true
                            ) {
                                onSelectFeature(.collage)
                            }
                        }
                    }

                    // Roadmap / Upcoming Tools
                    VStack(alignment: .leading, spacing: 14) {
                        Text("เร็วๆ นี้ใน tiffy-cut")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 18) {
                            FeatureMenuCard(
                                title: "Trim & Cut",
                                subtitle: "ตัดหัว-ท้าย แบ่งท่อน และตัดช่วงที่ไม่ต้องการออกจากคลิปอย่างรวดเร็ว",
                                iconName: "scissors",
                                accentColors: [Color.orange, Color.pink],
                                statusBadge: "เร็วๆ นี้",
                                isAvailable: false
                            ) {}

                            FeatureMenuCard(
                                title: "Merge Clips",
                                subtitle: "ต่อคลิปหลายไฟล์เรียงกันเป็นวิดีโอเดียวพร้อมปรับสัดส่วนอัตโนมัติ",
                                iconName: "film.stack",
                                accentColors: [Color.cyan, Color.blue],
                                statusBadge: "เร็วๆ นี้",
                                isAvailable: false
                            ) {}

                            FeatureMenuCard(
                                title: "Speed & Audio",
                                subtitle: "เร่งสปีด สโลว์โมชัน ปรับระดับเสียง หรือตัดเสียงออกจากคลิป",
                                iconName: "gauge.with.dots.needle.67percent",
                                accentColors: [Color.purple, Color.indigo],
                                statusBadge: "เร็วๆ นี้",
                                isAvailable: false
                            ) {}
                        }
                    }
                }
                .padding(32)
                .frame(maxWidth: 1040, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(Color(nsColor: .underPageBackgroundColor).opacity(0.4))
        }
        .frame(minWidth: 960, minHeight: 660)
    }

    private var activeCollageBadge: String {
        let count = collageProject.activeSlots.filter { $0.hasVideo }.count
        return count > 0 ? "กำลังทำค้างอยู่ • \(count) คลิป" : "พร้อมใช้งาน"
    }
}

private struct FeatureMenuCard: View {
    let title: String
    let subtitle: String
    let iconName: String
    let accentColors: [Color]
    let statusBadge: String
    let isAvailable: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: accentColors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .opacity(isAvailable ? 1.0 : 0.35)
                            .frame(width: 46, height: 46)

                        Image(systemName: iconName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white.opacity(isAvailable ? 1.0 : 0.75))
                    }

                    Spacer()

                    Text(statusBadge)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(
                            isAvailable ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.12),
                            in: Capsule()
                        )
                        .foregroundStyle(isAvailable ? Color.accentColor : Color.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(isAvailable ? .primary : .secondary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                if isAvailable {
                    HStack(spacing: 5) {
                        Text("เปิดใช้งาน")
                            .font(.caption.weight(.semibold))
                        Image(systemName: "arrow.right")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(Color.accentColor)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 185, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isAvailable && isHovered ? Color.accentColor : Color.secondary.opacity(0.18),
                        lineWidth: isAvailable && isHovered ? 1.8 : 1
                    )
            )
            .shadow(
                color: .black.opacity(isAvailable && isHovered ? 0.14 : 0.04),
                radius: isAvailable && isHovered ? 12 : 4,
                x: 0,
                y: isAvailable && isHovered ? 6 : 2
            )
            .scaleEffect(isAvailable && isHovered ? 1.01 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1.0 : 0.72)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
