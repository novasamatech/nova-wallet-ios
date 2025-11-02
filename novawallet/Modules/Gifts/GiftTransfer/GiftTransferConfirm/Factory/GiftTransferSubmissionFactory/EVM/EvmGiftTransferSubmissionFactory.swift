import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

final class EvmGiftTransferSubmissionFactory: GiftTransferSubmitting {
    let giftFactory: GiftOperationFactoryProtocol
    let signingWrapper: SigningWrapperProtocol
    let persistExtrinsicService: PersistentExtrinsicServiceProtocol
    let persistenceFilter: ExtrinsicPersistenceFilterProtocol
    let eventCenter: EventCenterProtocol
    let chain: ChainModel
    let asset: AssetModel
    let selectedAccount: ChainAccountResponse
    let transactionService: EvmTransactionServiceProtocol
    let transferCommandFactory: EvmTransferCommandFactory
    let operationQueue: OperationQueue

    private let mutex = NSLock()

    private var transferType: EvmGiftTransferInteractor.TransferType?
    private var evmFee: EvmFeeModel?

    init(
        giftFactory: GiftOperationFactoryProtocol,
        signingWrapper: SigningWrapperProtocol,
        persistExtrinsicService: PersistentExtrinsicServiceProtocol,
        persistenceFilter: ExtrinsicPersistenceFilterProtocol,
        eventCenter: EventCenterProtocol,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: ChainAccountResponse,
        transactionService: EvmTransactionServiceProtocol,
        transferCommandFactory: EvmTransferCommandFactory,
        operationQueue: OperationQueue
    ) {
        self.giftFactory = giftFactory
        self.signingWrapper = signingWrapper
        self.persistExtrinsicService = persistExtrinsicService
        self.persistenceFilter = persistenceFilter
        self.eventCenter = eventCenter
        self.chain = chain
        self.asset = asset
        self.selectedAccount = selectedAccount
        self.transactionService = transactionService
        self.transferCommandFactory = transferCommandFactory
        self.operationQueue = operationQueue
    }

    func createSubmitOperation(
        dependingOn giftOperation: BaseOperation<GiftModel>,
        amount: OnChainTransferAmount<BigUInt>,
        assetStorageInfo _: AssetStorageInfo?
    ) -> BaseOperation<SubmittedGiftTransactionMetadata> {
        AsyncClosureOperation { [weak self] completion in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            let gift = try giftOperation.extractNoCancellableResultData()

            guard
                let transferType,
                let evmFee
            else {
                throw GiftTransferConfirmError.giftSubmissionFailed(
                    giftAccountId: gift.giftAccountId,
                    underlyingError: nil
                )
            }

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
    }
}

// MARK: - EvmGiftTransferSubmissionFactoryProtocol

extension EvmGiftTransferSubmissionFactory: EvmGiftTransferSubmissionFactoryProtocol {
    func createSubmissionWrapper(
        amount: OnChainTransferAmount<BigUInt>,
        feeDescription: GiftFeeDescription?,
        evmFee: EvmFeeModel,
        transferType: EvmGiftTransferInteractor.TransferType,
    ) -> CompoundOperationWrapper<ExtrinsicSenderResolution?> {
        mutex.lock()
        defer { mutex.unlock() }

        self.evmFee = evmFee
        self.transferType = transferType

        return createWrapper(
            amount: amount,
            assetStorageInfo: nil,
            feeDescription: feeDescription
        )
    }
}
