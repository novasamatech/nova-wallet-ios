import XCTest
@testable import NovaAppAttest
import Keystore_iOS

final class BackendAttestationIdentityTests: XCTestCase {
    func testClientIdIsNotCreatedUntilAsked() {
        let settings = InMemorySettingsManager()
        _ = BackendAttestationIdentity(settingsManager: settings)

        XCTAssertNil(settings.gatewayAttestationClientId)
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

        XCTAssertNil(settings.gatewayAttestationClientId)

        identity.allowCreation()
        XCTAssertNotEqual(identity.clientId(), first)
    }

    func testForgetBlocksRecreationUntilConsentIsGrantedAgain() {
        let settings = InMemorySettingsManager()
        let identity = BackendAttestationIdentity(settingsManager: settings)

        _ = identity.clientId()
        identity.forgetClientId()

        // Without this, an attestation chain still running during opt-out would mint a
        // client id, attest a fresh key and register it with the gateway.
        XCTAssertNil(identity.clientId())
        XCTAssertNil(settings.gatewayAttestationClientId)
    }

    /// The only assertion that names the on-disk key. Every other test reads and writes
    /// through `gatewayAttestationClientId`, so a typo in that accessor's literal would pass
    /// the whole suite while silently orphaning the client id of every install that already
    /// has one — and the key being unchanged is the entire "no migration needed" argument
    /// for moving this accessor out of the app.
    func testClientIdIsStoredUnderTheKeyExistingInstallsAlreadyHold() {
        let settings = InMemorySettingsManager()
        let identity = BackendAttestationIdentity(settingsManager: settings)

        let created = identity.clientId()

        XCTAssertNotNil(created)
        XCTAssertEqual(settings.string(for: "gatewayAttestationClientId"), created)

        identity.forgetClientId()

        XCTAssertNil(settings.string(for: "gatewayAttestationClientId"))
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
