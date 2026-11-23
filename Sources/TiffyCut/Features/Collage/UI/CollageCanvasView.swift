import SwiftUI
import UniformTypeIdentifiers

public struct CollageCanvasView: View {
    @ObservedObject var project: CollageProject

    public init(project: CollageProject) {
        self.project = project
    }

    public var body: some View {
        GeometryReader { geo in
            let availableW = max(100, geo.size.width - 40)
            let availableH = max(100, geo.size.height - 40)
            let ratio = project.aspectRatio.ratio

            let previewSize: CGSize = {
                if availableW / availableH > ratio {
                    let h = availableH
                    return CGSize(width: h * ratio, height: h)
                } else {
                    let w = availableW
                    return CGSize(width: w, height: w / ratio)
                }
            }()

            let scaleFactor = previewSize.width / project.aspectRatio.renderSize.width
            let previewSpacing = project.spacing * scaleFactor
            let previewPadding = project.outerPadding * scaleFactor
            let previewRadius = project.cornerRadius * scaleFactor

            let rects = LayoutCalculator.slotRectsTopLeft(
                layout: project.layout,
                canvasSize: previewSize,
                spacing: previewSpacing,
                outerPadding: previewPadding
            )

            ZStack {
                // Canvas backdrop
                RoundedRectangle(cornerRadius: 8)
                    .fill(project.backgroundColor)
                    .frame(width: previewSize.width, height: previewSize.height)
                    .shadow(color: .black.opacity(0.45), radius: 22, x: 0, y: 10)

                // Slot layers
                ZStack(alignment: .topLeading) {
                    ForEach(0..<project.layout.slotCount, id: \.self) { index in
                        let rect = rects[index]
                        SlotCellView(
                            project: project,
                            slotIndex: index,
                            slotSize: rect.size,
                            cornerRadius: previewRadius
                        )
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                    }
                }
                .frame(width: previewSize.width, height: previewSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.6))
    }
}

private struct SlotCellView: View {
    @ObservedObject var project: CollageProject
    let slotIndex: Int
    let slotSize: CGSize
    let cornerRadius: CGFloat

    @State private var isTargeted = false
    @State private var isHovered = false
    @State private var dragStartOffset: CGPoint?

    private var slot: ClipSlot {
        project.slots[slotIndex]
    }

    private var isSelected: Bool {
        project.selectedSlotIndex == slotIndex
    }

    var body: some View {
        ZStack {
            if slot.hasVideo, let player = project.players[slotIndex] {
                SlotVideoPlayerView(
                    player: player,
                    orientedSize: slot.orientedSize,
                    scale: slot.scale,
                    offsetX: slot.offsetX,
                    offsetY: slot.offsetY
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 3)
                        .onChanged { value in
                            if project.selectedSlotIndex != slotIndex {
                                project.selectedSlotIndex = slotIndex
                            }
                            if dragStartOffset == nil {
                                dragStartOffset = CGPoint(x: slot.offsetX, y: slot.offsetY)
                            }
                            guard let start = dragStartOffset else { return }
                            let sensX = max(1, slotSize.width * 0.5)
                            let sensY = max(1, slotSize.height * 0.5)
                            project.slots[slotIndex].offsetX = max(-1, min(1, start.x + value.translation.width / sensX))
                            project.slots[slotIndex].offsetY = max(-1, min(1, start.y + value.translation.height / sensY))
                        }
                        .onEnded { _ in
                            dragStartOffset = nil
                        }
                )
                .onTapGesture {
                    project.selectedSlotIndex = slotIndex
                }

                // Hover / Selected quick overlay controls
                if isHovered || isSelected {
                    VStack {
                        HStack(spacing: 6) {
                            Text("#\(slotIndex + 1)")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(.ultraThinMaterial, in: Capsule())

                            Spacer()

                            Button {
                                project.slots[slotIndex].isMuted.toggle()
                                project.syncAudioSettings(for: slotIndex)
                            } label: {
                                Image(systemName: slot.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                    .font(.caption)
                                    .foregroundStyle(slot.isMuted ? .red : .white)
                                    .padding(6)
                                    .background(.black.opacity(0.6), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .help(slot.isMuted ? "เปิดเสียง" : "ปิดเสียง")

                            Button {
                                project.openFilePicker(for: slotIndex)
                            } label: {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                    .padding(6)
                                    .background(.black.opacity(0.6), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .help("เปลี่ยนคลิป")

                            Button {
                                project.clearSlot(slotIndex)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                                    .padding(6)
                                    .background(.black.opacity(0.6), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .help("ลบคลิป")
                        }
                        .padding(8)
                        Spacer()
                    }
                }
            } else {
                // Empty Drop Zone
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isTargeted ? Color.accentColor.opacity(0.25) : Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                isTargeted ? Color.accentColor : Color.white.opacity(0.25),
                                style: StrokeStyle(lineWidth: isTargeted ? 2.5 : 1.5, dash: [6, 5])
                            )
                    )
                    .overlay(
                        VStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: min(30, max(18, slotSize.width * 0.14))))
                                .foregroundStyle(isTargeted ? Color.accentColor : Color.white.opacity(0.75))
                            Text("ช่องที่ \(slotIndex + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.9))
                            if slotSize.height > 90 {
                                Text("ลากวิดีโอมาวาง หรือคลิกเลือก")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.6))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 8)
                            }
                        }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        project.selectedSlotIndex = slotIndex
                        project.openFilePicker(for: slotIndex)
                    }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor : Color.clear,
                    lineWidth: 2.5
                )
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            var resolvedURL: URL?
            if let data = item as? Data {
                resolvedURL = URL(dataRepresentation: data, relativeTo: nil)
            } else if let url = item as? URL {
                resolvedURL = url
            }
            guard let url = resolvedURL else { return }
            Task { @MainActor in
                project.loadVideo(url: url, into: slotIndex)
            }
        }
        return true
    }
}
