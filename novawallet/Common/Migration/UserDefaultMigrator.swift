import Foundation
import Keystore_iOS

final class SharedSettingsMigrator: Migrating {
    let settingsManager: SettingsManagerProtocol
    let sharedSettingsManager: SettingsManagerProtocol?

    init(
        settingsManager: SettingsManagerProtocol,
        sharedSettingsManager: SettingsManagerProtocol?
    ) {
        self.settingsManager = settingsManager
        self.sharedSettingsManager = sharedSettingsManager
    }

    func migrate() throws {
        let didMigrateKey = "SharedSettingsMigrator.DidMigrateToAppGroups"

        guard let sharedSettingsManager = sharedSettingsManager else {
            return
        }

        let didMigrate = sharedSettingsManager.bool(for: didMigrateKey) ?? false

        guard !didMigrate else {
            return
        }

        SharedSettingsKey.allCases.forEach { key in
            if let value = settingsManager.anyValue(for: key.rawValue) {
                sharedSettingsManager.set(anyValue: value, for: key.rawValue)
            } else {
                sharedSettingsManager.removeValue(for: key.rawValue)
            }
        }

        sharedSettingsManager.set(value: true, for: didMigrateKey)
    }
}
