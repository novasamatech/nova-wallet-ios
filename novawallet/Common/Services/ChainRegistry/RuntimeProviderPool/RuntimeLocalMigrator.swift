import Foundation

protocol RuntimeLocalMigrating {
    var version: UInt32 { get }
}

extension RuntimeLocalMigrating {
    func needsMigration(for runtimeItem: RuntimeMetadataItem) -> Bool {
        runtimeItem.localMigratorVersion < version
    }
}

struct RuntimeLocalMigrator: RuntimeLocalMigrating {
    let version: UInt32 = 2
}
