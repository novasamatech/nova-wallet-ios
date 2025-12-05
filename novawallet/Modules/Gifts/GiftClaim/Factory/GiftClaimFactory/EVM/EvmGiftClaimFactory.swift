import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

final class EvmGiftClaimFactory {
    let claimFactory: GiftClaimFactoryProtocol
    let signingWrapperFactory: SigningWrapperFactoryProtocol
    let transactionMonitorFactory: TransactionSubmitMonitorFactoryProtocol
    let transferCommandFactory: EvmTransferCommandFactory
    let operationQueue: OperationQueue

    init(
        claimFactory: GiftClaimFactoryProtocol,
        signingWrapperFactory: SigningWrapperFactoryProtocol,
        transactionMonitorFactory: TransactionSubmitMonitorFactoryProtocol,
        transferCommandFactory: EvmTransferCommandFactory,
        operationQueue: OperationQueue
    ) {
        self.claimFactory = claimFactory
        self.signingWrapperFactory = signingWrapperFactory
        self.transactionMonitorFactory = transactionMonitorFactory
        self.transferCommandFactory = transferCommandFactory
        self.operationQueue = operationQueue
    }
}

// MARK: - Private

private extension EvmGiftClaimFactory {
    func createClaimWrapper(
        dependingOn giftWrapper: CompoundOperationWrapper<GiftModel>,
        amount: OnChainTransferAmount<BigUInt>,
        claimingAccountId: AccountId,
        evmFee: EvmFeeModel,
        transferType: EvmTransferType,
        chain: ChainModel
    ) -> CompoundOperationWrapper<Void> {
        let transactionClosure: EvmTransactionBuilderClosure = { [weak self] builder in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            let claimingAccountAddress = try claimingAccountId.toAddress(using: chain.chainFormat)

            let (newBuilder, _) = try transferCommandFactory.addingTransferCommand(
                to: builder,
                amount: amount,
                recipient: claimingAccountAddress,
                type: transferType
            )

            return newBuilder
        }

        let submissionWrapper = createSubmitAndMonitorWrapper(
            gift: { try giftWrapper.targetOperation.extractNoCancellableResultData() },
            evmFee: evmFee,
            transactionBuilderClosure: transactionClosure
        )
        let mapOperation = ClosureOperation {
            guard let result = submissionWrapper.targetOperation.result else { return }

            switch result {
            case let .success(submission):
                switch submission.status {
                case .success:
                    return
                case .failure:
                    throw GiftClaimError.giftClaimFailed(
                        claimingAccountId: claimingAccountId,
                        underlyingError: nil
                    )
                }
            case let .failure(error):
                throw GiftClaimError.giftClaimFailed(
                    claimingAccountId: claimingAccountId,
                    underlyingError: error
                )
            }
        }

        mapOperation.addDependency(submissionWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: submissionWrapper.allOperations
        )
    }

    func createSubmitAndMonitorWrapper(
        gift: @escaping () throws -> GiftModel,
        evmFee: EvmFeeModel,
        transactionBuilderClosure: @escaping EvmTransactionBuilderClosure
    ) -> CompoundOperationWrapper<EvmTransactionMonitorSubmission> {
        OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) {
            let price = EvmTransactionPrice(
                gasLimit: evmFee.gasLimit,
                gasPrice: evmFee.gasPrice
            )

            let signingData = GiftSigningData(
                gift: try gift(),
                ethereumBased: true,
                cryptoType: .ethereumEcdsa
            )
            let signingWrapper = self.signingWrapperFactory.createSigningWrapper(giftSigningData: signingData)

            return self.transactionMonitorFactory.submitAndMonitorWrapper(
                transactionBuilderClosure,
                price: price,
                signer: signingWrapper
            )
        }
    }
}

// MARK: - EvmGiftClaimFactoryProtocol

extension EvmGiftClaimFactory: EvmGiftClaimFactoryProtocol {
    func createClaimWrapper(
        giftDescription: ClaimableGiftDescription,
        evmFee: EvmFeeModel,
        transferType: EvmTransferType
    ) -> CompoundOperationWrapper<Void> {
        guard let claimingAccountId = giftDescription.claimingAccountId else {
            return .createWithError(GiftClaimError.claimingAccountNotFound)
        }

        let claimWrapperProvider: GiftClaimWrapperProvider = { giftWrapper, _ in
            self.createClaimWrapper(
                dependingOn: giftWrapper,
                amount: giftDescription.amount,
                claimingAccountId: claimingAccountId,
                evmFee: evmFee,
                transferType: transferType,
                chain: giftDescription.chainAsset.chain
            )
        }

        return claimFactory.claimGift(
            using: giftDescription,
            claimWrapperProvider: claimWrapperProvider
        )
    }

    func createReclaimWrapper(
        gift: GiftModel,
        claimingAccountId: AccountId,
        evmFee: EvmFeeModel,
        transferType: EvmTransferType
    ) -> CompoundOperationWrapper<Void> {
        let claimWrapperProvider: GiftClaimWrapperProvider = { giftWrapper, chainAsset in
            self.createClaimWrapper(
                dependingOn: giftWrapper,
                amount: .all(value: gift.amount),
                claimingAccountId: claimingAccountId,
                evmFee: evmFee,
                transferType: transferType,
                chain: chainAsset.chain
            )
        }

        return claimFactory.reclaimGift(
            gift,
            claimWrapperProvider: claimWrapperProvider
        )
    }
}
