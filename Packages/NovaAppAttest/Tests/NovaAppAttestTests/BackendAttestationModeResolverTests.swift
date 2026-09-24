import XCTest
@testable import NovaAppAttest

final class BackendAttestationModeResolverTests: XCTestCase {
    func testSupportedDeviceUsesAppAttest() {
        XCTAssertEqual(BackendAttestationModeResolver.resolve(isAppAttestSupported: true), .appAttest)
    }

    func testUnsupportedDeviceIsUnavailable() {
        XCTAssertEqual(BackendAttestationModeResolver.resolve(isAppAttestSupported: false), .unavailable)
    }
}
