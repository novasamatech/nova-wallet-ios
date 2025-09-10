import Foundation
import Web3Core
import SubstrateSdk
import Operation_iOS

protocol EvmBalanceUpdateServiceFactoryProtocol {
    func createERC20BalanceUpdateService(
        for holder: AccountAddress,
        chainId: ChainModel.Id,
        assetContracts: Set<EvmAssetContractId>,
        block: EvmBalanceUpdateBlock,
        completionClosure: ERC20UpdateServiceCompletionClosure?
    ) throws -> SyncServiceProtocol

    func createNativeBalanceUpdateService(
        for holder: AccountAddress,
        chainAssetId: ChainAssetId,
        block: EvmBalanceUpdateBlock,
        completionClosure: EvmNativeUpdateServiceCompletionClosure?
    ) throws -> SyncServiceProtocol
}

final class EvmBalanceUpdateServiceFactory {
    let storageFacade: StorageFacadeProtocol
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        storageFacade: StorageFacadeProtocol,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.storageFacade = storageFacade
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

extension EvmBalanceUpdateServiceFactory: EvmBalanceUpdateServiceFactoryProtocol {
    func createERC20BalanceUpdateService(
        for holder: AccountAddress,
        chainId: ChainModel.Id,
        assetContracts: Set<EvmAssetContractId>,
        block: EvmBalanceUpdateBlock,
        completionClosure: ERC20UpdateServiceCompletionClosure?
    ) throws -> SyncServiceProtocol {
        guard let connection = chainRegistry.getOneShotConnection(for: chainId) else {
            throw ChainRegistryError.connectionUnavailable
        }

        let accountId = try holder.toEthereumAccountId()

        let mapper = AssetBalanceMapper()
        let filter = NSPredicate.assetBalance(for: chainId, accountId: accountId)
        let repository = storageFacade.createRepository(
            filter: filter,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        return ERC20BalanceUpdateService(
            holder: holder,
            assetContracts: assetContracts,
            connection: connection,
            updateHandler: EvmBalanceUpdatePersistentHandler(
                repository: AnyDataProviderRepository(repository),
                operationQueue: operationQueue
            ),
            operationQueue: operationQueue,
            block: block,
            queryMessageFactory: EvmQueryContractMessageFactory(),
            workQueue: .global(),
            logger: logger,
            completion: completionClosure
        )
    }

    func createNativeBalanceUpdateService(
        for holder: AccountAddress,
        chainAssetId: ChainAssetId,
        block: EvmBalanceUpdateBlock,
        completionClosure: EvmNativeUpdateServiceCompletionClosure?
    ) throws -> SyncServiceProtocol {
        guard let connection = chainRegistry.getOneShotConnection(for: chainAssetId.chainId) else {
            throw ChainRegistryError.connectionUnavailable
        }

        let accountId = try holder.toEthereumAccountId()

        let mapper = AssetBalanceMapper()
        let filter = NSPredicate.assetBalance(
            for: accountId,
            chainId: chainAssetId.chainId,
            assetId: chainAssetId.assetId
        )

        let repository = storageFacade.createRepository(
            filter: filter,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        return EvmNativeBalanceUpdateService(
            holder: holder,
            chainAssetId: chainAssetId,
            connection: connection,
            updateHandler: EvmBalanceUpdatePersistentHandler(
                repository: AnyDataProviderRepository(repository),
                operationQueue: operationQueue
            ),
            operationQueue: operationQueue,
            workQueue: .global(),
            block: block,
            logger: logger,
            completion: completionClosure
        )
    }
}
