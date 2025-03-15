import Foundation

protocol XcmTransfersSyncServiceProtocol: AnyObject, ApplicationServiceProtocol {
    var notificationCallback: ((XcmTransfersResult) -> Void)? { get set }
    var notificationQueue: DispatchQueue { get set }
}

final class XcmTransfersSyncService {
    let legacySyncService: XcmGenericTransfersSyncService<XcmLegacyTransfers>
    let dynamicSyncService: XcmGenericTransfersSyncService<XcmDynamicTransfers>

    private var legacyResult: Result<XcmLegacyTransfers, Error>?
    private var dynamicResult: Result<XcmDynamicTransfers, Error>?

    var notificationCallback: ((XcmTransfersResult) -> Void)?
    var notificationQueue: DispatchQueue

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
    func notifyIfReady() {
        guard let legacyResult = legacyResult, let dynamicResult = dynamicResult else {
            return
        }

        let transfers = XcmTransfersResult(
            legacyTransfersResult: legacyResult,
            dynamicTransfersResult: dynamicResult
        )

        dispatchInQueueWhenPossible(notificationQueue) {
            self.notificationCallback?(transfers)
        }
    }
}

extension XcmTransfersSyncService: XcmTransfersSyncServiceProtocol {
    func setup() {
        legacySyncService.notificationQueue = syncQueue
        dynamicSyncService.notificationQueue = syncQueue

        legacySyncService.notificationCallback = { [weak self] result in
            guard self else {
                return
            }

            legacyResult = result
            notifyIfReady()
        }

        dynamicSyncService.notificationCallback = { [weak self] result in
            guard self else {
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
