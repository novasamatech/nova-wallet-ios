import Operation_iOS
import CoreData

enum SubstrateStorageParams {
    static let databaseName = "SubstrateDataModel.sqlite"
    static let modelDirectory: String = "SubstrateDataModel.momd"
    static let modelVersion: SubstrateStorageVersion = .version38

    static let deprecatedStorageDirectoryURL: URL = {
        let baseURL = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first?.appendingPathComponent("CoreData")

        return baseURL!
    }()

    static let sharedStorageDirectoryURL: URL = {
        let baseURL = FileManager.default
            .containerURL(
                forSecurityApplicationGroupIdentifier: SharedContainerGroup.name
            )?.appendingPathComponent("CoreData")
        return baseURL!
    }()

    static var deprecatedStorageURL: URL {
        deprecatedStorageDirectoryURL.appendingPathComponent(databaseName)
    }

    static var sharedStorageURL: URL {
        sharedStorageDirectoryURL.appendingPathComponent(databaseName)
    }
}

class SubstrateDataStorageFacade: StorageFacadeProtocol {
    static let shared = SubstrateDataStorageFacade()

    let databaseService: CoreDataServiceProtocol

    private init() {
        let databaseName = SubstrateStorageParams.databaseName
        let modelName = SubstrateStorageParams.modelVersion.rawValue
        let bundle = Bundle.main

        let omoURL = bundle.url(
            forResource: modelName,
            withExtension: "omo",
            subdirectory: SubstrateStorageParams.modelDirectory
        )

        let momURL = bundle.url(
            forResource: modelName,
            withExtension: "mom",
            subdirectory: SubstrateStorageParams.modelDirectory
        )

        let modelURL = omoURL ?? momURL

        let persistentSettings = CoreDataPersistentSettings(
            databaseDirectory: SubstrateStorageParams.sharedStorageDirectoryURL,
            databaseName: databaseName,
            incompatibleModelStrategy: .ignore
        )

        let configuration = CoreDataServiceConfiguration(
            modelURL: modelURL!,
            storageType: .persistent(settings: persistentSettings)
        )

        databaseService = CoreDataService(configuration: configuration)
    }

    func createRepository<T, U>(
        filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor],
        mapper: AnyCoreDataMapper<T, U>
    ) -> CoreDataRepository<T, U> where T: Identifiable, U: NSManagedObject {
        CoreDataRepository(
            databaseService: databaseService,
            mapper: mapper,
            filter: filter,
            sortDescriptors: sortDescriptors
        )
    }
}
