import XCTest
@testable import novawallet

final class PrivacyManifestTests: XCTestCase {
    func testProductInteractionAndDeviceIdAreDeclaredUnlinkedForAnalytics() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let plist = try PropertyListSerialization.propertyList(from: try Data(contentsOf: url), format: nil) as? [String: Any]
        let collected = plist?["NSPrivacyCollectedDataTypes"] as? [[String: Any]] ?? []

        for expected in ["NSPrivacyCollectedDataTypeProductInteraction", "NSPrivacyCollectedDataTypeDeviceID"] {
            let entry = try XCTUnwrap(collected.first { $0["NSPrivacyCollectedDataType"] as? String == expected }, expected)

            XCTAssertEqual(entry["NSPrivacyCollectedDataTypeLinked"] as? Bool, false, expected)
            XCTAssertEqual(entry["NSPrivacyCollectedDataTypeTracking"] as? Bool, false, expected)
            XCTAssertEqual(entry["NSPrivacyCollectedDataTypePurposes"] as? [String], ["NSPrivacyCollectedDataTypePurposeAnalytics"], expected)
        }
    }
}
