import Foundation
import Operation_iOS
@testable import NovaAnalytics

final class AnalyticsStorageTestFacade {
    private let databaseService = CoreDataService(
        configuration: CoreDataServiceConfiguration(
            modelURL: AnalyticsStorageFacade.modelURL,
            storageType: .inMemory
        )
    )

    func createEventRepository() -> CoreDataRepository<AnalyticsPendingEvent, CDAnalyticsEvent> {
        CoreDataRepository(
            databaseService: databaseService,
            mapper: AnyCoreDataMapper(AnalyticsPendingEventMapper()),
            filter: nil,
            sortDescriptors: [NSSortDescriptor.analyticsEventsBySequence]
        )
    }
}
