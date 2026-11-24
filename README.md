# 🧩 Tiffy Collage

**Native macOS Video Collage Studio**

[![Version](https://img.shields.io/badge/Release-v3.0.0-ec4899?style=for-the-badge)](https://pakkawatkh.github.io/Tiffy-App/tiffy-collage/)
[![Platform](https://img.shields.io/badge/Platform-macOS%2013%2B-lightgrey?style=for-the-badge&logo=apple)](https://github.com/pakkawatkh/Tiffy-Collage)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

`Tiffy Collage` is a lightweight, native macOS video collage studio built with SwiftUI, AVFoundation, and CoreImage — combine multiple video clips into `9:16`, `4:5`, `1:1`, `16:9`, or custom grids up to `6×6` and export crisp MP4 with zero watermarks.

- 🌐 **Website & Preview:** https://pakkawatkh.github.io/Tiffy-App/tiffy-collage/
- 📥 **Direct Download (DMG · 1.7 MB):** https://pakkawatkh.github.io/Tiffy-App/tiffy-collage/tiffy-collage-Installer.dmg
- 🗜️ **ZIP Archive (1.4 MB):** https://pakkawatkh.github.io/Tiffy-App/tiffy-collage/tiffy-collage.zip

---

## ✨ Features

- **Social Aspect Ratios & Custom Grids:** Instant presets for `9:16`, `4:5`, `1:1`, `16:9`, or custom canvas sizes and grids from `1×1` up to `6×6`.
- **Per-Slot Control:** Drag & drop video clips, pan/zoom framing, start/end trim, border spacing, corner radius, background color, and per-slot volume/mute.
- **Fast Native MP4 Export:** Hardware-accelerated H.264 MP4 export on Apple Silicon & Intel Macs.
- **One-Click In-App Auto-Updater:** Checks for updates automatically on launch and updates in one click.

---

## 🚀 Installation

1. Download **`tiffy-collage-Installer.dmg`** and double-click to mount it.
2. Drag **`Tiffy Collage.app`** into your **Applications** folder.
3. **First-Time Launch (Gatekeeper):** Open **System Settings → Privacy & Security → Open Anyway**, or run:
   ```bash
   xattr -cr "/Applications/Tiffy Collage.app"
   ```

---

## 🛠️ Build & Test from Source

```bash
swift test
./scripts/build_app.sh
./scripts/create_dmg.sh
```

---

## 📄 License

Open Source — Licensed under the **[MIT License](LICENSE)**. Copyright © 2026 Pakkawat.k.
