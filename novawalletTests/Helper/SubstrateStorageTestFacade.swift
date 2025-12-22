import Foundation
@testable import novawallet
import Operation_iOS
import CoreData

class SubstrateStorageTestFacade: StorageFacadeProtocol {
    let databaseService: CoreDataServiceProtocol

    init() {
        let modelName = "SubstrateDataModel"
        let modelURL = Bundle.main.url(forResource: modelName, withExtension: "momd")

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
