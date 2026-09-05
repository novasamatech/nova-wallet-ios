import Foundation
import CoreData
import Operation_iOS

/// The analytics queue's own store, separate from the app's `UserDataModel.sqlite`.
///
/// Two settings differ from the app's user store deliberately, because this holds unsent
/// telemetry rather than user data: an incompatible future model drops the queue instead of
/// crashing at launch, and unsent events must not enter iCloud backups.
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
    /// Deliberately `internal`: the model's location is not part of the contract in spec
    /// §5.1, and the only reader outside this type is the package's own test store, which
    /// reaches it through `@testable`.
    ///
    /// `Bundle.module` is the SwiftPM resource bundle. `momc` compiles
    /// `Resources/AnalyticsDataModel.xcdatamodeld` into it only because the target declares
    /// `resources: [.process("Resources")]`, so a nil here means that declaration was lost.
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
