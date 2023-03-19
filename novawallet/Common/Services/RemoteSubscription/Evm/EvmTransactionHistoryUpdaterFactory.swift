import Foundation

protocol EvmTransactionHistoryUpdaterFactoryProtocol {
    func createCustomAssetHistoryUpdater(
        for accountId: AccountId,
        assetContracts: Set<EvmAssetContractId>
    ) -> ContractTransactionHistoryUpdaterProtocol

    func createNativeAssetHistoryUpdater(
        for accountId: AccountId,
        chainAssetId: ChainAssetId
    ) throws -> EvmNativeTransactionHistoryUpdaterProtocol
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
    func createCustomAssetHistoryUpdater(
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

    func createNativeAssetHistoryUpdater(
        for accountId: AccountId,
        chainAssetId: ChainAssetId
    ) throws -> EvmNativeTransactionHistoryUpdaterProtocol {
        let repository = SubstrateRepositoryFactory(storageFacade: storageFacade).createTxRepository()

        guard let connection = chainRegistry.getConnection(for: chainAssetId.chainId) else {
            throw ChainRegistryError.connectionUnavailable
        }

        let operationFactory = EvmWebSocketOperationFactory(connection: connection)

        return EvmNativeTransactionHistoryUpdater(
            chainAssetId: chainAssetId,
            repository: repository,
            operationFactory: operationFactory,
            operationQueue: operationQueue,
            eventCenter: eventCenter,
            accountId: accountId,
            logger: logger
        )
    }
}
