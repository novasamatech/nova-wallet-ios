import Foundation

final class SerialMigrator: Migrating {
    let migrations: [Migrating]

    init(migrations: [Migrating]) {
        self.migrations = migrations
    }

    func migrate() throws {
        try migrations.forEach { try $0.migrate() }
    }
}
