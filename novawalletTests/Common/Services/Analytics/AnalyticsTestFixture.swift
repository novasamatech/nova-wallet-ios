import XCTest
@testable import novawallet
import Operation_iOS
import Keystore_iOS
import Cuckoo

/// A fixture builder, not a protocol double. Everything except the uploader is the
/// production object: the real queue over an in-memory store, the real settings, the
/// real consent manager and the real identity.
struct AnalyticsTestFixture {
    let service: AnalyticsService
    let consent: AnalyticsConsentManager
    let queue: CoreDataAnalyticsEventQueue
    let settings: InMemorySettingsManager
    let uploader: MockAnalyticsUploading
    let operationQueue: OperationQueue
    let uploadOperationQueue: OperationQueue
}

extension AnalyticsTestFixture {
    static func make(
        isAvailable: Bool = true,
        now: @escaping () -> Date = { Date() }
    ) -> AnalyticsTestFixture {
        let facade = UserDataStorageTestFacade()
        let repository: CoreDataRepository<AnalyticsPendingEvent, CDAnalyticsEvent> =
            facade.createRepository(
                filter: nil,
                sortDescriptors: [.analyticsEventsBySequence],
                mapper: AnyCoreDataMapper(AnalyticsPendingEventMapper())
            )

        let eventQueue = CoreDataAnalyticsEventQueue(
            repository: AnyDataProviderRepository(repository),
            operationQueue: OperationQueue(),
            maxCount: 500
        )

        let settings = InMemorySettingsManager()

        let availability = AnalyticsAvailabilityProvider(
            attestationMode: isAvailable ? .appAttest : .unavailable
        )

        let consent = AnalyticsConsentManager(
            settingsManager: settings,
            availabilityProvider: availability
        )

        let uploader = MockAnalyticsUploading()
        stub(uploader) { stub in
            when(stub.flushWrapper(maxBatches: any())).then { _ in
                CompoundOperationWrapper<Void>.createWithResult(())
            }
        }

        // Serial, exactly as OperationManagerFacade.analyticsQueue is: two enqueues in
        // flight at once would race for the same sequence number.
        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1

        let uploadOperationQueue = OperationQueue()

        let service = AnalyticsService(
            consent: consent,
            availability: availability,
            queue: eventQueue,
            identity: AnalyticsIdentity(settingsManager: settings),
            uploader: uploader,
            operationQueue: operationQueue,
            uploadOperationQueue: uploadOperationQueue,
            timeProvider: now,
            logger: Logger.shared
        )

        return AnalyticsTestFixture(
            service: service,
            consent: consent,
            queue: eventQueue,
            settings: settings,
            uploader: uploader,
            operationQueue: operationQueue,
            uploadOperationQueue: uploadOperationQueue
        )
    }

    static func makeConsented(now: @escaping () -> Date = { Date() }) -> AnalyticsTestFixture {
        let fixture = make(now: now)
        fixture.consent.setEnabled(true)

        return fixture
    }

    /// Enqueue, count and clear all land on the service's serial queue, so waiting on it
    /// is the whole synchronisation the assertions need. Never a sleep.
    func drain() {
        operationQueue.waitUntilAllOperationsAreFinished()
    }

    func queueCount() throws -> Int {
        drain()

        let operation = queue.countOperation()
        OperationQueue().addOperations([operation], waitUntilFinished: true)

        return try operation.extractNoCancellableResultData()
    }

    func peekNames() throws -> [String] {
        drain()

        let wrapper = queue.peekWrapper(count: 500)
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData().map(\.name)
    }

    func persistedInstallId() -> String? {
        settings.string(for: SettingsKey.analyticsInstallId.rawValue)
    }

    func track(_ count: Int, _ event: @autoclosure () -> AnalyticsEvent) {
        for _ in 0 ..< count {
            service.track(event())
        }
    }
}
