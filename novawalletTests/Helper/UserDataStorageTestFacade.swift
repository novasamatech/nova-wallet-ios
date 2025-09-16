import Foundation
@testable import novawallet
import Operation_iOS
import CoreData

class UserDataStorageTestFacade: StorageFacadeProtocol {
    let databaseService: CoreDataServiceProtocol

    init() {
        let modelName = UserStorageParams.modelVersion.rawValue
        let subdirectory = UserStorageParams.modelDirectory
        let bundle = Bundle.main

        let omoURL = bundle.url(
            forResource: modelName,
            withExtension: "omo",
            subdirectory: subdirectory
        )

        let momURL = bundle.url(
            forResource: modelName,
            withExtension: "mom",
            subdirectory: subdirectory
        )

        let modelURL = omoURL ?? momURL

        let configuration = CoreDataServiceConfiguration(
            modelURL: modelURL!,
            storageType: .inMemory
        )

        databaseService = CoreDataService(configuration: configuration)
    }

    func createRepository<T, U>(
        filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor],
        mapper: AnyCoreDataMapper<T, U>
    ) -> CoreDataRepository<T, U>
        where T: Identifiable, U: NSManagedObject {
        CoreDataRepository(
            databaseService: databaseService,
            mapper: mapper,
            filter: filter,
            sortDescriptors: sortDescriptors
        )
    }
}
