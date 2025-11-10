import Foundation
import Operation_iOS
import BigInt

protocol GiftClaimAvailabilityCheckFactoryProtocol {
    func createAvailabilityWrapper(
        for giftInfo: ClaimableGiftInfo
    ) -> CompoundOperationWrapper<GiftClaimAvailabilityCheckResult>
}

final class GiftClaimAvailabilityCheckFactory {
    private let chainRegistry: ChainRegistryProtocol
    private let giftSecretsManager: GiftSecretsManagerProtocol
    private let balanceQueryFacade: RemoteBalanceQueryFacadeProtocol
    private let assetInfoFactory: AssetStorageInfoOperationFactoryProtocol
    private let operationQueue: OperationQueue

    init(
        chainRegistry: ChainRegistryProtocol,
        giftSecretsManager: GiftSecretsManagerProtocol,
        balanceQueryFacade: RemoteBalanceQueryFacadeProtocol,
        assetInfoFactory: AssetStorageInfoOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainRegistry = chainRegistry
        self.giftSecretsManager = giftSecretsManager
        self.balanceQueryFacade = balanceQueryFacade
        self.assetInfoFactory = assetInfoFactory
        self.operationQueue = operationQueue
    }
}

// MARK: - Private

private extension GiftClaimAvailabilityCheckFactory {
    func createClaimCheckInfoWrapper(
        for giftInfo: ClaimableGiftInfo
    ) -> CompoundOperationWrapper<ClaimCheckInfo> {
        do {
            let chain = try chainRegistry.getChainOrError(for: giftInfo.chainId)
            let chainAsset = try chain.chainAssetForSymbolOrError(giftInfo.assetSymbol)

            let request = GiftPublicKeyFetchRequest(
                seed: giftInfo.seed,
                ethereumBased: chain.isEthereumBased
            )

            let publicKeyOperation: BaseOperation<Data> = giftSecretsManager.getPublicKey(request: request)

            let mapOperation = ClosureOperation<ClaimCheckInfo> {
                let publicKey = try publicKeyOperation.extractNoCancellableResultData()
                let accountId = try chain.isEthereumBased
                    ? publicKey.ethereumAddressFromPublicKey()
                    : publicKey.publicKeyToAccountId()

                return ClaimCheckInfo(
                    accountId: accountId,
                    chainAsset: chainAsset
                )
            }

            mapOperation.addDependency(publicKeyOperation)

            return CompoundOperationWrapper(
                targetOperation: mapOperation,
                dependencies: [publicKeyOperation]
            )
        } catch {
            return .createWithError(error)
        }
    }

    func createTransferableBalanceWrapper(
        dependingOn infoWrapper: CompoundOperationWrapper<ClaimCheckInfo>
    ) -> CompoundOperationWrapper<BigUInt> {
        OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            let claimCheckInfo = try infoWrapper.targetOperation.extractNoCancellableResultData()

            return self.balanceQueryFacade.createTransferrableWrapper(
                for: claimCheckInfo.accountId,
                chainAsset: claimCheckInfo.chainAsset
            )
        }
    }

    func createBalanceExisteceWrapper(
        dependingOn infoWrapper: CompoundOperationWrapper<ClaimCheckInfo>
    ) -> CompoundOperationWrapper<AssetBalanceExistence> {
        OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            let claimCheckInfo = try infoWrapper.targetOperation.extractNoCancellableResultData()

            let runtimeProvider = try self.chainRegistry.getRuntimeProviderOrError(
                for: claimCheckInfo.chainAsset.chainAssetId.chainId
            )

            return self.assetInfoFactory.createAssetBalanceExistenceOperation(
                chainId: claimCheckInfo.chainAsset.chainAssetId.chainId,
                asset: claimCheckInfo.chainAsset.asset,
                runtimeProvider: runtimeProvider,
                operationQueue: self.operationQueue
            )
        }
    }
}

// MARK: - GiftClaimAvailabilityCheckFactoryProtocol

extension GiftClaimAvailabilityCheckFactory: GiftClaimAvailabilityCheckFactoryProtocol {
    func createAvailabilityWrapper(
        for giftInfo: ClaimableGiftInfo
    ) -> CompoundOperationWrapper<GiftClaimAvailabilityCheckResult> {
        let claimCheckInfoWrapper = createClaimCheckInfoWrapper(for: giftInfo)

        let transferableBalanceWrapper = createTransferableBalanceWrapper(
            dependingOn: claimCheckInfoWrapper
        )
        let balanceExistenceWrapper = createBalanceExisteceWrapper(
            dependingOn: claimCheckInfoWrapper
        )

        let resultOperation = ClosureOperation<GiftClaimAvailabilityCheckResult> {
            let transferableBalance = try transferableBalanceWrapper
                .targetOperation
                .extractNoCancellableResultData()

            let existence = try balanceExistenceWrapper
                .targetOperation
                .extractNoCancellableResultData()

            let availability: GiftClaimAvailabilty = transferableBalance > existence.minBalance
                ? .claimable(transferableBalance)
                : .claimed

            return GiftClaimAvailabilityCheckResult(
                claimableGiftInfo: giftInfo,
                availability: availability
            )
        }

        transferableBalanceWrapper.addDependency(wrapper: claimCheckInfoWrapper)
        balanceExistenceWrapper.addDependency(wrapper: claimCheckInfoWrapper)

        resultOperation.addDependency(transferableBalanceWrapper.targetOperation)
        resultOperation.addDependency(balanceExistenceWrapper.targetOperation)

        let dependencies = claimCheckInfoWrapper.allOperations
            + transferableBalanceWrapper.allOperations
            + balanceExistenceWrapper.allOperations

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: dependencies
        )
    }
}

private extension GiftClaimAvailabilityCheckFactory {
    struct ClaimCheckInfo {
        let accountId: AccountId
        let chainAsset: ChainAsset
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
