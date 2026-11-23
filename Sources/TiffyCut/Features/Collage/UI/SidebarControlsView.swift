import SwiftUI

public struct SidebarControlsView: View {
    @ObservedObject var project: CollageProject

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    public init(project: CollageProject) {
        self.project = project
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Layout Templates
                VStack(alignment: .leading, spacing: 10) {
                    Label("เลย์เอาต์ช่อง", systemImage: "square.grid.2x2")
                        .font(.headline)

                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(CollageLayout.allCases) { layout in
                            LayoutThumbnailButton(
                                layout: layout,
                                isSelected: project.layout == layout
                            ) {
                                project.layout = layout
                            }
                        }
                    }
                }

                Divider()

                // Canvas Styling
                VStack(alignment: .leading, spacing: 12) {
                    Label("ขอบและพื้นหลัง", systemImage: "slider.horizontal.3")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("ระยะห่างช่อง")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(project.spacing)) px")
                                .font(.caption.monospacedDigit())
                        }
                        Slider(value: $project.spacing, in: 0...48, step: 2)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("ขอบรอบนอก")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(project.outerPadding)) px")
                                .font(.caption.monospacedDigit())
                        }
                        Slider(value: $project.outerPadding, in: 0...64, step: 2)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("มุมโค้ง")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(project.cornerRadius)) px")
                                .font(.caption.monospacedDigit())
                        }
                        Slider(value: $project.cornerRadius, in: 0...64, step: 2)
                    }

                    HStack {
                        Text("สีพื้นหลัง")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        HStack(spacing: 6) {
                            ColorSwatchButton(color: .black, selected: $project.backgroundColor)
                            ColorSwatchButton(color: .white, selected: $project.backgroundColor)
                            ColorSwatchButton(color: Color(white: 0.14), selected: $project.backgroundColor)
                            ColorPicker("", selection: $project.backgroundColor, supportsOpacity: false)
                                .labelsHidden()
                        }
                    }
                }

                Divider()

                // Duration Mode
                VStack(alignment: .leading, spacing: 8) {
                    Label("ความยาววิดีโอ", systemImage: "clock")
                        .font(.headline)

                    Picker("", selection: $project.durationMode) {
                        ForEach(DurationMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    Text(project.durationMode.description)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
        .frame(width: 240)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

private struct LayoutThumbnailButton: View {
    let layout: CollageLayout
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                GeometryReader { geo in
                    let rects = LayoutCalculator.slotRectsTopLeft(
                        layout: layout,
                        canvasSize: geo.size,
                        spacing: 3,
                        outerPadding: 3
                    )
                    ZStack(alignment: .topLeading) {
                        ForEach(0..<rects.count, id: \.self) { idx in
                            let r = rects[idx]
                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(isSelected ? Color.accentColor.opacity(0.85) : Color.secondary.opacity(0.45))
                                .frame(width: r.width, height: r.height)
                                .position(x: r.midX, y: r.midY)
                        }
                    }
                }
                .frame(width: 34, height: 52)
                .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 5))

                Text(layout.title)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ColorSwatchButton: View {
    let color: Color
    @Binding var selected: Color

    var body: some View {
        Button {
            selected = color
        } label: {
            Circle()
                .fill(color)
                .frame(width: 18, height: 18)
                .overlay(Circle().strokeBorder(Color.secondary.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
