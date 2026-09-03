import Foundation
import Operation_iOS
import Foundation_iOS
import Keystore_iOS

final class AnalyticsServiceFacade {
    static let shared = AnalyticsServiceFacade()

    let consent: AnalyticsConsentManagerProtocol

    private let settingsManager: SettingsManagerProtocol
    private let service: AnalyticsService
    private let sessionTracker: AnalyticsSessionTracking

    private let mutex = NSLock()
    private var isActive: Bool = false

    private init() {
        // Built once, lazily, on first reference. Never under -UNITTEST: AppDelegate
        // returns before Root, so nothing reaches this in the unit-test process, where
        // the factory resolves to NoOpAnalyticsServiceFacade.
        let settingsManager = SettingsManager.shared

        let repository: CoreDataRepository<AnalyticsPendingEvent, CDAnalyticsEvent> =
            UserDataStorageFacade.shared.createRepository(
                filter: nil,
                sortDescriptors: [.analyticsEventsBySequence],
                mapper: AnyCoreDataMapper(AnalyticsPendingEventMapper())
            )

        let eventQueue = CoreDataAnalyticsEventQueue(
            repository: AnyDataProviderRepository(repository),
            operationQueue: OperationManagerFacade.analyticsQueue
        )

        let appAttest = AppAttestService()

        #if F_RELEASE
            let isReleaseBuild = true
        #else
            let isReleaseBuild = false
        #endif

        // The ladder's inputs are read here, at the factory, so the resolver itself
        // stays pure and unit-tested (spec §7.5).
        let attestationMode = BackendAttestationModeResolver.resolve(
            isReleaseBuild: isReleaseBuild,
            isAppAttestSupported: appAttest.isSupported
        )

        // The remote kill switch is wired later; the mode is the whole gate for now.
        let availability = AnalyticsAvailabilityProvider(attestationMode: attestationMode)

        let consent = AnalyticsConsentManager(
            settingsManager: settingsManager,
            availabilityProvider: availability
        )

        let gatewayURL = ApplicationConfig.shared.gatewayURL

        let attestKeyRepository: CoreDataRepository<AppAttestKeySettings, CDAppAttestKey> =
            UserDataStorageFacade.shared.createRepository(
                filter: nil,
                sortDescriptors: [],
                mapper: AnyCoreDataMapper(AppAttestKeyMapper())
            )

        // The provider signs on the shared queue: its wrapper chain nests, which a
        // serial queue could not run.
        let attestation = BackendAttestationProvider(
            appAttest: appAttest,
            remoteFactory: BackendAttestationRemoteFactory(baseURL: gatewayURL),
            identity: BackendAttestationIdentity(settingsManager: settingsManager),
            repository: AnyDataProviderRepository(attestKeyRepository),
            gatewayURL: gatewayURL,
            mode: attestationMode,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let identity = AnalyticsIdentity(settingsManager: settingsManager)

        let uploader = AnalyticsUploader(
            queue: eventQueue,
            identity: identity,
            attestation: attestation,
            uploadFactory: AnalyticsUploadOperationFactory(baseURL: gatewayURL),
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            appVersion: Self.appVersion
        )

        // Persistence runs on the serial analytics queue and the upload on the shared
        // network queue, so an event is stored while a slow POST is in flight.
        let service = AnalyticsService(
            consent: consent,
            availability: availability,
            queue: eventQueue,
            identity: identity,
            uploader: uploader,
            attestation: attestation,
            operationQueue: OperationManagerFacade.analyticsQueue,
            uploadOperationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let sessionTracker = AnalyticsSessionTracker(
            tracker: service,
            flushHandler: { [weak service] reason in service?.flush(reason: reason) },
            applicationHandler: ApplicationHandler(),
            backgroundTaskRunner: UIApplicationBackgroundTaskRunner()
        )

        self.settingsManager = settingsManager
        self.consent = consent
        self.service = service
        self.sessionTracker = sessionTracker

        // The opt-out wipe belongs to AnalyticsService, which observes the same manager.
        // The facade owns only the opt-in edge, which opens a session (spec §9).
        consent.addObserver(with: self, queue: nil) { [weak self] oldValue, newValue in
            guard !oldValue, newValue else {
                return
            }

            self?.sessionTracker.startSession()
        }
    }
}

// MARK: - AnalyticsServiceFacadeProtocol

extension AnalyticsServiceFacade: AnalyticsServiceFacadeProtocol {
    func setup() {
        mutex.lock()

        guard !isActive else {
            mutex.unlock()
            return
        }

        isActive = true
        mutex.unlock()

        sessionTracker.setup()
        sessionTracker.startSession()

        track(.appOpened(isFirstLaunch: settingsManager.isAppFirstLaunch))
        flush(reason: .launch)
    }

    /// A real symmetric throttle: nothing on the launch path calls it, but the kill
    /// switch and the tests do.
    func throttle() {
        mutex.lock()

        guard isActive else {
            mutex.unlock()
            return
        }

        isActive = false
        mutex.unlock()

        sessionTracker.throttle()
    }

    func track(_ event: AnalyticsEvent) {
        // track() depends on consent and availability only, never on isActive.
        service.track(event)
    }

    func flush(reason: AnalyticsFlushReason) {
        service.flush(reason: reason)
    }
}

// MARK: - Private

private extension AnalyticsServiceFacade {
    /// `CFBundleShortVersionString` only — `ApplicationConfig.version` appends the build
    /// number, which the gateway does not expect (spec §6.2).
    static var appVersion: String {
        let bundle = Bundle(for: AnalyticsServiceFacade.self)

        return bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
}
