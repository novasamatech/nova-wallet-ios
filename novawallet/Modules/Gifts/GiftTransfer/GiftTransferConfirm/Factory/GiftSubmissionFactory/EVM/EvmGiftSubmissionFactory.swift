import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

final class EvmGiftSubmissionFactory {
    let submissionFactory: GiftSubmissionFactoryProtocol
    let signingWrapper: SigningWrapperProtocol
    let chain: ChainModel
    let transactionService: EvmTransactionServiceProtocol
    let transferCommandFactory: EvmTransferCommandFactory

    init(
        submissionFactory: GiftSubmissionFactoryProtocol,
        signingWrapper: SigningWrapperProtocol,
        chain: ChainModel,
        transactionService: EvmTransactionServiceProtocol,
        transferCommandFactory: EvmTransferCommandFactory
    ) {
        self.submissionFactory = submissionFactory
        self.signingWrapper = signingWrapper
        self.chain = chain
        self.transactionService = transactionService
        self.transferCommandFactory = transferCommandFactory
    }

    func createSubmitWrapper(
        dependingOn giftWrapper: CompoundOperationWrapper<GiftModel>,
        amount: OnChainTransferAmount<BigUInt>,
        evmFee: EvmFeeModel,
        transferType: EvmGiftTransferInteractor.TransferType
    ) -> CompoundOperationWrapper<SubmittedGiftTransactionMetadata> {
        let operation = AsyncClosureOperation { [weak self] completion in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            let gift = try giftWrapper.targetOperation.extractNoCancellableResultData()

            var callCodingPath: CallCodingPath?

            let extrinsicClosure: EvmTransactionBuilderClosure = { [weak self] builder in
                guard let self else { throw BaseOperationError.parentOperationCancelled }

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

            transactionService.submit(
                extrinsicClosure,
                price: price,
                signer: signingWrapper,
                runningIn: .main,
                completion: { result in
                    switch result {
                    case let .success(txHash):
                        let submittedExtrinsicModel = SubmittedGiftTransactionMetadata(
                            txHash: txHash,
                            senderResolution: nil,
                            callCodingPath: callCodingPath
                        )
                        completion(.success(submittedExtrinsicModel))
                    case let .failure(error):
                        completion(
                            .failure(
                                GiftTransferConfirmError.giftSubmissionFailed(
                                    giftAccountId: gift.giftAccountId,
                                    underlyingError: error
                                )
                            )
                        )
                    }
                }
            )
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }
}

// MARK: - EvmGiftSubmissionFactoryProtocol

extension EvmGiftSubmissionFactory: EvmGiftSubmissionFactoryProtocol {
    func createSubmissionWrapper(
        amount: OnChainTransferAmount<BigUInt>,
        feeDescription: GiftFeeDescription?,
        evmFee: EvmFeeModel,
        transferType: EvmGiftTransferInteractor.TransferType
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
