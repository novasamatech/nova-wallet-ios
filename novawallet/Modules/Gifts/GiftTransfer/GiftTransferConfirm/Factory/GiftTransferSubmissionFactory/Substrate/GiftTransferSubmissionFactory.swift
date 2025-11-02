import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

final class GiftTransferSubmissionFactory: GiftTransferSubmitting {
    let giftFactory: GiftOperationFactoryProtocol
    let giftsRepository: AnyDataProviderRepository<GiftModel>
    let signingWrapper: SigningWrapperProtocol
    let persistExtrinsicService: PersistentExtrinsicServiceProtocol
    let persistenceFilter: ExtrinsicPersistenceFilterProtocol
    let eventCenter: EventCenterProtocol
    let chain: ChainModel
    let asset: AssetModel
    let selectedAccount: ChainAccountResponse
    let extrinsicService: ExtrinsicServiceProtocol
    let transferCommandFactory: SubstrateTransferCommandFactory
    let operationQueue: OperationQueue

    init(
        giftFactory: GiftOperationFactoryProtocol,
        giftsRepository: AnyDataProviderRepository<GiftModel>,
        signingWrapper: SigningWrapperProtocol,
        persistExtrinsicService: PersistentExtrinsicServiceProtocol,
        persistenceFilter: ExtrinsicPersistenceFilterProtocol,
        eventCenter: EventCenterProtocol,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: ChainAccountResponse,
        extrinsicService: ExtrinsicServiceProtocol,
        transferCommandFactory: SubstrateTransferCommandFactory,
        operationQueue: OperationQueue
    ) {
        self.giftFactory = giftFactory
        self.giftsRepository = giftsRepository
        self.signingWrapper = signingWrapper
        self.persistExtrinsicService = persistExtrinsicService
        self.persistenceFilter = persistenceFilter
        self.eventCenter = eventCenter
        self.chain = chain
        self.asset = asset
        self.selectedAccount = selectedAccount
        self.extrinsicService = extrinsicService
        self.transferCommandFactory = transferCommandFactory
        self.operationQueue = operationQueue
    }

    func createSubmitOperation(
        dependingOn giftOperation: BaseOperation<GiftModel>,
        amount: OnChainTransferAmount<BigUInt>,
        assetStorageInfo: AssetStorageInfo?
    ) -> BaseOperation<SubmittedGiftTransactionMetadata> {
        AsyncClosureOperation { [weak self] completion in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            let gift = try giftOperation.extractNoCancellableResultData()

            var callCodingPath: CallCodingPath?

            let extrinsicClosure: ExtrinsicBuilderClosure = { [weak self] builder in
                guard let self else { throw BaseOperationError.parentOperationCancelled }

                let (newBuilder, codingPath) = try self.addingTransferCommand(
                    to: builder,
                    amount: amount,
                    recepient: gift.giftAccountId,
                    assetStorageInfo: assetStorageInfo
                )

                callCodingPath = codingPath

                return newBuilder
            }

            extrinsicService.submit(
                extrinsicClosure,
                payingIn: ChainAssetId(chainId: chain.chainId, assetId: asset.assetId),
                signer: signingWrapper,
                runningIn: .main,
                completion: { result in
                    switch result {
                    case let .success(submitModel):
                        let submittedExtrinsicModel = SubmittedGiftTransactionMetadata(
                            txHash: submitModel.txHash,
                            senderResolution: submitModel.sender,
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

// MARK: - Private

private extension GiftTransferSubmissionFactory {
    func addingTransferCommand(
        to builder: ExtrinsicBuilderProtocol,
        amount: OnChainTransferAmount<BigUInt>,
        recepient: AccountId,
        assetStorageInfo: AssetStorageInfo?
    ) throws -> (ExtrinsicBuilderProtocol, CallCodingPath?) {
        guard let assetStorageInfo else {
            return (builder, nil)
        }

        return try transferCommandFactory.addingTransferCommand(
            to: builder,
            amount: amount,
            recipient: recepient,
            assetStorageInfo: assetStorageInfo
        )
    }
}

// MARK: - GiftTransferSubmissionFactoryProtocol

extension GiftTransferSubmissionFactory: GiftTransferSubmissionFactoryProtocol {
    func createSubmissionWrapper(
        amount: OnChainTransferAmount<BigUInt>,
        assetStorageInfo: AssetStorageInfo?,
        feeDescription: GiftFeeDescription?
    ) -> CompoundOperationWrapper<ExtrinsicSenderResolution?> {
        createWrapper(
            amount: amount,
            assetStorageInfo: assetStorageInfo,
            feeDescription: feeDescription
        )
    }
}
