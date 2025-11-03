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
    let extrinsicMonitorFactory: ExtrinsicSubmissionMonitorFactory
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
        extrinsicMonitorFactory: ExtrinsicSubmissionMonitorFactory,
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
        self.extrinsicMonitorFactory = extrinsicMonitorFactory
        self.transferCommandFactory = transferCommandFactory
        self.operationQueue = operationQueue
    }

    func createSubmitWrapper(
        dependingOn giftOperation: BaseOperation<GiftModel>,
        amount: OnChainTransferAmount<BigUInt>,
        assetStorageInfo: AssetStorageInfo?
    ) -> CompoundOperationWrapper<SubmittedGiftTransactionMetadata> {
        var callCodingPath: CallCodingPath?

        let extrinsicBuilderClosre: ExtrinsicBuilderClosure = { [weak self] builder in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            let gift = try giftOperation.extractNoCancellableResultData()

            let (newBuilder, codingPath) = try self.addingTransferCommand(
                to: builder,
                amount: amount,
                recepient: gift.giftAccountId,
                assetStorageInfo: assetStorageInfo
            )

            callCodingPath = codingPath

            return newBuilder
        }

        let submitAndMonitorWrapper = extrinsicMonitorFactory.submitAndMonitorWrapper(
            extrinsicBuilderClosure: extrinsicBuilderClosre,
            payingIn: ChainAssetId(chainId: chain.chainId, assetId: asset.assetId),
            signer: signingWrapper
        )

        let mapOperation = ClosureOperation<SubmittedGiftTransactionMetadata> {
            let result = submitAndMonitorWrapper.targetOperation.result
            let gift = try giftOperation.extractNoCancellableResultData()

            switch result {
            case let .success(submission):
                return SubmittedGiftTransactionMetadata(
                    txHash: submission.extrinsicSubmittedModel.txHash,
                    senderResolution: submission.extrinsicSubmittedModel.sender,
                    callCodingPath: callCodingPath
                )
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

        return submitAndMonitorWrapper.insertingTail(operation: mapOperation)
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
    ) -> CompoundOperationWrapper<GiftTransferSubmissionResult> {
        createWrapper(
            amount: amount,
            assetStorageInfo: assetStorageInfo,
            feeDescription: feeDescription
        )
    }
}
