import XCTest
@testable import NovaAuth

final class NovaAuthPrivacyManifestTests: XCTestCase {
    func testPackagedManifestDeclaresOnlyUsedRequiredReasonCategories() throws {
        let bundleURL = Bundle.module.bundleURL.deletingLastPathComponent().appendingPathComponent("NovaAuth_NovaAuth.bundle")
        let bundle = try XCTUnwrap(Bundle(url: bundleURL))
        let manifestURL = try XCTUnwrap(bundle.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let data = try Data(contentsOf: manifestURL)
        let manifest = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        let entries = try XCTUnwrap(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        let expected = [
            "NSPrivacyAccessedAPICategoryUserDefaults": "CA92.1",
            "NSPrivacyAccessedAPICategorySystemBootTime": "35F9.1"
        ]
        XCTAssertEqual(Set(entries.compactMap { $0["NSPrivacyAccessedAPIType"] as? String }), Set(expected.keys))
        for (category, reason) in expected {
            let matching = entries.filter { $0["NSPrivacyAccessedAPIType"] as? String == category }
            XCTAssertEqual(matching.count, 1)
            XCTAssertEqual(matching.first?["NSPrivacyAccessedAPITypeReasons"] as? [String], [reason])
        }
    }
}
