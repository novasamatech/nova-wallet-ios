import Foundation
import CoreData

final class StorePathMigrator: Migrating {
    let fileManager: FileManager
    let currentStoreLocation: URL
    let sharedStoreLocation: URL
    let sharedStoreDirectory: URL

    init(
        currentStoreLocation: URL,
        sharedStoreLocation: URL,
        sharedStoreDirectory: URL,
        fileManager: FileManager
    ) {
        self.currentStoreLocation = currentStoreLocation
        self.sharedStoreLocation = sharedStoreLocation
        self.sharedStoreDirectory = sharedStoreDirectory
        self.fileManager = fileManager
    }

    private func requiresMigration() -> Bool {
        guard !fileManager.fileExists(atPath: sharedStoreLocation.path) else {
            return false
        }
        return fileManager.fileExists(atPath: currentStoreLocation.path)
    }

    private func createSharedStoreDirectoryIfNotExists() throws {
        var isDirectory: ObjCBool = false
        if
            !fileManager.fileExists(atPath: sharedStoreDirectory.path, isDirectory: &isDirectory) ||
            !isDirectory.boolValue {
            try fileManager.createDirectory(at: sharedStoreDirectory, withIntermediateDirectories: true)
        }
    }

    func migrate() throws {
        guard requiresMigration() else {
            return
        }

        try createSharedStoreDirectoryIfNotExists()

        try NSPersistentStoreCoordinator.replaceStore(
            at: sharedStoreLocation,
            withStoreAt: currentStoreLocation
        )

        try NSPersistentStoreCoordinator.destroyStore(at: currentStoreLocation)
    }
}
