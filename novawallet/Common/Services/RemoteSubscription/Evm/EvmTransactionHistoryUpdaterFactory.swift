import Foundation

protocol EvmTransactionHistoryUpdaterFactoryProtocol {
    func createTransactionHistoryUpdater(
        for accountId: AccountId,
        assetContracts: Set<EvmAssetContractId>
    ) -> EvmTransactionHistoryUpdaterProtocol
}

final class EvmTransactionHistoryUpdaterFactory {
    let storageFacade: StorageFacadeProtocol
    let operationQueue: OperationQueue
    let eventCenter: EventCenterProtocol

    init(
        storageFacade: StorageFacadeProtocol,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue
    ) {
        self.storageFacade = storageFacade
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
    }
}

extension EvmTransactionHistoryUpdaterFactory: EvmTransactionHistoryUpdaterFactoryProtocol {
    func createTransactionHistoryUpdater(
        for accountId: AccountId,
        assetContracts: Set<EvmAssetContractId>
    ) -> EvmTransactionHistoryUpdaterProtocol {
        let repository = SubstrateRepositoryFactory(storageFacade: storageFacade).createTxRepository()

        return EvmTransactionHistoryUpdater(
            repository: repository,
            operationQueue: operationQueue,
            eventCenter: eventCenter,
            accountId: accountId,
            assetContracts: assetContracts
        )
    }
}
