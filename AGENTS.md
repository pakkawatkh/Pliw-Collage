# AGENTS.md — Pliw Collage Development & Release Guide

> Repository-level playbook for AI coding agents working on **Pliw Collage** (`https://github.com/pakkawatkh/Pliw-Collage`). Follow these rules and release steps consistently in every session.

---

## 1. Project Overview

- **App Name:** `Pliw Collage` (`Pliw Collage.app`)
- **Bundle Identifier:** `com.local.pliw-collage` *(keep consistent across releases)*
- **Platform:** Native macOS 13.0+ (Apple Silicon & Intel), Swift 5.9+, SwiftUI, AppKit, AVFoundation, CoreImage (Metal-accelerated custom `AVVideoCompositing`)
- **License:** Open Source — MIT License
- **Release Portal:** `../Pliw-App/pliw-collage/` → Live at `https://pakkawatkh.github.io/Pliw-App/pliw-collage/`
- **Auto-Update Manifest:** `https://pakkawatkh.github.io/Pliw-App/pliw-collage/version.json`

### Scope & Architecture
- **Collage-Only Focus:** This app is dedicated exclusively to **Video Collage** (`9:16`, `4:5`, `1:1`, `16:9`, and custom grids from `1×1` to `6×6`). Do **not** re-introduce a separate multi-track timeline editor or home screen launcher unless explicitly requested.
- `Sources/PliwCollage/App/` — `PliwCollageApp.swift` (direct entry into `ContentView`) and `UpdateManager.swift` (one-click in-app auto-updater).
- `Sources/PliwCollage/Features/Collage/` — Models (`AspectRatioPreset`, `ClipSlot`, `CollageLayout`, `CollageProject`), Engine (`CollageCompositionBuilder`, `CollageExporter`, `CollageVideoCompositor`, `LayoutCalculator`), and UI (`ContentView`, `CollageCanvasView`, `SidebarControlsView`, `SlotInspectorView`, `SlotVideoPlayerView`).

---

## 2. Mandatory Rules

1. **Keep the app focused on Video Collage:** Launch directly into the Collage workspace with fast drag-and-drop, framing/zoom, trim, border/corner styling, per-slot audio, and MP4 export.
2. **Bilingual UI (`th` & `en`):** Support both Thai (`th`) and English (`en`) for new UI additions.
3. **Persistent Code Signing:** Always sign `Pliw Collage.app` in `scripts/build_app.sh` with `MonkeyToolsDeveloper` / `MonkeyCopyDeveloper`.
4. **One-Click In-App Auto-Updater:** Maintain `PliwCollageUpdateManager` checking `https://pakkawatkh.github.io/Pliw-App/pliw-collage/version.json` with one-click download/unzip/replace/relaunch.
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
   This builds Release `Pliw Collage.app`, installs `/Applications/Pliw Collage.app`, creates `pliw-collage-Installer.dmg` + `pliw-collage.zip`, and syncs them to `../Pliw-App/pliw-collage/`.
4. **Update Release Portal (`../Pliw-App`):**
   - Update `../Pliw-App/pliw-collage/version.json` (`latestVersion`, `releaseDate`, `releaseNotes`).
   - Update version and exact DMG/ZIP sizes in `../Pliw-App/index.html`, `../Pliw-App/pliw-collage/index.html`, `../Pliw-App/README.md`, and `./README.md`.
   - Follow `../Pliw-App/AGENTS.md` (100% English, minimal copy).
5. **Commit & push both repositories:**
   ```bash
   git add -A && git commit -m "chore: release vX.Y.Z - <summary>" && git push origin main
   cd ../Pliw-App && git add -A && git commit -m "chore(release): Pliw Collage vX.Y.Z" && git push origin main
   ```
