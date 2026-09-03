import XCTest
@testable import novawallet
import Keystore_iOS

final class BackendAttestationIdentityTests: XCTestCase {
    func testClientIdIsNotCreatedUntilAsked() {
        let settings = InMemorySettingsManager()
        _ = BackendAttestationIdentity(settingsManager: settings)

        XCTAssertNil(settings.string(for: SettingsKey.gatewayAttestationClientId.rawValue))
    }

    func testClientIdIsStableAndLowercaseUUID() {
        let identity = BackendAttestationIdentity(settingsManager: InMemorySettingsManager())
        let first = identity.clientId()

        XCTAssertEqual(identity.clientId(), first)
        XCTAssertEqual(first, first.lowercased())
        XCTAssertNotNil(UUID(uuidString: first))
    }

    func testForgetDeletesSoAReconsentedUserIsANewClient() {
        let settings = InMemorySettingsManager()
        let identity = BackendAttestationIdentity(settingsManager: settings)

        let first = identity.clientId()
        identity.forgetClientId()

        XCTAssertNil(settings.string(for: SettingsKey.gatewayAttestationClientId.rawValue))
        XCTAssertNotEqual(identity.clientId(), first)
    }

    func testClientIdIsIndependentOfInstallId() {
        let settings = InMemorySettingsManager()
        let identity = BackendAttestationIdentity(settingsManager: settings)
        let analytics = AnalyticsIdentity(settingsManager: settings)

        XCTAssertNotEqual(identity.clientId(), analytics.installId())
    }
}
