import AppKit
import Foundation
import SwiftUI

public struct PliwCollageReleaseMeta: Codable, Equatable, Sendable {
    public let latestVersion: String
    public let releaseDate: String?
    public let downloadUrl: String
    public let zipUrl: String?
    public let pageUrl: String?
    public let releaseNotes: String?
}

public enum PliwCollageVersionComparator {
    public static func isNewer(_ remote: String, than current: String) -> Bool {
        let r = parse(remote)
        let c = parse(current)
        let count = max(r.count, c.count)
        for i in 0..<count {
            let rv = i < r.count ? r[i] : 0
            let cv = i < c.count ? c[i] : 0
            if rv != cv { return rv > cv }
        }
        return false
    }

    private static func parse(_ version: String) -> [Int] {
        version
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "v", with: "", options: .caseInsensitive)
            .split(separator: ".")
            .map { Int($0.prefix(while: { $0.isNumber })) ?? 0 }
    }
}

@MainActor
public final class PliwCollageUpdateManager: ObservableObject {
    public static let shared = PliwCollageUpdateManager()
    public static let versionURL = URL(string: "https://pakkawatkh.github.io/public/pliw-collage/version.json")!

    @Published public private(set) var isChecking = false
    @Published public private(set) var isUpdating = false
    @Published public private(set) var availableUpdate: PliwCollageReleaseMeta?
    @Published public private(set) var statusMessage: String?

    private var statusDismissTask: Task<Void, Never>?

    public var currentVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "3.0.0"
    }

    private init() {}

    public func checkForUpdates(manual: Bool = false) {
        guard !isChecking, !isUpdating else { return }
        isChecking = true
        if manual {
            setStatus("กำลังตรวจสอบอัปเดต...", autoHideAfter: nil)
        }

        Task {
            defer { self.isChecking = false }
            do {
                var req = URLRequest(url: Self.versionURL)
                req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
                req.timeoutInterval = 12
                let (data, response) = try await URLSession.shared.data(for: req)
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                    if manual {
                        setStatus("ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์อัปเดตได้", autoHideAfter: 4)
                    }
                    return
                }

                let meta = try JSONDecoder().decode(PliwCollageReleaseMeta.self, from: data)
                if PliwCollageVersionComparator.isNewer(meta.latestVersion, than: currentVersion) {
                    availableUpdate = meta
                    statusMessage = nil
                } else {
                    availableUpdate = nil
                    if manual {
                        setStatus("Pliw Collage v\(currentVersion) เป็นเวอร์ชันล่าสุดแล้ว", autoHideAfter: 3.5)
                    }
                }
            } catch {
                if manual {
                    setStatus("ตรวจสอบอัปเดตไม่สำเร็จ", autoHideAfter: 4)
                }
            }
        }
    }

    public func dismissBanner() {
        availableUpdate = nil
    }

    public func installAvailableUpdate() {
        guard let meta = availableUpdate, !isUpdating else { return }
        let zipURLString = meta.zipUrl ?? meta.downloadUrl
        guard let url = URL(string: zipURLString), zipURLString.hasSuffix(".zip") else {
            if let fallback = URL(string: meta.downloadUrl) {
                NSWorkspace.shared.open(fallback)
            }
            return
        }

        isUpdating = true
        setStatus("กำลังดาวน์โหลด Pliw Collage v\(meta.latestVersion)...", autoHideAfter: nil)

        Task {
            do {
                let (tempZip, response) = try await URLSession.shared.download(from: url)
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                    throw URLError(.badServerResponse)
                }

                setStatus("กำลังติดตั้งและเปิดแอปใหม่...", autoHideAfter: nil)

                let staging = FileManager.default.temporaryDirectory
                    .appendingPathComponent("PliwCollageUpdate-\(UUID().uuidString)")
                try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)

                let unzip = Process()
                unzip.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                unzip.arguments = ["-x", "-k", tempZip.path, staging.path]
                try unzip.run()
                unzip.waitUntilExit()
                guard unzip.terminationStatus == 0 else {
                    throw NSError(domain: "PliwCollageUpdater", code: Int(unzip.terminationStatus))
                }

                let extractedApp = staging.appendingPathComponent("Pliw Collage.app")
                guard FileManager.default.fileExists(atPath: extractedApp.path) else {
                    throw NSError(domain: "PliwCollageUpdater", code: 404)
                }

                let targetApp = "/Applications/Pliw Collage.app"
                let pid = ProcessInfo.processInfo.processIdentifier

                let script = """
                #!/bin/bash
                while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done
                rm -rf "/Applications/pliw-cut.app" "/Applications/Pliw Cut.app" "\(targetApp)"
                mv "\(extractedApp.path)" "\(targetApp)"
                xattr -cr "\(targetApp)" 2>/dev/null || true
                open "\(targetApp)"
                rm -rf "\(staging.path)"
                """

                let scriptURL = staging.appendingPathComponent("install_update.sh")
                try script.write(to: scriptURL, atomically: true, encoding: .utf8)
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

                let launcher = Process()
                launcher.executableURL = URL(fileURLWithPath: "/bin/bash")
                launcher.arguments = [scriptURL.path]
                try launcher.run()

                NSApp.terminate(nil)
            } catch {
                self.isUpdating = false
                self.setStatus("อัปเดตไม่สำเร็จ — กำลังเปิดหน้าดาวน์โหลด", autoHideAfter: 4)
                if let fallback = URL(string: meta.downloadUrl) {
                    NSWorkspace.shared.open(fallback)
                }
            }
        }
    }

    private func setStatus(_ text: String, autoHideAfter seconds: TimeInterval?) {
        statusDismissTask?.cancel()
        statusMessage = text
        if let seconds {
            statusDismissTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                if !Task.isCancelled {
                    self.statusMessage = nil
                }
            }
        }
    }
}
