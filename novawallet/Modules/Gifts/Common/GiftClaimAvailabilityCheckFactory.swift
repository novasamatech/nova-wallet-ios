import Foundation
import Operation_iOS
import BigInt

protocol GiftClaimAvailabilityCheckFactoryProtocol {
    func createAvailabilityWrapper(
        for giftAccountId: AccountId,
        chainAsset: ChainAsset
    ) -> CompoundOperationWrapper<GiftClaimAvailabilty>
}

final class GiftClaimAvailabilityCheckFactory {
    private let chainRegistry: ChainRegistryProtocol
    private let giftSecretsManager: GiftSecretsManagerProtocol
    private let balanceQueryFactory: WalletRemoteQueryWrapperFactoryProtocol
    private let assetInfoFactory: AssetStorageInfoOperationFactoryProtocol
    private let operationQueue: OperationQueue

    init(
        chainRegistry: ChainRegistryProtocol,
        giftSecretsManager: GiftSecretsManagerProtocol,
        balanceQueryFactory: WalletRemoteQueryWrapperFactoryProtocol,
        assetInfoFactory: AssetStorageInfoOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainRegistry = chainRegistry
        self.giftSecretsManager = giftSecretsManager
        self.balanceQueryFactory = balanceQueryFactory
        self.assetInfoFactory = assetInfoFactory
        self.operationQueue = operationQueue
    }
}

// MARK: - Private

private extension GiftClaimAvailabilityCheckFactory {
    func createBalanceExisteceWrapper(
        chainAsset: ChainAsset
    ) -> CompoundOperationWrapper<AssetBalanceExistence> {
        OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            if chainAsset.asset.isAnyEvm {
                let existence = AssetBalanceExistence(
                    minBalance: 0,
                    isSelfSufficient: true
                )

                return .createWithResult(existence)
            } else {
                let runtimeProvider = try self.chainRegistry.getRuntimeProviderOrError(
                    for: chainAsset.chainAssetId.chainId
                )

                return self.assetInfoFactory.createAssetBalanceExistenceOperation(
                    chainId: chainAsset.chainAssetId.chainId,
                    asset: chainAsset.asset,
                    runtimeProvider: runtimeProvider,
                    operationQueue: self.operationQueue
                )
            }
        }
    }
}

// MARK: - GiftClaimAvailabilityCheckFactoryProtocol

extension GiftClaimAvailabilityCheckFactory: GiftClaimAvailabilityCheckFactoryProtocol {
    func createAvailabilityWrapper(
        for giftAccountId: AccountId,
        chainAsset: ChainAsset
    ) -> CompoundOperationWrapper<GiftClaimAvailabilty> {
        let transferableBalanceWrapper = balanceQueryFactory.queryBalance(
            for: giftAccountId,
            chainAsset: chainAsset
        )
        let balanceExistenceWrapper = createBalanceExisteceWrapper(
            chainAsset: chainAsset
        )

        let resultOperation = ClosureOperation<GiftClaimAvailabilty> {
            let transferableBalance = try transferableBalanceWrapper
                .targetOperation
                .extractNoCancellableResultData()
                .transferable

            let existence = try balanceExistenceWrapper
                .targetOperation
                .extractNoCancellableResultData()

            return transferableBalance > existence.minBalance
                ? .claimable(transferableBalance)
                : .claimed
        }

        resultOperation.addDependency(transferableBalanceWrapper.targetOperation)
        resultOperation.addDependency(balanceExistenceWrapper.targetOperation)

        let dependencies = transferableBalanceWrapper.allOperations + balanceExistenceWrapper.allOperations

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: dependencies
        )
    }
}

enum GiftClaimAvailabilty {
    case claimable(BigUInt)
    case claimed
}
