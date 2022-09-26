import CoreData

extension StorageMigrating {
    typealias Version = CaseIterable & RawRepresentable & Equatable

    func checkIfMigrationNeeded<T>(
        to version: T,
        storeURL: URL,
        fileManager: FileManager,
        modelDirectory: String
    ) -> Bool where T: Version, T.RawValue == String {
        let storageExists = fileManager.fileExists(atPath: storeURL.path)

        guard storageExists else {
            return false
        }

        guard let metadata = NSPersistentStoreCoordinator.metadata(at: storeURL) else {
            return false
        }

        let compatibleVersion = T.allCases.first {
            let model = createManagedObjectModel(forResource: $0.rawValue, modelDirectory: modelDirectory)
            return model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
        }

        return compatibleVersion != version
    }

    func compatibleVersionForStoreMetadata<T>(
        _ metadata: [String: Any],
        modelDirectory: String
    ) -> T? where T: Version, T.RawValue == String {
        let compatibleVersion = T.allCases.first {
            let model = createManagedObjectModel(forResource: $0.rawValue, modelDirectory: modelDirectory)
            return model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
        }

        return compatibleVersion
    }

    func createManagedObjectModel(forResource resource: String, modelDirectory: String) -> NSManagedObjectModel {
        let bundle = Bundle.main
        let omoURL = bundle.url(
            forResource: resource,
            withExtension: "omo",
            subdirectory: modelDirectory
        )

        let momURL = bundle.url(
            forResource: resource,
            withExtension: "mom",
            subdirectory: modelDirectory
        )

        guard
            let modelURL = omoURL ?? momURL,
            let model = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Unable to load model in bundle for resource \(resource)")
        }

        return model
    }
}
