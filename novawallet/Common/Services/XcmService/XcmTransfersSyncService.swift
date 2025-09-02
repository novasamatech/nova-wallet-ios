import Foundation

protocol XcmTransfersSyncServiceProtocol: AnyObject, ApplicationServiceProtocol {
    var notificationCallback: ((Result<XcmTransfers, Error>) -> Void)? { get set }
    var notificationQueue: DispatchQueue { get set }
}

final class XcmTransfersSyncService {
    let legacySyncService: XcmGenericTransfersSyncService<XcmLegacyTransfers>
    let dynamicSyncService: XcmGenericTransfersSyncService<XcmDynamicTransfers>

    private var legacyResult: Result<XcmLegacyTransfers, Error>?
    private var dynamicResult: Result<XcmDynamicTransfers, Error>?

    var notificationCallback: ((Result<XcmTransfers, Error>) -> Void)?
    var notificationQueue: DispatchQueue = .main

    private let syncQueue = DispatchQueue(label: "com.nova.wallet.xcm.sync.service")

    init(
        legacySyncService: XcmGenericTransfersSyncService<XcmLegacyTransfers>,
        dynamicSyncService: XcmGenericTransfersSyncService<XcmDynamicTransfers>
    ) {
        self.legacySyncService = legacySyncService
        self.dynamicSyncService = dynamicSyncService
    }
}

private extension XcmTransfersSyncService {
    func getResult() -> Result<XcmTransfers, Error>? {
        guard let legacyResult = legacyResult, let dynamicResult = dynamicResult else {
            return nil
        }

        do {
            let legacy = try legacyResult.get()
            let dynamic = try dynamicResult.get()

            let transfers = XcmTransfers(legacyTransfers: legacy, dynamicTransfers: dynamic)

            return .success(transfers)
        } catch {
            return .failure(error)
        }
    }

    func notifyIfReady() {
        guard let result = getResult(), let notificationCallback else {
            return
        }

        dispatchInQueueWhenPossible(notificationQueue) {
            notificationCallback(result)
        }
    }
}

extension XcmTransfersSyncService: XcmTransfersSyncServiceProtocol {
    func setup() {
        legacySyncService.notificationQueue = syncQueue
        dynamicSyncService.notificationQueue = syncQueue

        legacySyncService.notificationCallback = { [weak self] result in
            guard let self else {
                return
            }

            legacyResult = result
            notifyIfReady()
        }

        dynamicSyncService.notificationCallback = { [weak self] result in
            guard let self else {
                return
            }

            dynamicResult = result
            notifyIfReady()
        }

        legacySyncService.setup()
        dynamicSyncService.setup()
    }

    func throttle() {
        legacySyncService.throttle()
        dynamicSyncService.throttle()
    }
}

extension XcmTransfersSyncService {
    convenience init(
        config: ApplicationConfigProtocol,
        operationQueue: OperationQueue = OperationManagerFacade.sharedDefaultQueue,
        logger: LoggerProtocol = Logger.shared
    ) {
        let legacySyncService = XcmLegacyTransfersSyncService(
            remoteUrl: config.xcmTransfersURL,
            operationQueue: operationQueue,
            logger: logger
        )

        let dynamicSyncService = XcmDynamicTransfersSyncService(
            remoteUrl: config.xcmDynamicTransfersURL,
            operationQueue: operationQueue,
            logger: logger
        )

        self.init(legacySyncService: legacySyncService, dynamicSyncService: dynamicSyncService)
    }
}
