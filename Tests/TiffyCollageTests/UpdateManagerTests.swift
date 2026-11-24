import XCTest
@testable import TiffyCollage

final class UpdateManagerTests: XCTestCase {
    func testVersionComparatorDetectsNewerVersions() {
        XCTAssertTrue(TiffyCollageVersionComparator.isNewer("3.0.1", than: "3.0.0"))
        XCTAssertTrue(TiffyCollageVersionComparator.isNewer("v3.1.0", than: "3.0.0"))
        XCTAssertFalse(TiffyCollageVersionComparator.isNewer("3.0.0", than: "3.0.0"))
        XCTAssertFalse(TiffyCollageVersionComparator.isNewer("2.9.9", than: "3.0.0"))
    }

    func testReleaseMetaDecodesVersionJSON() throws {
        let json = """
        {
          "latestVersion": "3.0.0",
          "releaseDate": "2026-11-24",
          "downloadUrl": "https://pakkawatkh.github.io/Tiffy-App/tiffy-collage/tiffy-collage-Installer.dmg",
          "zipUrl": "https://pakkawatkh.github.io/Tiffy-App/tiffy-collage/tiffy-collage.zip",
          "pageUrl": "https://pakkawatkh.github.io/Tiffy-App/tiffy-collage/",
          "releaseNotes": "Refocused app as Tiffy Collage"
        }
        """.data(using: .utf8)!

        let meta = try JSONDecoder().decode(TiffyCollageReleaseMeta.self, from: json)
        XCTAssertEqual(meta.latestVersion, "3.0.0")
        XCTAssertEqual(meta.zipUrl, "https://pakkawatkh.github.io/Tiffy-App/tiffy-collage/tiffy-collage.zip")
    }
}
