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

    init(
        submissionFactory: GiftSubmissionFactoryProtocol,
        signingWrapper: SigningWrapperProtocol,
        chain: ChainModel,
        transactionMonitorFactory: TransactionSubmitMonitorFactoryProtocol,
        transferCommandFactory: EvmTransferCommandFactory
    ) {
        self.submissionFactory = submissionFactory
        self.signingWrapper = signingWrapper
        self.chain = chain
        self.transactionMonitorFactory = transactionMonitorFactory
        self.transferCommandFactory = transferCommandFactory
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

        let price = EvmTransactionPrice(
            gasLimit: evmFee.gasLimit,
            gasPrice: evmFee.gasPrice
        )

        let submitAndMonitorWrapper = transactionMonitorFactory.submitAndMonitorWrapper(
            extrinsicClosure,
            price: price,
            signer: signingWrapper
        )

        let mapOperation = ClosureOperation<SubmittedGiftTransactionMetadata> {
            let result = submitAndMonitorWrapper.targetOperation.result
            let gift = try giftWrapper.targetOperation.extractNoCancellableResultData()

            switch result {
            case let .success(submission):
                if case let .success(successSubmission) = submission.status {
                    return SubmittedGiftTransactionMetadata(
                        txHash: successSubmission.transactionHash,
                        senderResolution: nil,
                        callCodingPath: callCodingPath
                    )
                } else {
                    throw GiftTransferConfirmError.giftSubmissionFailed(
                        giftAccountId: gift.giftAccountId,
                        underlyingError: nil
                    )
                }
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

        mapOperation.addDependency(submitAndMonitorWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: submitAndMonitorWrapper.allOperations
        )
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
