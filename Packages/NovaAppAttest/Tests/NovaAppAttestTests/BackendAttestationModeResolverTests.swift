import XCTest
@testable import NovaAppAttest

final class BackendAttestationModeResolverTests: XCTestCase {
    private func resolve(isAppAttestSupported: Bool) -> BackendAttestationMode {
        BackendAttestationModeResolver.resolve(isAppAttestSupported: isAppAttestSupported)
    }

    func testSupportedDeviceUsesAppAttest() {
        XCTAssertEqual(resolve(isAppAttestSupported: true), .appAttest)
    }

    /// Profile 2 has no unattested variant of a protected route, so a Simulator cannot upload at all.
    func testAnUnsupportedDeviceIsUnavailableRatherThanUnattested() {
        XCTAssertEqual(resolve(isAppAttestSupported: false), .unavailable)
    }
}
