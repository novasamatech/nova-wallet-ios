import XCTest
@testable import NovaAppAttest
import Keystore_iOS
import Operation_iOS

final class AttestationProfileMigratorTests: XCTestCase {
    /// A legacy binding stays at its own profile server-side and is never promoted: keeping the
    /// identifier earns 403 on every request challenge and 409 on every re-registration, both of
    /// which tell the client to stop. The only way out is a new identifier and a new key.
    func testAnInstallationFromTheOldProtocolIsRetiredWithItsKey() throws {
        let settings = InMemorySettingsManager()
        let repository = SettingsAppAttestKeyRepository(settingsManager: settings)

        settings.gatewayAttestationClientId = "6f2c1e4a-0000-4000-8000-000000000001"

        let save = repository.saveOperation({
            [
                AppAttestKeySettings(
                    identifier: "https://gateway.example/|6f2c1e4a-0000-4000-8000-000000000001",
                    keyId: "legacy-key",
                    isAttested: true,
                    attemptCount: 0,
                    nextAttemptAt: nil
                )
            ]
        }, { [] })

        OperationQueue().addOperations([save], waitUntilFinished: true)

        AttestationProfileMigrator.migrate(settingsManager: settings)

        XCTAssertNil(settings.gatewayAttestationClientId)

        let fetch = repository.fetchAllOperation(with: RepositoryFetchOptions())
        OperationQueue().addOperations([fetch], waitUntilFinished: true)

        XCTAssertTrue(try fetch.extractNoCancellableResultData().isEmpty)
        XCTAssertEqual(settings.gatewayAttestationProfile, AttestationProfile2.version)
    }

    func testAnInstallationAlreadyOnThisProfileKeepsItsIdentity() {
        let settings = InMemorySettingsManager()

        AttestationProfileMigrator.migrate(settingsManager: settings)

        let created = "6f2c1e4a-0000-4000-8000-000000000002"
        settings.gatewayAttestationClientId = created

        AttestationProfileMigrator.migrate(settingsManager: settings)

        XCTAssertEqual(settings.gatewayAttestationClientId, created)
    }
}
