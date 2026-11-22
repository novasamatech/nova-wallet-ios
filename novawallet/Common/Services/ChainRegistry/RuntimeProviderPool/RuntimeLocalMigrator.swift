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
    // 3: metadata v16 is requested when the runtime has it, an item cached by a build that asked for v15 is refetched
    static let latest: UInt32 = 3
}

struct RuntimeLocalMigrator: RuntimeLocalMigrating {
    let version: UInt32
}

extension RuntimeLocalMigrator {
    static func createLatest() -> RuntimeLocalMigrator {
        RuntimeLocalMigrator(version: RuntimeLocalVersion.latest)
    }
}
