import Foundation
import CoreData
import Operation_iOS

/// The analytics queue's own store, separate from the app's `UserDataModel.sqlite`.
public final class AnalyticsStorageFacade {
    public static let databaseName = "AnalyticsDataModel.sqlite"

    private let databaseService: CoreDataServiceProtocol

    public init(storeDirectory: URL) {
        let settings = CoreDataPersistentSettings(
            databaseDirectory: storeDirectory,
            databaseName: Self.databaseName,
            incompatibleModelStrategy: .removeStore,
            excludeFromiCloudBackup: true
        )

        databaseService = CoreDataService(
            configuration: CoreDataServiceConfiguration(
                modelURL: Self.modelURL,
                storageType: .persistent(settings: settings)
            )
        )
    }

    public func createEventRepository() -> AnyDataProviderRepository<AnalyticsPendingEvent> {
        let repository = CoreDataRepository<AnalyticsPendingEvent, CDAnalyticsEvent>(
            databaseService: databaseService,
            mapper: AnyCoreDataMapper(AnalyticsPendingEventMapper()),
            filter: nil,
            sortDescriptors: [NSSortDescriptor.analyticsEventsBySequence]
        )

        return AnyDataProviderRepository(repository)
    }
}

// MARK: - Internal

extension AnalyticsStorageFacade {
    static var modelURL: URL {
        guard let url = Bundle.module.url(
            forResource: "AnalyticsDataModel",
            withExtension: "momd"
        ) else {
            fatalError("AnalyticsDataModel.momd missing from the package bundle")
        }

        return url
    }
}
