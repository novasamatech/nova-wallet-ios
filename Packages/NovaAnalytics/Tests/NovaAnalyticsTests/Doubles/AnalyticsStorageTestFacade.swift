import Foundation
import CoreData
import Operation_iOS
@testable import NovaAnalytics

final class AnalyticsStorageTestFacade {
    let databaseService: CoreDataServiceProtocol

    init() {
        databaseService = CoreDataService(
            configuration: CoreDataServiceConfiguration(
                modelURL: AnalyticsStorageFacade.modelURL,
                storageType: .inMemory
            )
        )
    }

    func createEventRepository() -> CoreDataRepository<AnalyticsPendingEvent, CDAnalyticsEvent> {
        createRepository(mapper: AnyCoreDataMapper(AnalyticsPendingEventMapper()))
    }

    func createRepository(
        mapper: AnyCoreDataMapper<AnalyticsPendingEvent, CDAnalyticsEvent>
    ) -> CoreDataRepository<AnalyticsPendingEvent, CDAnalyticsEvent> {
        CoreDataRepository(
            databaseService: databaseService,
            mapper: mapper,
            filter: nil,
            sortDescriptors: [NSSortDescriptor.analyticsEventsBySequence]
        )
    }
}
