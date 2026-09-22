import XCTest
@testable import NovaAppAttest
import Keystore_iOS

final class BackendAttestationIdentityTests: XCTestCase {
    func testCreatesStableClientId() throws {
        let identity = BackendAttestationIdentity(settingsManager: InMemorySettingsManager())
        let first = try XCTUnwrap(identity.clientId())

        XCTAssertEqual(identity.clientId(), first)
        XCTAssertEqual(first, first.lowercased())
        XCTAssertNotNil(UUID(uuidString: first))
    }

    func testResetRequiresCurrentClientId() throws {
        let settings = InMemorySettingsManager()
        let identity = BackendAttestationIdentity(settingsManager: settings)
        let refused = try XCTUnwrap(identity.clientId())

        identity.resetClientId(ifCurrent: refused)
        let successor = try XCTUnwrap(identity.clientId())
        XCTAssertNotEqual(successor, refused)

        identity.resetClientId(ifCurrent: refused)
        XCTAssertEqual(settings.gatewayAttestationClientId, successor)
    }

    func testForgetClearsClientId() throws {
        let settings = InMemorySettingsManager()
        let identity = BackendAttestationIdentity(settingsManager: settings)
        let first = try XCTUnwrap(identity.clientId())

        identity.forgetClientId()
        XCTAssertNil(settings.gatewayAttestationClientId)

        identity.allowCreation()
        XCTAssertNotEqual(identity.clientId(), first)
    }
}
