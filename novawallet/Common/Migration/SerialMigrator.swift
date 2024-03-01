import Foundation

final class SerialMigrator: Migrating {
    let migration: Migrating
    let dependentMigration: Migrating

    init(
        migration: Migrating,
        dependentMigration: Migrating
    ) {
        self.migration = migration
        self.dependentMigration = dependentMigration
    }

    func migrate() throws {
        try migration.migrate()
        try dependentMigration.migrate()
    }
}
