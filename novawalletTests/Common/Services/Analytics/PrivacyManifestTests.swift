import XCTest
@testable import novawallet

/// Reads the manifest out of the built app bundle rather than the repo file, so this asserts
/// on what actually ships.
final class PrivacyManifestTests: XCTestCase {
    private func manifest() throws -> [String: Any] {
        let url = try XCTUnwrap(
            Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"),
            "PrivacyInfo.xcprivacy is not in the app bundle"
        )

        let plist = try PropertyListSerialization.propertyList(
            from: try Data(contentsOf: url),
            format: nil
        )

        return try XCTUnwrap(plist as? [String: Any])
    }

    func testTrackingIsDeclaredFalseWithNoTrackingDomains() throws {
        let plist = try manifest()

        XCTAssertEqual(plist["NSPrivacyTracking"] as? Bool, false)

        // Listing the analytics host here would make iOS block it without an ATT prompt.
        // The key must be present and empty, not absent.
        XCTAssertEqual((plist["NSPrivacyTrackingDomains"] as? [String])?.count, 0)
    }

    func testProductInteractionAndDeviceIdAreDeclaredUnlinkedForAnalytics() throws {
        let plist = try manifest()
        let collected = plist["NSPrivacyCollectedDataTypes"] as? [[String: Any]] ?? []

        for expected in [
            "NSPrivacyCollectedDataTypeProductInteraction",
            "NSPrivacyCollectedDataTypeDeviceID"
        ] {
            guard
                let entry = collected.first(where: {
                    $0["NSPrivacyCollectedDataType"] as? String == expected
                })
            else {
                return XCTFail("missing declaration for \(expected)")
            }

            XCTAssertEqual(entry["NSPrivacyCollectedDataTypeLinked"] as? Bool, false, expected)
            XCTAssertEqual(entry["NSPrivacyCollectedDataTypeTracking"] as? Bool, false, expected)
            XCTAssertEqual(
                entry["NSPrivacyCollectedDataTypePurposes"] as? [String],
                ["NSPrivacyCollectedDataTypePurposeAnalytics"],
                expected
            )
        }
    }

    func testExistingAccessedApiDeclarationIsUntouched() throws {
        let plist = try manifest()
        let apis = plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]] ?? []

        XCTAssertTrue(
            apis.contains {
                $0["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults"
            }
        )
    }

    func testNoDataTypeIsDeclaredLinkedOrTracking() throws {
        let plist = try manifest()
        let collected = plist["NSPrivacyCollectedDataTypes"] as? [[String: Any]] ?? []

        XCTAssertFalse(collected.isEmpty)

        // A later addition that flips either flag changes the App Store label and would
        // require an ATT prompt, so catch it here rather than in review.
        for entry in collected {
            let name = entry["NSPrivacyCollectedDataType"] as? String ?? "unknown"

            XCTAssertEqual(entry["NSPrivacyCollectedDataTypeLinked"] as? Bool, false, name)
            XCTAssertEqual(entry["NSPrivacyCollectedDataTypeTracking"] as? Bool, false, name)
        }
    }
}
