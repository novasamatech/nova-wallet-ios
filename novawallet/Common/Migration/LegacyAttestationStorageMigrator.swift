import Foundation
import Keystore_iOS
import NovaAuth

final class LegacyAttestationStorageMigrator: Migrating {
    let settingsManager: SettingsManagerProtocol

    init(settingsManager: SettingsManagerProtocol) {
        self.settingsManager = settingsManager
    }

    func migrate() throws {
        let didMigrateKey = "LegacyAttestationStorageMigrator.DidRemoveLegacyAttestation"

        let didMigrate = settingsManager.bool(for: didMigrateKey) ?? false

        guard !didMigrate else {
            return
        }

        ["gatewayAttestationClientId", "appAttestKeys"].forEach { key in
            settingsManager.removeValue(for: key)
        }

        try NovaAuth.removeLegacyBearer()

        settingsManager.set(value: true, for: didMigrateKey)
    }
}
