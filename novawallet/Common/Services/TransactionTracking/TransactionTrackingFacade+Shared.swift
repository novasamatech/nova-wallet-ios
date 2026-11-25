import Foundation
import Foundation_iOS

extension TransactionTrackingFacade {
    static let shared: TransactionTrackingFacadeProtocol = {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let logger = Logger.shared
        let storageFacade = SubstrateDataStorageFacade.shared

        let trackers: [ChainTransactionTracking] = [
            EvmTransactionTracker(
                chainRegistry: chainRegistry,
                eventCenter: EventCenter.shared,
                operationQueue: operationQueue,
                logger: logger
            )
        ]

        let pickup = PendingTransactionPickup(
            storageFacade: storageFacade,
            chainRegistry: chainRegistry,
            trackers: trackers,
            logger: logger
        )

        return TransactionTrackingFacade(
            trackers: trackers,
            resolver: TransactionHistoryResolver(storageFacade: storageFacade),
            pickup: pickup,
            chainRegistry: chainRegistry,
            applicationHandler: ApplicationHandler(),
            eventCenter: EventCenter.shared,
            operationQueue: operationQueue,
            logger: logger
        )
    }()
}
