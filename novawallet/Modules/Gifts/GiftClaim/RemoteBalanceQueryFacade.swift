import Foundation
import Operation_iOS
import BigInt

protocol RemoteBalanceQueryFacadeProtocol {
    func createTransferrableWrapper(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) -> CompoundOperationWrapper<BigUInt>
}

final class RemoteBalanceQueryFacade {
    private let chainRegistry: ChainRegistryProtocol
    private let operationQueue: OperationQueue

    init(
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
    }
}

// MARK: - Private

private extension RemoteBalanceQueryFacade {
    func querySubstrateTransferrableBalance(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) -> CompoundOperationWrapper<BigUInt> {
        let wrapper = querySubstrateBalance(
            for: accountId,
            chainAsset: chainAsset
        )

        let mapOperation = ClosureOperation {
            try wrapper.targetOperation
                .extractNoCancellableResultData()
                .transferable
        }

        mapOperation.addDependency(wrapper.targetOperation)

        return wrapper.insertingTail(operation: mapOperation)
    }

    func querySubstrateBalance(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) -> CompoundOperationWrapper<AssetBalance> {
        WalletRemoteQueryWrapperFactory(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        ).queryBalance(
            for: accountId,
            chainAsset: chainAsset
        )
    }

    func queryEthereumBalance(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) -> CompoundOperationWrapper<BigUInt> {
        do {
            let address = try accountId.toAddress(using: chainAsset.chain.chainFormat)

            return EvmRemoteBalanceQueryFactory(
                chainRegistry: chainRegistry
            ).fetchBalance(
                for: address,
                chainId: chainAsset.chainAssetId.chainId
            )
        } catch {
            return .createWithError(error)
        }
    }
}

// MARK: - RemoteBalanceQueryFacadeProtocol

extension RemoteBalanceQueryFacade: RemoteBalanceQueryFacadeProtocol {
    func createTransferrableWrapper(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) -> CompoundOperationWrapper<BigUInt> {
        chainAsset.chain.isEthereumBased
            ? querySubstrateTransferrableBalance(
                for: accountId,
                chainAsset: chainAsset
            )
            : queryEthereumBalance(
                for: accountId,
                chainAsset: chainAsset
            )
    }
}
