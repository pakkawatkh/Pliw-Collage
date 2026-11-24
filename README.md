# ✂️ Tiffy Cut

**CapCut-Style Video Editor & Collage Studio for macOS**

[![Version](https://img.shields.io/badge/Release-v2.0.2-ec4899?style=for-the-badge)](https://pakkawatkh.github.io/tiffy-app/tiffy-cut/)
[![Platform](https://img.shields.io/badge/Platform-macOS%2013%2B-lightgrey?style=for-the-badge&logo=apple)](https://github.com/pakkawatkh/Tiffy-Cut)

`Tiffy Cut` is a lightweight, native macOS video editing suite built with SwiftUI, AVFoundation, and Metal-accelerated CoreImage — designed for fast TikTok, Instagram Reels, and YouTube workflows with zero watermarks.

- 🌐 **Live Website & Studio Preview:** https://pakkawatkh.github.io/tiffy-app/tiffy-cut/
- 📥 **Direct Download (DMG · 2.0 MB):** https://pakkawatkh.github.io/tiffy-app/tiffy-cut/tiffy-cut-Installer.dmg
- 🗜️ **ZIP Archive:** https://pakkawatkh.github.io/tiffy-app/tiffy-cut/tiffy-cut.zip

---

## ✨ Features & Modes

### 1. 🎬 Multi-Track Video Editor (4-Pane Dark Studio)
- **Multi-Track Timeline:** Magnetic Main Video track, Overlay / Picture-in-Picture (PIP), Text Overlays, and Audio tracks.
- **Fast Editing Tools:** Split clip (`⌘B`), Trim, Undo/Redo, Scale/Position/Rotation/Flip, and Speed (`0.25x–4x`).
- **Color & Style:** 7 built-in filters, color grading sliders, smooth clip transitions, and project auto-saving.
- **Hardware-Accelerated Export:** Export crisp MP4 in `720p`, `1080p`, or `4K` at `24/30/60fps` (`H.264` or `HEVC`).

### 2. 🧩 Collage Studio
- **Social Aspect Ratios & Custom Grids:** Instant presets for `9:16`, `4:5`, `1:1`, `16:9`, or custom aspect ratios and grids from `1×1` up to `6×6`.
- **Per-Slot Control:** Drag & drop video clips, pan/zoom framing, trim start/end, border spacing, corner radius, background color, and per-slot volume/mute.

---

## 🚀 Installation Guide

1. Download **`tiffy-cut-Installer.dmg`** from the link above and double-click to open it.
2. Drag **`Tiffy Cut.app`** into the **Applications** folder.
3. **First-Time Launch (macOS Gatekeeper):**
   - Open **System Settings → Privacy & Security → Open Anyway**, **or**
   - Run in Terminal:
     ```bash
     xattr -cr "/Applications/Tiffy Cut.app"
     ```

---

## 🛠️ Build & Test from Source

```bash
swift test
./scripts/build_app.sh
./scripts/create_dmg.sh
```
