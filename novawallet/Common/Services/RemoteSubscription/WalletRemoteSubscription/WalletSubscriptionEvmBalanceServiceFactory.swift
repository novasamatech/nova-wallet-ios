import Foundation
import Core

final class WalletSubscriptionEvmBalanceServiceFactory {
    let chainRegistry: ChainRegistryProtocol
    let updateHandler: EvmBalanceUpdateHandling
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        updateHandler: EvmBalanceUpdateHandling,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.updateHandler = updateHandler
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

extension WalletSubscriptionEvmBalanceServiceFactory: EvmBalanceUpdateServiceFactoryProtocol {
    func createERC20BalanceUpdateService(
        for holder: AccountAddress,
        chainId: ChainModel.Id,
        assetContracts: Set<EvmAssetContractId>,
        block: EvmBalanceUpdateBlock,
        completionClosure: ERC20UpdateServiceCompletionClosure?
    ) throws -> SyncServiceProtocol {
        let connection = try chainRegistry.getOneShotConnectionOrError(for: chainId)

        return ERC20BalanceUpdateService(
            holder: holder,
            assetContracts: assetContracts,
            connection: connection,
            updateHandler: updateHandler,
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
        let connection = try chainRegistry.getOneShotConnectionOrError(for: chainAssetId.chainId)

        return EvmNativeBalanceUpdateService(
            holder: holder,
            chainAssetId: chainAssetId,
            connection: connection,
            updateHandler: updateHandler,
            operationQueue: operationQueue,
            workQueue: .global(),
            block: block,
            logger: logger,
            completion: completionClosure
        )
    }
}
