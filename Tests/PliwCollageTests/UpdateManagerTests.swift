import XCTest
@testable import PliwCollage

final class UpdateManagerTests: XCTestCase {
    func testVersionComparatorDetectsNewerVersions() {
        XCTAssertTrue(PliwCollageVersionComparator.isNewer("3.0.1", than: "3.0.0"))
        XCTAssertTrue(PliwCollageVersionComparator.isNewer("v3.1.0", than: "3.0.0"))
        XCTAssertFalse(PliwCollageVersionComparator.isNewer("3.0.0", than: "3.0.0"))
        XCTAssertFalse(PliwCollageVersionComparator.isNewer("2.9.9", than: "3.0.0"))
    }

    func testReleaseMetaDecodesVersionJSON() throws {
        let json = """
        {
          "latestVersion": "3.0.0",
          "releaseDate": "2026-11-24",
          "downloadUrl": "https://pakkawatkh.github.io/Pliw-App/pliw-collage/pliw-collage-Installer.dmg",
          "zipUrl": "https://pakkawatkh.github.io/Pliw-App/pliw-collage/pliw-collage.zip",
          "pageUrl": "https://pakkawatkh.github.io/Pliw-App/pliw-collage/",
          "releaseNotes": "Refocused app as Pliw Collage"
        }
        """.data(using: .utf8)!

        let meta = try JSONDecoder().decode(PliwCollageReleaseMeta.self, from: json)
        XCTAssertEqual(meta.latestVersion, "3.0.0")
        XCTAssertEqual(meta.zipUrl, "https://pakkawatkh.github.io/Pliw-App/pliw-collage/pliw-collage.zip")
    }
}
