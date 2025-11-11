import Foundation
import Operation_iOS
import BigInt

protocol GiftClaimAvailabilityCheckFactoryProtocol {
    func createAvailabilityWrapper(
        for claimableGift: ClaimableGiftInfo
    ) -> CompoundOperationWrapper<GiftClaimAvailabilityCheckResult>
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
        claimableGift: ClaimableGiftInfo
    ) -> CompoundOperationWrapper<AssetBalanceExistence> {
        OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            if claimableGift.chainAsset.asset.isAnyEvm {
                let existence = AssetBalanceExistence(
                    minBalance: 0,
                    isSelfSufficient: true
                )

                return .createWithResult(existence)
            } else {
                let runtimeProvider = try self.chainRegistry.getRuntimeProviderOrError(
                    for: claimableGift.chainAsset.chainAssetId.chainId
                )

                return self.assetInfoFactory.createAssetBalanceExistenceOperation(
                    chainId: claimableGift.chainAsset.chainAssetId.chainId,
                    asset: claimableGift.chainAsset.asset,
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
        for claimableGift: ClaimableGiftInfo
    ) -> CompoundOperationWrapper<GiftClaimAvailabilityCheckResult> {
        let transferableBalanceWrapper = balanceQueryFactory.queryBalance(
            for: claimableGift.accountId,
            chainAsset: claimableGift.chainAsset
        )
        let balanceExistenceWrapper = createBalanceExisteceWrapper(
            claimableGift: claimableGift
        )

        let resultOperation = ClosureOperation<GiftClaimAvailabilityCheckResult> {
            let transferableBalance = try transferableBalanceWrapper
                .targetOperation
                .extractNoCancellableResultData()
                .transferable

            let existence = try balanceExistenceWrapper
                .targetOperation
                .extractNoCancellableResultData()

            let availability: GiftClaimAvailabilty = transferableBalance > existence.minBalance
                ? .claimable(transferableBalance)
                : .claimed

            return GiftClaimAvailabilityCheckResult(
                claimableGiftInfo: claimableGift,
                availability: availability
            )
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

struct GiftClaimAvailabilityCheckResult {
    let claimableGiftInfo: ClaimableGiftInfo
    let availability: GiftClaimAvailabilty
}

enum GiftClaimAvailabilty {
    case claimable(BigUInt)
    case claimed
}
