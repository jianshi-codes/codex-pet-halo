import XCTest
@testable import PetHalo

final class AppVersionTests: XCTestCase {
    func testFormatsVersionAndBuildMetadata() {
        let version = AppVersion.from(infoDictionary: [
            "CFBundleShortVersionString": "0.1.0",
            "CFBundleVersion": "1",
        ])

        XCTAssertEqual(version, AppVersion(marketingVersion: "0.1.0", buildNumber: "1"))
        XCTAssertEqual(version.displayText, "Version 0.1.0 (1)")
    }

    func testMissingMetadataIsExplicitlyUnavailable() {
        let version = AppVersion.from(infoDictionary: [:])

        XCTAssertEqual(version.displayText, "Version Unavailable (Unavailable)")
    }

    func testMenuModelUsesApplicationIdentityAndVersion() {
        let model = ApplicationMenuModel(
            version: AppVersion(marketingVersion: "0.1.0", buildNumber: "1")
        )

        XCTAssertEqual(model.applicationName, "Pet Halo")
        XCTAssertEqual(model.versionText, "Version 0.1.0 (1)")
    }
}
