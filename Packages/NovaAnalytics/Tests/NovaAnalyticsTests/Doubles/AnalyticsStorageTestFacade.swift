import Foundation
import CoreData
import Operation_iOS
@testable import NovaAnalytics

final class AnalyticsStorageTestFacade {
    private enum Constants {
        static let unreadableSequence: Int64 = 999
    }

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

    func seedUnreadableRow() throws {
        let repository = createRepository(mapper: AnyCoreDataMapper(CorruptAnalyticsEventMapper()))

        let operation = repository.saveOperation({
            [
                AnalyticsPendingEvent(
                    identifier: AnalyticsPendingEvent.identifier(for: Constants.unreadableSequence),
                    sequence: Constants.unreadableSequence,
                    name: "unreadable",
                    timestamp: Date(timeIntervalSince1970: 1),
                    payload: Data(),
                    consentEpoch: 0
                )
            ]
        }, { [] })

        OperationQueue().addOperations([operation], waitUntilFinished: true)

        try operation.extractNoCancellableResultData()
    }
}
