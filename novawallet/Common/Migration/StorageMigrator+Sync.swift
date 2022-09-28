import Foundation

extension UserStorageMigrator: Migrating {
    func migrate() throws {
        guard requiresMigration() else {
            return
        }

        performMigration()

        Logger.shared.info("User storage migration was completed")
    }
}

extension SubstrateStorageMigrator: Migrating {
    func migrate() throws {
        guard requiresMigration() else {
            return
        }

        performMigration()

        Logger.shared.info("Substrate storage migration was completed")
    }
}
