import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

final class EvmGiftSubmissionFactory {
    let submissionFactory: GiftSubmissionFactoryProtocol
    let signingWrapper: SigningWrapperProtocol
    let chain: ChainModel
    let transactionMonitorFactory: TransactionSubmitMonitorFactoryProtocol
    let transferCommandFactory: EvmTransferCommandFactory
    let balanceQueryFactory: WalletRemoteQueryWrapperFactoryProtocol
    let operationQueue: OperationQueue

    init(
        submissionFactory: GiftSubmissionFactoryProtocol,
        signingWrapper: SigningWrapperProtocol,
        chain: ChainModel,
        transactionMonitorFactory: TransactionSubmitMonitorFactoryProtocol,
        transferCommandFactory: EvmTransferCommandFactory,
        balanceQueryFactory: WalletRemoteQueryWrapperFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.submissionFactory = submissionFactory
        self.signingWrapper = signingWrapper
        self.chain = chain
        self.transactionMonitorFactory = transactionMonitorFactory
        self.transferCommandFactory = transferCommandFactory
        self.balanceQueryFactory = balanceQueryFactory
        self.operationQueue = operationQueue
    }

    func createSubmitWrapper(
        dependingOn giftWrapper: CompoundOperationWrapper<GiftModel>,
        amount: OnChainTransferAmount<BigUInt>,
        evmFee: EvmFeeModel,
        transferType: EvmTransferType
    ) -> CompoundOperationWrapper<SubmittedGiftTransactionMetadata> {
        var callCodingPath: CallCodingPath?

        let extrinsicClosure: EvmTransactionBuilderClosure = { [weak self] builder in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            let gift = try giftWrapper.targetOperation.extractNoCancellableResultData()

            let giftAccountAddress = try gift.giftAccountId.toAddress(using: chain.chainFormat)

            let (newBuilder, codingPath) = try transferCommandFactory.addingTransferCommand(
                to: builder,
                amount: amount,
                recipient: giftAccountAddress,
                type: transferType
            )

            callCodingPath = codingPath

            return newBuilder
        }

        let submitAndMonitorWrapper = transactionMonitorFactory.submitAndMonitorWrapper(
            extrinsicClosure,
            price: evmFee.transactionPrice,
            signer: signingWrapper
        )

        let resultWrapper = createSubmissionResultWrapper(
            dependingOn: submitAndMonitorWrapper,
            giftWrapper: giftWrapper,
            callCodingPath: { callCodingPath }
        )

        resultWrapper.addDependency(wrapper: submitAndMonitorWrapper)

        return resultWrapper.insertingHead(operations: submitAndMonitorWrapper.allOperations)
    }
}

// MARK: - Private

private extension EvmGiftSubmissionFactory {
    func createSubmissionResultWrapper(
        dependingOn submitAndMonitorWrapper: CompoundOperationWrapper<EvmTransactionMonitorSubmission>,
        giftWrapper: CompoundOperationWrapper<GiftModel>,
        callCodingPath: @escaping () -> CallCodingPath?
    ) -> CompoundOperationWrapper<SubmittedGiftTransactionMetadata> {
        OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) { [weak self] in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            let result = submitAndMonitorWrapper.targetOperation.result
            let gift = try giftWrapper.targetOperation.extractNoCancellableResultData()

            switch result {
            case let .success(submission):
                if case let .success(successSubmission) = submission.status {
                    return .createWithResult(
                        SubmittedGiftTransactionMetadata(
                            txHash: successSubmission.transactionHash,
                            senderResolution: nil,
                            callCodingPath: callCodingPath()
                        )
                    )
                } else {
                    throw GiftTransferConfirmError.giftSubmissionFailed(
                        giftAccountId: gift.giftAccountId,
                        underlyingError: nil
                    )
                }
            case let .failure(EvmTransactionMonitorError.dropped(transactionHash)):
                return createDroppedFundingWrapper(for: gift, transactionHash: transactionHash)
            case let .failure(error):
                throw GiftTransferConfirmError.giftSubmissionFailed(
                    giftAccountId: gift.giftAccountId,
                    underlyingError: error
                )
            case .none:
                throw GiftTransferConfirmError.giftSubmissionFailed(
                    giftAccountId: gift.giftAccountId,
                    underlyingError: nil
                )
            }
        }
    }

    func createDroppedFundingWrapper(
        for gift: GiftModel,
        transactionHash: String
    ) -> CompoundOperationWrapper<SubmittedGiftTransactionMetadata> {
        let balanceWrapper: CompoundOperationWrapper<AssetBalance>

        do {
            let chainAsset = try chain.chainAssetOrError(for: gift.chainAssetId.assetId)
            balanceWrapper = balanceQueryFactory.queryBalance(for: gift.giftAccountId, chainAsset: chainAsset)
        } catch {
            balanceWrapper = .createWithError(error)
        }

        let resultOperation = ClosureOperation<SubmittedGiftTransactionMetadata> {
            let balance: AssetBalance

            do {
                balance = try balanceWrapper.targetOperation.extractNoCancellableResultData()
            } catch {
                throw GiftTransferConfirmError.giftSubmissionFailed(
                    giftAccountId: gift.giftAccountId,
                    underlyingError: EvmTransactionMonitorError.stillPending(transactionHash: transactionHash)
                )
            }

            guard balance.transferable > gift.amount / 2 else {
                throw GiftTransferConfirmError.giftSubmissionFailed(
                    giftAccountId: gift.giftAccountId,
                    underlyingError: EvmTransactionMonitorError.dropped(transactionHash: transactionHash)
                )
            }

            return SubmittedGiftTransactionMetadata(
                txHash: transactionHash,
                senderResolution: nil,
                callCodingPath: nil
            )
        }

        resultOperation.addDependency(balanceWrapper.targetOperation)

        return balanceWrapper.insertingTail(operation: resultOperation)
    }
}

// MARK: - EvmGiftSubmissionFactoryProtocol

extension EvmGiftSubmissionFactory: EvmGiftSubmissionFactoryProtocol {
    func createSubmissionWrapper(
        amount: OnChainTransferAmount<BigUInt>,
        feeDescription: GiftFeeDescription?,
        evmFee: EvmFeeModel,
        transferType: EvmTransferType
    ) -> CompoundOperationWrapper<GiftTransferSubmissionResult> {
        let submissionWrapperProvider: GiftSubmissionWrapperProvider = { giftWrapper, amount in
            self.createSubmitWrapper(
                dependingOn: giftWrapper,
                amount: amount,
                evmFee: evmFee,
                transferType: transferType
            )
        }

        return submissionFactory.createWrapper(
            submissionWrapperProvider: submissionWrapperProvider,
            amount: amount,
            feeDescription: feeDescription
        )
    }
}
