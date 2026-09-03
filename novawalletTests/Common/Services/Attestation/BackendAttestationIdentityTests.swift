import XCTest
@testable import novawallet
import Keystore_iOS

final class BackendAttestationIdentityTests: XCTestCase {
    func testClientIdIsNotCreatedUntilAsked() {
        let settings = InMemorySettingsManager()
        _ = BackendAttestationIdentity(settingsManager: settings)

        XCTAssertNil(settings.string(for: SettingsKey.gatewayAttestationClientId.rawValue))
    }

    func testClientIdIsStableAndLowercaseUUID() throws {
        let identity = BackendAttestationIdentity(settingsManager: InMemorySettingsManager())
        let first = try XCTUnwrap(identity.clientId())

        XCTAssertEqual(identity.clientId(), first)
        XCTAssertEqual(first, first.lowercased())
        XCTAssertNotNil(UUID(uuidString: first))
    }

    func testForgetDeletesSoAReconsentedUserIsANewClient() throws {
        let settings = InMemorySettingsManager()
        let identity = BackendAttestationIdentity(settingsManager: settings)

        let first = try XCTUnwrap(identity.clientId())
        identity.forgetClientId()

        XCTAssertNil(settings.string(for: SettingsKey.gatewayAttestationClientId.rawValue))

        identity.allowCreation()
        XCTAssertNotEqual(identity.clientId(), first)
    }

    func testClientIdIsIndependentOfInstallId() {
        let settings = InMemorySettingsManager()
        let identity = BackendAttestationIdentity(settingsManager: settings)
        let analytics = AnalyticsIdentity(settingsManager: settings)

        XCTAssertNotEqual(identity.clientId(), analytics.installId())
    }

    func testForgetBlocksRecreationUntilConsentIsGrantedAgain() {
        let settings = InMemorySettingsManager()
        let identity = BackendAttestationIdentity(settingsManager: settings)

        _ = identity.clientId()
        identity.forgetClientId()

        // Without this, an attestation chain still running during opt-out would mint a
        // client id, attest a fresh key and register it with the gateway.
        XCTAssertNil(identity.clientId())
        XCTAssertNil(settings.string(for: SettingsKey.gatewayAttestationClientId.rawValue))
    }

    func testReConsentAllowsAFreshClientId() {
        let settings = InMemorySettingsManager()
        let identity = BackendAttestationIdentity(settingsManager: settings)

        let original = identity.clientId()
        identity.forgetClientId()
        identity.allowCreation()

        let recreated = identity.clientId()

        XCTAssertNotNil(recreated)
        XCTAssertNotEqual(recreated, original)
    }
}
