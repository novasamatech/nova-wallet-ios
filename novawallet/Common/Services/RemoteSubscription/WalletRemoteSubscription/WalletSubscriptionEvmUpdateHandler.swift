import Foundation
import Operation_iOS
import Web3Core
import SubstrateSdk

final class WalletSubscriptionEvmUpdateHandler {
    let chainAssetId: ChainAssetId
    let callbackQueue: DispatchQueue
    let callbackClosure: (WalletRemoteSubscriptionUpdate) -> Void
    let blockNumberMapper: BlockNumberToHashMapping?

    init(
        chainAssetId: ChainAssetId,
        blockNumberMapper: BlockNumberToHashMapping?,
        callbackQueue: DispatchQueue,
        callbackClosure: @escaping (WalletRemoteSubscriptionUpdate) -> Void
    ) {
        self.chainAssetId = chainAssetId
        self.blockNumberMapper = blockNumberMapper
        self.callbackQueue = callbackQueue
        self.callbackClosure = callbackClosure
    }
}

private extension WalletSubscriptionEvmUpdateHandler {
    func createBlockHashWrapper(for block: Web3Core.BlockNumber?) -> CompoundOperationWrapper<Data?> {
        guard
            let blockNumberMapper,
            case let .exact(number) = block, let blockNumber = BlockNumber(exactly: number) else {
            return .createWithResult(nil)
        }

        return blockNumberMapper.createBlockHashMappingWrapper(for: blockNumber)
    }
}

extension WalletSubscriptionEvmUpdateHandler: EvmBalanceUpdateHandling {
    func onBalanceUpdateWrapper(
        balances: [ChainAssetId: Balance],
        holder: AccountAddress,
        block: Web3Core.BlockNumber?
    ) -> CompoundOperationWrapper<Bool> {
        let blockHashWrapper = createBlockHashWrapper(for: block)

        let notificationOperation = ClosureOperation<Bool> {
            guard let newBalance = balances[self.chainAssetId] else {
                return false
            }

            let blockHash = try blockHashWrapper.targetOperation.extractNoCancellableResultData()

            let accountId = try holder.toAccountId(using: .ethereum)

            let assetBalance = AssetBalance(
                evmBalance: newBalance,
                accountId: accountId,
                chainAssetId: self.chainAssetId
            )

            let update = WalletRemoteSubscriptionUpdate(balance: assetBalance, blockHash: blockHash)

            dispatchInQueueWhenPossible(self.callbackQueue) {
                self.callbackClosure(update)
            }

            return true
        }

        notificationOperation.addDependency(blockHashWrapper.targetOperation)

        return blockHashWrapper.insertingTail(operation: notificationOperation)
    }
}
