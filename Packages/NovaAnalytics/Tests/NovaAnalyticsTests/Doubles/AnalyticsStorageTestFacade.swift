import Foundation
import CoreData
import Operation_iOS
@testable import NovaAnalytics

/// Replaces `novawalletTests/Helper/UserDataStorageTestFacade.swift`, which is an in-memory
/// `CoreDataService` over the *app's* `UserDataModel` and therefore cannot come along.
///
/// It reaches `AnalyticsStorageFacade.modelURL` through `@testable` rather than going
/// through the production type, because `AnalyticsEventQueueTests` needs a *second*
/// repository over a *different* mapper sharing one store — a seam the production facade
/// would only get by growing a generic repository factory it has no other use for.
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

    /// The production pairing of mapper and sort descriptor, so a test store orders rows
    /// exactly as `AnalyticsStorageFacade.createEventRepository()` does.
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
