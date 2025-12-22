import Foundation
import BigInt
import Operation_iOS

protocol EvmClaimableGiftDescriptionFactoryProtocol {
    func createDescription(
        for claimableGift: ClaimGiftPayload,
        giftAmountWithFee: BigUInt,
        claimingWallet: @escaping () throws -> MetaAccountModel,
        transferType: EvmTransferType
    ) -> BaseOperation<(ClaimableGiftDescription, EvmFeeModel)>
}

final class EvmClaimableGiftDescriptionFactory {
    let chainRegistry: ChainRegistryProtocol
    let transferCommandFactory: EvmTransferCommandFactory
    let transactionService: EvmTransactionServiceProtocol
    let callbackQueue: DispatchQueue
    let helper: ClaimableGiftDescriptionHelper

    init(
        chainRegistry: ChainRegistryProtocol,
        transferCommandFactory: EvmTransferCommandFactory,
        transactionService: EvmTransactionServiceProtocol,
        callbackQueue: DispatchQueue,
        helper: ClaimableGiftDescriptionHelper = ClaimableGiftDescriptionHelper()
    ) {
        self.chainRegistry = chainRegistry
        self.transferCommandFactory = transferCommandFactory
        self.transactionService = transactionService
        self.callbackQueue = callbackQueue
        self.helper = helper
    }
}

// MARK: - Private

private extension EvmClaimableGiftDescriptionFactory {
    func createBuilderClosure(
        using giftData: ClaimableGiftBaseData,
        transferType: EvmTransferType,
        chainAsset: ChainAsset
    ) -> EvmTransactionBuilderClosure {
        { [weak self] builder in
            guard let self else { return builder }

            let recipientAccountId = try giftData.claimingAccountId
                ?? chainAsset.chain.emptyAccountId()
            let recipientAccountAddress = try recipientAccountId.toAddress(
                using: chainAsset.chain.chainFormat
            )

            let (newBuilder, _) = try transferCommandFactory.addingTransferCommand(
                to: builder,
                amount: giftData.onChainAmountWithFee,
                recipient: recipientAccountAddress,
                type: transferType
            )

            return newBuilder
        }
    }
}

// MARK: - EvmClaimableGiftDescriptionFactoryProtocol

extension EvmClaimableGiftDescriptionFactory: EvmClaimableGiftDescriptionFactoryProtocol {
    func createDescription(
        for claimableGift: ClaimGiftPayload,
        giftAmountWithFee: BigUInt,
        claimingWallet: @escaping () throws -> MetaAccountModel,
        transferType: EvmTransferType
    ) -> BaseOperation<(ClaimableGiftDescription, EvmFeeModel)> {
        AsyncClosureOperation { [weak self] completion in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            let chain = try chainRegistry.getChainOrError(for: claimableGift.chainAssetId.chainId)
            let chainAsset = try chain.chainAssetOrError(for: claimableGift.chainAssetId.assetId)

            let baseData = try helper.createBaseData(
                for: chainAsset,
                giftAmountWithFee: giftAmountWithFee,
                claimingWallet: claimingWallet
            )

            let builderClosure = createBuilderClosure(
                using: baseData,
                transferType: transferType,
                chainAsset: chainAsset
            )

            transactionService.estimateFee(
                builderClosure,
                runningIn: callbackQueue
            ) { [weak self] result in
                guard let self else { return }

                switch result {
                case let .success(fee):
                    let description = helper.createFinalDescription(
                        chainAsset: chainAsset,
                        claimableGift: claimableGift,
                        onChainAmountWithFee: baseData.onChainAmountWithFee,
                        feeAmount: fee.fee,
                        claimingAccountId: baseData.claimingAccountId
                    )

                    completion(.success((description, fee)))
                case let .failure(error):
                    completion(.failure(error))
                }
            }
        }
    }
}
