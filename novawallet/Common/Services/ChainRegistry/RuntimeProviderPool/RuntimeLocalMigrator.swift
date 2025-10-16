import Foundation

protocol RuntimeLocalMigrating {
    var version: UInt32 { get }
}

extension RuntimeLocalMigrating {
    func needsMigration(for runtimeItem: RuntimeMetadataItem) -> Bool {
        runtimeItem.localMigratorVersion < version
    }
}

enum RuntimeLocalVersion {
    static let latest: UInt32 = 2
}

struct RuntimeLocalMigrator: RuntimeLocalMigrating {
    let version: UInt32
}

extension RuntimeLocalMigrator {
    static func createLatest() -> RuntimeLocalMigrator {
        RuntimeLocalMigrator(version: RuntimeLocalVersion.latest)
    }
}
