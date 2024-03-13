import Foundation
import CoreData

final class StorePathMigrator: Migrating {
    let fileManager: FileManager
    let currentStoreLocation: URL
    let sharedStoreLocation: URL

    init(
        currentStoreLocation: URL,
        sharedStoreLocation: URL,
        fileManager: FileManager
    ) {
        self.currentStoreLocation = currentStoreLocation
        self.sharedStoreLocation = sharedStoreLocation
        self.fileManager = fileManager
    }

    func requiresMigration() -> Bool {
        guard !fileManager.fileExists(atPath: sharedStoreLocation.path) else {
            return false
        }
        return fileManager.fileExists(atPath: currentStoreLocation.path)
    }

    func migrate() throws {
        guard requiresMigration() else {
            return
        }
        
        try NSPersistentStoreCoordinator.replaceStore(
            at: sharedStoreLocation,
            withStoreAt: currentStoreLocation
        )
        
        try NSPersistentStoreCoordinator.destroyStore(at: currentStoreLocation)
    }
}
