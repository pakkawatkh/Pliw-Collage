# AGENTS.md — Tiffy Collage Development & Release Guide

> Repository-level playbook for AI coding agents working on **Tiffy Collage** (`https://github.com/pakkawatkh/Tiffy-Collage`). Follow these rules and release steps consistently in every session.

---

## 1. Project Overview

- **App Name:** `Tiffy Collage` (`Tiffy Collage.app`)
- **Bundle Identifier:** `com.local.tiffy-collage` *(keep consistent across releases)*
- **Platform:** Native macOS 13.0+ (Apple Silicon & Intel), Swift 5.9+, SwiftUI, AppKit, AVFoundation, CoreImage (Metal-accelerated custom `AVVideoCompositing`)
- **License:** Open Source — MIT License
- **Release Portal:** `../Tiffy-App/tiffy-collage/` → Live at `https://pakkawatkh.github.io/Tiffy-App/tiffy-collage/`
- **Auto-Update Manifest:** `https://pakkawatkh.github.io/Tiffy-App/tiffy-collage/version.json`

### Scope & Architecture
- **Collage-Only Focus:** This app is dedicated exclusively to **Video Collage** (`9:16`, `4:5`, `1:1`, `16:9`, and custom grids from `1×1` to `6×6`). Do **not** re-introduce a separate multi-track timeline editor or home screen launcher unless explicitly requested.
- `Sources/TiffyCollage/App/` — `TiffyCollageApp.swift` (direct entry into `ContentView`) and `UpdateManager.swift` (one-click in-app auto-updater).
- `Sources/TiffyCollage/Features/Collage/` — Models (`AspectRatioPreset`, `ClipSlot`, `CollageLayout`, `CollageProject`), Engine (`CollageCompositionBuilder`, `CollageExporter`, `CollageVideoCompositor`, `LayoutCalculator`), and UI (`ContentView`, `CollageCanvasView`, `SidebarControlsView`, `SlotInspectorView`, `SlotVideoPlayerView`).

---

## 2. Mandatory Rules

1. **Keep the app focused on Video Collage:** Launch directly into the Collage workspace with fast drag-and-drop, framing/zoom, trim, border/corner styling, per-slot audio, and MP4 export.
2. **Bilingual UI (`th` & `en`):** Support both Thai (`th`) and English (`en`) for new UI additions.
3. **Persistent Code Signing:** Always sign `Tiffy Collage.app` in `scripts/build_app.sh` with `MonkeyToolsDeveloper` / `MonkeyCopyDeveloper`.
4. **One-Click In-App Auto-Updater:** Maintain `TiffyCollageUpdateManager` checking `https://pakkawatkh.github.io/Tiffy-App/tiffy-collage/version.json` with one-click download/unzip/replace/relaunch.
5. **Keep build artifacts out of Git:** `.gitignore` must exclude `*.app/`, `*.dmg`, `*.zip`, and `.build/`.

---

## 3. Standard End-to-End Release Workflow

Never stop after editing code. Complete every step below in one pass:

1. **Run all unit & export tests:**
   ```bash
   swift test
   ```
   All tests (including end-to-end MP4 collage export and updater tests) must pass.
2. **Bump version** in `scripts/build_app.sh` (`CFBundleShortVersionString` and `CFBundleVersion`).
3. **Build, sign, install, and package:**
   ```bash
   ./scripts/create_dmg.sh
   ```
   This builds Release `Tiffy Collage.app`, installs `/Applications/Tiffy Collage.app`, creates `tiffy-collage-Installer.dmg` + `tiffy-collage.zip`, and syncs them to `../Tiffy-App/tiffy-collage/`.
4. **Update Release Portal (`../Tiffy-App`):**
   - Update `../Tiffy-App/tiffy-collage/version.json` (`latestVersion`, `releaseDate`, `releaseNotes`).
   - Update version and exact DMG/ZIP sizes in `../Tiffy-App/index.html`, `../Tiffy-App/tiffy-collage/index.html`, `../Tiffy-App/README.md`, and `./README.md`.
   - Follow `../Tiffy-App/AGENTS.md` (100% English, minimal copy).
5. **Commit & push both repositories:**
   ```bash
   git add -A && git commit -m "chore: release vX.Y.Z - <summary>" && git push origin main
   cd ../Tiffy-App && git add -A && git commit -m "chore(release): Tiffy Collage vX.Y.Z" && git push origin main
   ```
