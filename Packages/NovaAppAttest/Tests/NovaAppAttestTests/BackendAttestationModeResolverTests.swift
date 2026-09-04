import XCTest
@testable import NovaAppAttest

final class BackendAttestationModeResolverTests: XCTestCase {
    func testSupportedDeviceUsesAppAttestInEveryConfiguration() {
        XCTAssertEqual(
            BackendAttestationModeResolver.resolve(isReleaseBuild: true, isAppAttestSupported: true),
            .appAttest
        )
        XCTAssertEqual(
            BackendAttestationModeResolver.resolve(isReleaseBuild: false, isAppAttestSupported: true),
            .appAttest
        )
    }

    func testSimulatorInADevBuildSendsUnsigned() {
        XCTAssertEqual(
            BackendAttestationModeResolver.resolve(isReleaseBuild: false, isAppAttestSupported: false),
            .none
        )
    }

    func testUnsupportedInReleaseIsUnavailable() {
        // Feeds isAvailable=false: no prompt, no Settings row, track() drops.
        XCTAssertEqual(
            BackendAttestationModeResolver.resolve(isReleaseBuild: true, isAppAttestSupported: false),
            .unavailable
        )
    }
}
