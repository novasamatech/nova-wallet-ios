import XCTest
@testable import NovaAppAttest

final class BackendAttestationModeResolverTests: XCTestCase {
    private func resolve(isReleaseBuild: Bool, isAppAttestSupported: Bool) -> BackendAttestationMode {
        BackendAttestationModeResolver.resolve(
            isReleaseBuild: isReleaseBuild,
            isAppAttestSupported: isAppAttestSupported
        )
    }

    func testSupportedDeviceUsesAppAttestInEveryConfiguration() {
        XCTAssertEqual(resolve(isReleaseBuild: true, isAppAttestSupported: true), .appAttest)
        XCTAssertEqual(resolve(isReleaseBuild: false, isAppAttestSupported: true), .appAttest)
    }

    func testUnsupportedInReleaseIsUnavailable() {
        XCTAssertEqual(resolve(isReleaseBuild: true, isAppAttestSupported: false), .unavailable)
    }
}
