import Foundation
import Operation_iOS
import CoreData

enum UserStorageParams {
    /**
     *  Controls which version of the UserDataModel to use
     *  and also allows to understand how to do migration.
     *  If there are changes that need to be applied to the model
     *  go ahead with the following steps:
     *  - create new version of the UserDataModel (for example, MultiassetUserDataModel5);
     *  - add new case to UserStorageVersion and set associated value to the data model version name;
     *  - add transition to UserStorageVersion.nextVersion;
     *  - if lightweight migration is not an option then add MigrationMapping
     *  and implement migration policy;
     *  - update mappings between CoreData Entities and App Models;
     *  - switch version of UserStorageParams.modelVersion;
     */
    static let modelVersion: UserStorageVersion = .version18
    static let modelDirectory: String = "UserDataModel.momd"
    static let databaseName = "UserDataModel.sqlite"

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

class UserDataStorageFacade: StorageFacadeProtocol {
    static let shared = UserDataStorageFacade()

    let databaseService: CoreDataServiceProtocol

    private init() {
        let modelName = UserStorageParams.modelVersion.rawValue
        let bundle = Bundle.main

        let omoURL = bundle.url(
            forResource: modelName,
            withExtension: "omo",
            subdirectory: UserStorageParams.modelDirectory
        )

        let momURL = bundle.url(
            forResource: modelName,
            withExtension: "mom",
            subdirectory: UserStorageParams.modelDirectory
        )

        let modelURL = omoURL ?? momURL

        let persistentSettings = CoreDataPersistentSettings(
            databaseDirectory: UserStorageParams.sharedStorageDirectoryURL,
            databaseName: UserStorageParams.databaseName,
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
