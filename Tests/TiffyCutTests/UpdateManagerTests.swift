import XCTest
@testable import TiffyCut

final class UpdateManagerTests: XCTestCase {
    func testVersionComparatorDetectsNewerVersions() {
        XCTAssertTrue(TiffyCutVersionComparator.isNewer("2.1.0", than: "2.0.2"))
        XCTAssertTrue(TiffyCutVersionComparator.isNewer("v2.1.1", than: "2.1.0"))
        XCTAssertFalse(TiffyCutVersionComparator.isNewer("2.1.0", than: "2.1.0"))
        XCTAssertFalse(TiffyCutVersionComparator.isNewer("2.0.9", than: "2.1.0"))
    }

    func testReleaseMetaDecodesVersionJSON() throws {
        let json = """
        {
          "latestVersion": "2.1.0",
          "releaseDate": "2026-11-24",
          "downloadUrl": "https://pakkawatkh.github.io/Tiffy-App/tiffy-cut/tiffy-cut-Installer.dmg",
          "zipUrl": "https://pakkawatkh.github.io/Tiffy-App/tiffy-cut/tiffy-cut.zip",
          "pageUrl": "https://pakkawatkh.github.io/Tiffy-App/tiffy-cut/",
          "releaseNotes": "Added one-click in-app auto-updater"
        }
        """.data(using: .utf8)!

        let meta = try JSONDecoder().decode(TiffyCutReleaseMeta.self, from: json)
        XCTAssertEqual(meta.latestVersion, "2.1.0")
        XCTAssertEqual(meta.zipUrl, "https://pakkawatkh.github.io/Tiffy-App/tiffy-cut/tiffy-cut.zip")
    }
}
