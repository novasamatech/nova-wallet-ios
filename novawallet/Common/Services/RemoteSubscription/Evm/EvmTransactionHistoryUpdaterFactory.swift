import Foundation

protocol EvmTransactionHistoryUpdaterFactoryProtocol {
    func createTransactionHistoryUpdater(
        for accountId: AccountId,
        assetContracts: Set<EvmAssetContractId>
    ) -> ContractTransactionHistoryUpdaterProtocol
}

final class EvmTransactionHistoryUpdaterFactory {
    let storageFacade: StorageFacadeProtocol
    let operationQueue: OperationQueue
    let eventCenter: EventCenterProtocol
    let chainRegistry: ChainRegistryProtocol
    let logger: LoggerProtocol

    init(
        storageFacade: StorageFacadeProtocol,
        chainRegistry: ChainRegistryProtocol,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.storageFacade = storageFacade
        self.chainRegistry = chainRegistry
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

extension EvmTransactionHistoryUpdaterFactory: EvmTransactionHistoryUpdaterFactoryProtocol {
    func createTransactionHistoryUpdater(
        for accountId: AccountId,
        assetContracts: Set<EvmAssetContractId>
    ) -> ContractTransactionHistoryUpdaterProtocol {
        let repository = SubstrateRepositoryFactory(storageFacade: storageFacade).createTxRepository()

        return ContractTransactionHistoryUpdater(
            repository: repository,
            chainRegistry: chainRegistry,
            operationQueue: operationQueue,
            eventCenter: eventCenter,
            accountId: accountId,
            assetContracts: assetContracts,
            logger: logger
        )
    }
}
