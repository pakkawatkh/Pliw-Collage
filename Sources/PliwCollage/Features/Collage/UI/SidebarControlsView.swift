import SwiftUI

public struct SidebarControlsView: View {
    @ObservedObject var project: CollageProject
    @State private var layoutTab: LayoutTab = .presets

    private enum LayoutTab: String, CaseIterable {
        case presets = "เทมเพลต"
        case custom = "กำหนดช่องเอง"
    }

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    public init(project: CollageProject) {
        self.project = project
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Custom Aspect Ratio & Pixel Size Section
                if project.aspectRatio == .custom {
                    customSizeSection
                    Divider()
                }

                // Layout Templates / Custom Slot Count
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("เลย์เอาต์ & ช่อง", systemImage: "square.grid.2x2")
                            .font(.headline)
                        Spacer()
                        Text("\(project.layout.slotCount) ช่อง")
                            .font(.caption2.monospacedDigit().weight(.semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15), in: Capsule())
                            .foregroundStyle(Color.accentColor)
                    }

                    Picker("", selection: $layoutTab) {
                        ForEach(LayoutTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .onChange(of: layoutTab) { newTab in
                        if newTab == .custom && !project.layout.isCustom {
                            project.applyCustomGrid(rows: project.customRows, columns: project.customColumns)
                        }
                    }

                    if layoutTab == .presets {
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(CollageLayout.presets) { layout in
                                LayoutThumbnailButton(
                                    layout: layout,
                                    isSelected: project.layout == layout
                                ) {
                                    project.layout = layout
                                }
                            }
                        }
                    } else {
                        customGridSection
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
        .frame(width: 256)
        .background(Color(nsColor: .controlBackgroundColor))
        .onAppear {
            layoutTab = project.layout.isCustom ? .custom : .presets
        }
    }

    private var customSizeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("ขนาด & อัตราส่วนเอง", systemImage: "aspectratio")
                    .font(.headline)
                Spacer()
                Button {
                    project.swapCustomDimensions()
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .help("สลับกว้าง ↔ สูง (แนวตั้ง/แนวนอน)")
            }

            // Free Aspect Ratio W : H
            VStack(alignment: .leading, spacing: 6) {
                Text("อัตราส่วน (กว้าง : สูง)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    TextField("W", value: Binding(
                        get: { project.customRatioW },
                        set: { project.applyCustomRatio(w: $0, h: project.customRatioH) }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 54)
                    .multilineTextAlignment(.center)

                    Text(":")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    TextField("H", value: Binding(
                        get: { project.customRatioH },
                        set: { project.applyCustomRatio(w: project.customRatioW, h: $0) }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 54)
                    .multilineTextAlignment(.center)

                    Spacer()
                }

                // Quick custom ratio chips
                HStack(spacing: 5) {
                    ForEach([(3, 4), (2, 3), (4, 3), (21, 9)], id: \.0) { pair in
                        Button("\(pair.0):\(pair.1)") {
                            project.applyCustomRatio(w: pair.0, h: pair.1)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }
                }
            }

            // Free Pixel Size Width × Height
            VStack(alignment: .leading, spacing: 6) {
                Text("ขนาดพิกเซลส่งออก (px)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    TextField("Width", value: Binding(
                        get: { project.customWidth },
                        set: { project.customWidth = max(320, min(3840, $0)) }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)

                    Text("×")
                        .foregroundStyle(.secondary)

                    TextField("Height", value: Binding(
                        get: { project.customHeight },
                        set: { project.customHeight = max(320, min(3840, $0)) }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
                }

                Text("ส่งออกจริง: \(Int(project.renderSize.width)) × \(Int(project.renderSize.height)) px")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var customGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Rows stepper
            HStack {
                Text("จำนวนแถว (Rows)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Stepper(
                    value: Binding(
                        get: { project.customRows },
                        set: { project.applyCustomGrid(rows: $0, columns: project.customColumns) }
                    ),
                    in: 1...6
                ) {
                    Text("\(project.customRows)")
                        .font(.caption.monospacedDigit().bold())
                        .frame(width: 20, alignment: .trailing)
                }
            }

            // Columns stepper
            HStack {
                Text("จำนวนคอลัมน์ (Cols)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Stepper(
                    value: Binding(
                        get: { project.customColumns },
                        set: { project.applyCustomGrid(rows: project.customRows, columns: $0) }
                    ),
                    in: 1...6
                ) {
                    Text("\(project.customColumns)")
                        .font(.caption.monospacedDigit().bold())
                        .frame(width: 20, alignment: .trailing)
                }
            }

            // Quick custom grid presets
            VStack(alignment: .leading, spacing: 6) {
                Text("ตารางด่วน")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach([(1, 1, "1 ช่อง"), (3, 2, "6 ช่อง"), (2, 3, "2×3"), (3, 3, "9 ช่อง"), (4, 2, "8 ช่อง"), (4, 3, "12 ช่อง")], id: \.2) { item in
                        let active = project.layout == .customGrid(rows: item.0, columns: item.1)
                        Button(item.2) {
                            project.applyCustomGrid(rows: item.0, columns: item.1)
                        }
                        .buttonStyle(.bordered)
                        .tint(active ? .accentColor : nil)
                        .controlSize(.small)
                    }
                }
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
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
