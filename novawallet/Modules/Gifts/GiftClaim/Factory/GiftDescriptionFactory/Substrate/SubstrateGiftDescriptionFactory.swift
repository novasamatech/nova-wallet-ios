import Foundation
import BigInt
import Operation_iOS

protocol SubstrateGiftDescriptionFactoryProtocol {
    func createDescription(
        for claimableGift: ClaimableGift,
        giftAmountWithFee: BigUInt,
        claimingWallet: @escaping () throws -> MetaAccountModel,
        assetStorageInfo: @escaping () throws -> AssetStorageInfo
    ) -> BaseOperation<ClaimableGiftDescription>
}

final class SubstrateGiftDescriptionFactory {
    let transferCommandFactory: SubstrateTransferCommandFactory
    let extrinsicService: ExtrinsicServiceProtocol
    let callbackQueue: DispatchQueue
    let helper: ClaimableGiftDescriptionHelper

    init(
        transferCommandFactory: SubstrateTransferCommandFactory,
        extrinsicService: ExtrinsicServiceProtocol,
        callbackQueue: DispatchQueue,
        helper: ClaimableGiftDescriptionHelper = ClaimableGiftDescriptionHelper()
    ) {
        self.transferCommandFactory = transferCommandFactory
        self.extrinsicService = extrinsicService
        self.callbackQueue = callbackQueue
        self.helper = helper
    }
}

// MARK: - Private

private extension SubstrateGiftDescriptionFactory {
    func createBuilderClosure(
        using giftData: ClaimableGiftBaseData,
        assetStorageInfo: AssetStorageInfo
    ) -> ExtrinsicBuilderClosure {
        { [weak self] builder in
            guard let self else { return builder }

            let recipientAccountId = giftData.claimingAccountId ?? giftData.transactionId.recepientAccountId

            let (newBuilder, _) = try transferCommandFactory.addingTransferCommand(
                to: builder,
                amount: giftData.onChainAmountWithFee,
                recipient: recipientAccountId,
                assetStorageInfo: assetStorageInfo
            )

            return newBuilder
        }
    }
}

// MARK: - SubstrateGiftDescriptionFactoryProtocol

extension SubstrateGiftDescriptionFactory: SubstrateGiftDescriptionFactoryProtocol {
    func createDescription(
        for claimableGift: ClaimableGift,
        giftAmountWithFee: BigUInt,
        claimingWallet: @escaping () throws -> MetaAccountModel,
        assetStorageInfo: @escaping () throws -> AssetStorageInfo
    ) -> BaseOperation<ClaimableGiftDescription> {
        AsyncClosureOperation { [weak self] completion in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            let chainAsset = claimableGift.chainAsset

            let baseData = try helper.createBaseData(
                for: claimableGift,
                giftAmountWithFee: giftAmountWithFee,
                claimingWallet: claimingWallet
            )

            let builderClosure = createBuilderClosure(
                using: baseData,
                assetStorageInfo: try assetStorageInfo()
            )

            extrinsicService.estimateFee(
                builderClosure,
                payingIn: chainAsset.chainAssetId,
                runningIn: callbackQueue
            ) { [weak self] result in
                guard let self else { return }

                switch result {
                case let .success(fee):
                    let description = helper.createFinalDescription(
                        claimableGift: claimableGift,
                        onChainAmountWithFee: baseData.onChainAmountWithFee,
                        feeAmount: fee.amount,
                        claimingAccountId: baseData.claimingAccountId
                    )

                    completion(.success(description))
                case let .failure(error):
                    completion(.failure(error))
                }
            }
        }
    }
}
