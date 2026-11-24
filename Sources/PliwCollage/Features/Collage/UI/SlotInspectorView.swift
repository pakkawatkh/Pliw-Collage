import SwiftUI

public struct SlotInspectorView: View {
    @ObservedObject var project: CollageProject

    public init(project: CollageProject) {
        self.project = project
    }

    private var slotIndex: Int {
        min(project.selectedSlotIndex, project.layout.slotCount - 1)
    }

    private var slot: ClipSlot {
        project.slots[slotIndex]
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Label("ช่องที่ \(slotIndex + 1)", systemImage: "film")
                        .font(.headline)
                    Spacer()
                    if slot.hasVideo {
                        Button(role: .destructive) {
                            project.clearSlot(slotIndex)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .help("ลบวิดีโอในช่องนี้")
                    }
                }

                if slot.hasVideo {
                    // File Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(slot.fileName)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(2)
                        HStack(spacing: 10) {
                            Text("\(Int(slot.orientedSize.width))×\(Int(slot.orientedSize.height))")
                            Text("•")
                            Text(CollageProject.formatTime(slot.duration))
                        }
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

                    Button {
                        project.openFilePicker(for: slotIndex)
                    } label: {
                        Label("เปลี่ยนไฟล์วิดีโอ", systemImage: "folder")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.regular)

                    Divider()

                    // Trim Controls
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("ตัดช่วงเวลา (Trim)", systemImage: "scissors")
                                .font(.subheadline.bold())
                            Spacer()
                            Text(CollageProject.formatTime(slot.trimmedDuration))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("เริ่ม")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(CollageProject.formatTime(slot.trimStart))
                                    .font(.caption.monospacedDigit())
                            }
                            Slider(
                                value: Binding(
                                    get: { project.slots[slotIndex].trimStart },
                                    set: { newVal in
                                        let maxStart = max(0, project.slots[slotIndex].trimEnd - 0.2)
                                        let clamped = min(newVal, maxStart)
                                        project.slots[slotIndex].trimStart = clamped
                                        project.previewSlotFrame(index: slotIndex, at: clamped)
                                    }
                                ),
                                in: 0...max(0.1, slot.duration)
                            )
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("จบ")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(CollageProject.formatTime(slot.trimEnd))
                                    .font(.caption.monospacedDigit())
                            }
                            Slider(
                                value: Binding(
                                    get: { project.slots[slotIndex].trimEnd },
                                    set: { newVal in
                                        let minEnd = min(slot.duration, project.slots[slotIndex].trimStart + 0.2)
                                        let clamped = max(newVal, minEnd)
                                        project.slots[slotIndex].trimEnd = clamped
                                        project.previewSlotFrame(index: slotIndex, at: clamped)
                                    }
                                ),
                                in: 0...max(0.1, slot.duration)
                            )
                        }
                    }

                    Divider()

                    // Framing Controls
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("จัดเฟรมภาพ", systemImage: "crop")
                                .font(.subheadline.bold())
                            Spacer()
                            Button("รีเซ็ต") {
                                project.slots[slotIndex].resetFraming()
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("ซูม (Zoom)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(String(format: "%.0f%%", slot.scale * 100))
                                    .font(.caption.monospacedDigit())
                            }
                            Slider(
                                value: Binding(
                                    get: { project.slots[slotIndex].scale },
                                    set: { project.slots[slotIndex].scale = $0 }
                                ),
                                in: 1.0...3.0
                            )
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("เลื่อนซ้าย-ขวา")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(String(format: "%.0f%%", slot.offsetX * 100))
                                    .font(.caption.monospacedDigit())
                            }
                            Slider(
                                value: Binding(
                                    get: { project.slots[slotIndex].offsetX },
                                    set: { project.slots[slotIndex].offsetX = $0 }
                                ),
                                in: -1.0...1.0
                            )
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("เลื่อนบน-ล่าง")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(String(format: "%.0f%%", slot.offsetY * 100))
                                    .font(.caption.monospacedDigit())
                            }
                            Slider(
                                value: Binding(
                                    get: { project.slots[slotIndex].offsetY },
                                    set: { project.slots[slotIndex].offsetY = $0 }
                                ),
                                in: -1.0...1.0
                            )
                        }

                        Text("ทิป: ลากนิ้ว/เมาส์บนคลิปในหน้าจอพรีวิวเพื่อขยับตำแหน่งได้ทันที")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    // Audio Controls
                    VStack(alignment: .leading, spacing: 10) {
                        Label("เสียงของคลิปนี้", systemImage: "speaker.wave.2")
                            .font(.subheadline.bold())

                        Toggle(isOn: Binding(
                            get: { !project.slots[slotIndex].isMuted },
                            set: { enabled in
                                project.slots[slotIndex].isMuted = !enabled
                                project.syncAudioSettings(for: slotIndex)
                            }
                        )) {
                            Text(slot.isMuted ? "ปิดเสียงอยู่" : "เปิดเสียง")
                                .font(.caption)
                        }

                        if !slot.isMuted {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("ระดับเสียง")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(Int(slot.volume * 100))%")
                                        .font(.caption.monospacedDigit())
                                }
                                Slider(
                                    value: Binding(
                                        get: { Double(project.slots[slotIndex].volume) },
                                        set: {
                                            project.slots[slotIndex].volume = Float($0)
                                            project.syncAudioSettings(for: slotIndex)
                                        }
                                    ),
                                    in: 0...1
                                )
                            }
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "video.badge.plus")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        Text("ยังไม่มีวิดีโอในช่องนี้")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button {
                            project.openFilePicker(for: slotIndex)
                        } label: {
                            Label("เลือกไฟล์วิดีโอ...", systemImage: "plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, 28)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(16)
        }
        .frame(width: 250)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
