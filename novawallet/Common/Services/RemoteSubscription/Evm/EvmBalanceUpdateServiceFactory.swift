import Foundation
import Core
import SubstrateSdk
import RobinHood

protocol EvmBalanceUpdateServiceFactoryProtocol {
    func createERC20BalanceUpdateService(
        for holder: AccountAddress,
        chainId: ChainModel.Id,
        assetContracts: Set<EvmAssetContractId>,
        blockNumber: Core.BlockNumber,
        completionClosure: ERC20BalanceUpdateServiceCompletionClosure?
    ) throws -> SyncServiceProtocol
}

final class EvmBalanceUpdateServiceFactory {
    let storageFacade: StorageFacadeProtocol
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol?

    init(
        storageFacade: StorageFacadeProtocol,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol?
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
        blockNumber: Core.BlockNumber,
        completionClosure: ERC20BalanceUpdateServiceCompletionClosure?
    ) throws -> SyncServiceProtocol {
        guard let connection = chainRegistry.getConnection(for: chainId) else {
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
            repository: AnyDataProviderRepository(repository),
            operationQueue: operationQueue,
            blockNumber: blockNumber,
            queryMessageFactory: EvmQueryContractMessageFactory(),
            logger: logger,
            completion: completionClosure
        )
    }
}
