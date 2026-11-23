import SwiftUI

public struct HomeView: View {
    @ObservedObject var timelineProject: TimelineProject
    @ObservedObject var collageProject: CollageProject
    let onStartNewProject: () -> Void
    let onOpenProject: (TimelineSnapshot) -> Void
    let onOpenCollage: () -> Void

    public init(
        timelineProject: TimelineProject,
        collageProject: CollageProject,
        onStartNewProject: @escaping () -> Void,
        onOpenProject: @escaping (TimelineSnapshot) -> Void,
        onOpenCollage: @escaping () -> Void
    ) {
        self.timelineProject = timelineProject
        self.collageProject = collageProject
        self.onStartNewProject = onStartNewProject
        self.onOpenProject = onOpenProject
        self.onOpenCollage = onOpenCollage
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack(spacing: 10) {
                Image(systemName: "scissors")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(CapCutTheme.cyan)
                Text("tiffy-cut")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                Text("v2.0.0")
                    .font(.caption2.monospacedDigit())
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(CapCutTheme.cyan.opacity(0.18), in: Capsule())
                    .foregroundStyle(CapCutTheme.cyan)
                Spacer()
                Text("Native macOS Video Studio")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(CapCutTheme.bgPanel)

            Divider().overlay(CapCutTheme.border)

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // CapCut-style Hero Action Row
                    HStack(spacing: 18) {
                        // Primary: New Video Project (CapCut Desktop Hero Button)
                        Button(action: onStartNewProject) {
                            HStack(spacing: 16) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.black.opacity(0.22))
                                        .frame(width: 54, height: 54)
                                    Image(systemName: "plus")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundStyle(.black)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("สร้างโปรเจกต์ใหม่")
                                        .font(.title2.bold())
                                        .foregroundStyle(.black)
                                    Text("ตัดต่อไทม์ไลน์หลายแทร็ก ใส่ข้อความ ฟิลเตอร์ ทรานซิชัน เสียง และส่งออก 4K")
                                        .font(.caption)
                                        .foregroundStyle(.black.opacity(0.75))
                                }
                                Spacer()
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.black.opacity(0.8))
                            }
                            .padding(22)
                            .frame(maxWidth: .infinity, minHeight: 112)
                            .background(
                                LinearGradient(
                                    colors: [CapCutTheme.cyan, Color(red: 0.16, green: 0.92, blue: 0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)

                        // Secondary: Collage Studio
                        Button(action: onOpenCollage) {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: "rectangle.split.2x2.fill")
                                        .font(.title2)
                                        .foregroundStyle(.pink)
                                    Spacer()
                                    Text(collageBadge)
                                        .font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.pink.opacity(0.2), in: Capsule())
                                        .foregroundStyle(.pink)
                                }
                                Text("Video Collage")
                                    .font(.headline.bold())
                                    .foregroundStyle(.white)
                                Text("รวมหลายคลิปเป็นตาราง 9:16, 4:5, 1:1 หรือกำหนดช่องและขนาดเองอิสระ")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.6))
                                    .lineLimit(2)
                            }
                            .padding(18)
                            .frame(width: 280, height: 112, alignment: .topLeading)
                            .background(CapCutTheme.bgElevated, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // Recent Projects (Saved .json snapshots)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("โปรเจกต์ล่าสุด (\(timelineProject.recentProjects.count))")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Spacer()
                        }

                        if timelineProject.recentProjects.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "film.stack")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.white.opacity(0.25))
                                Text("ยังไม่มีโปรเจกต์ที่บันทึกไว้")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.5))
                                Text("กด \"สร้างโปรเจกต์ใหม่\" ด้านบนเพื่อเริ่มตัดต่อวิดีโอได้เลย")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.35))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 44)
                            .background(CapCutTheme.bgPanel, in: RoundedRectangle(cornerRadius: 14))
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220, maximum: 260), spacing: 14)], spacing: 14) {
                                ForEach(timelineProject.recentProjects, id: \.projectID) { snap in
                                    RecentProjectCard(
                                        snapshot: snap,
                                        onOpen: { onOpenProject(snap) },
                                        onDelete: { timelineProject.deleteSavedProject(snap) }
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(32)
                .frame(maxWidth: 1080, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(CapCutTheme.bgBase)
        }
        .frame(minWidth: 1000, minHeight: 680)
        .preferredColorScheme(.dark)
        .onAppear {
            timelineProject.loadRecentProjectsList()
        }
    }

    private var collageBadge: String {
        let count = collageProject.activeSlots.filter { $0.hasVideo }.count
        return count > 0 ? "\(count) คลิปค้างอยู่" : "พร้อมใช้"
    }
}

private struct RecentProjectCard: View {
    let snapshot: TimelineSnapshot
    let onOpen: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(CapCutTheme.bgBase)
                        .frame(height: 110)
                    VStack(spacing: 6) {
                        Image(systemName: "play.rectangle.fill")
                            .font(.title)
                            .foregroundStyle(CapCutTheme.cyan.opacity(0.8))
                        Text("\(snapshot.clips.count) คลิป • \(snapshot.aspectRatio.title)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if isHovered {
                        Button(role: .destructive, action: onDelete) {
                            Image(systemName: "trash.fill")
                                .font(.caption2)
                                .padding(6)
                                .background(.black.opacity(0.75), in: Circle())
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .padding(6)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.projectName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(snapshot.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            .padding(10)
            .background(CapCutTheme.bgPanel, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isHovered ? CapCutTheme.cyan : CapCutTheme.border, lineWidth: isHovered ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
