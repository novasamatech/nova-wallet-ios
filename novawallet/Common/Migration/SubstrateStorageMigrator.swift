import Foundation
import CoreData

final class SubstrateStorageMigrator {
    let modelDirectory: String
    let model: SubstrateStorageVersion
    let storeURL: URL
    let fileManager: FileManager

    init(
        storeURL: URL,
        modelDirectory: String,
        model: SubstrateStorageVersion,
        fileManager: FileManager
    ) {
        self.storeURL = storeURL
        self.model = model
        self.modelDirectory = modelDirectory
        self.fileManager = fileManager
    }
}

// MARK: - StorageMigrating

extension SubstrateStorageMigrator: StorageMigrating {
    func requiresMigration() -> Bool {
        checkIfMigrationNeeded(
            to: SubstrateStorageVersion.current,
            storeURL: storeURL,
            fileManager: fileManager,
            modelDirectory: modelDirectory
        )
    }

    func performMigration() {
        let destinationVersion = SubstrateStorageVersion.current

        let mom = createManagedObjectModel(
            forResource: destinationVersion.rawValue,
            modelDirectory: modelDirectory
        )

        let psc = NSPersistentStoreCoordinator(managedObjectModel: mom)
        let options = [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true
        ]
        do {
            try psc.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: storeURL,
                options: options
            )
        } catch {
            fatalError("Failed to add persistent store: \(error)")
        }
    }

    func migrate(_ completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.performMigration()

            DispatchQueue.main.async {
                completion()
            }
        }
    }
}
