import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

final class SubstrateGiftSubmissionFactory {
    let submissionFactory: GiftSubmissionFactoryProtocol
    let signingWrapper: SigningWrapperProtocol
    let chainAsset: ChainAsset
    let extrinsicMonitorFactory: ExtrinsicSubmitMonitorFactoryProtocol
    let transferCommandFactory: SubstrateTransferCommandFactory

    init(
        submissionFactory: GiftSubmissionFactoryProtocol,
        signingWrapper: SigningWrapperProtocol,
        chainAsset: ChainAsset,
        extrinsicMonitorFactory: ExtrinsicSubmitMonitorFactoryProtocol,
        transferCommandFactory: SubstrateTransferCommandFactory
    ) {
        self.submissionFactory = submissionFactory
        self.signingWrapper = signingWrapper
        self.chainAsset = chainAsset
        self.extrinsicMonitorFactory = extrinsicMonitorFactory
        self.transferCommandFactory = transferCommandFactory
    }

    func createSubmitWrapper(
        dependingOn giftWrapper: CompoundOperationWrapper<GiftModel>,
        amount: OnChainTransferAmount<BigUInt>,
        assetStorageInfo: AssetStorageInfo?
    ) -> CompoundOperationWrapper<SubmittedGiftTransactionMetadata> {
        var callCodingPath: CallCodingPath?

        let extrinsicBuilderClosure: ExtrinsicBuilderClosure = { [weak self] builder in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            let gift = try giftWrapper.targetOperation.extractNoCancellableResultData()

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
            extrinsicBuilderClosure: extrinsicBuilderClosure,
            payingIn: chainAsset.chainAssetId,
            signer: signingWrapper
        )

        let mapOperation = ClosureOperation<SubmittedGiftTransactionMetadata> {
            let result = submitAndMonitorWrapper.targetOperation.result
            let gift = try giftWrapper.targetOperation.extractNoCancellableResultData()

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

private extension SubstrateGiftSubmissionFactory {
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

// MARK: - SubstrateGiftSubmissionFactoryProtocol

extension SubstrateGiftSubmissionFactory: SubstrateGiftSubmissionFactoryProtocol {
    func createSubmissionWrapper(
        amount: OnChainTransferAmount<BigUInt>,
        assetStorageInfo: AssetStorageInfo?,
        feeDescription: GiftFeeDescription?
    ) -> CompoundOperationWrapper<GiftTransferSubmissionResult> {
        let submitWrapperProvider: GiftSubmissionWrapperProvider = { giftWrapper, amount in
            self.createSubmitWrapper(
                dependingOn: giftWrapper,
                amount: amount,
                assetStorageInfo: assetStorageInfo
            )
        }

        return submissionFactory.createWrapper(
            submissionWrapperProvider: submitWrapperProvider,
            amount: amount,
            feeDescription: feeDescription
        )
    }
}
