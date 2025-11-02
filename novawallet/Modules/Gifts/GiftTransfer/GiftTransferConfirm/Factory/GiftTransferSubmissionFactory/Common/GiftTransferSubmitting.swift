import Foundation
import BigInt
import Operation_iOS

protocol GiftTransferSubmitting: AnyObject {
    var giftFactory: GiftOperationFactoryProtocol { get }
    var persistExtrinsicService: PersistentExtrinsicServiceProtocol { get }
    var persistenceFilter: ExtrinsicPersistenceFilterProtocol { get }
    var eventCenter: EventCenterProtocol { get }
    var chain: ChainModel { get }
    var asset: AssetModel { get }
    var selectedAccount: ChainAccountResponse { get }
    var operationQueue: OperationQueue { get }

    func createSubmitOperation(
        dependingOn giftOperation: BaseOperation<GiftModel>,
        amount: OnChainTransferAmount<BigUInt>,
        assetStorageInfo: AssetStorageInfo?
    ) -> BaseOperation<SubmittedGiftTransactionMetadata>
}

// MARK: - Private

private extension GiftTransferSubmitting {
    func createProcessSubmissionResultWrapper(
        dependingOn submitOperation: BaseOperation<SubmittedGiftTransactionMetadata>,
        giftOperation: BaseOperation<GiftModel>,
        lastFee: BigUInt?
    ) -> CompoundOperationWrapper<ExtrinsicSenderResolution?> {
        OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            let gift = try giftOperation.extractNoCancellableResultData()
            let submissionData = try submitOperation.extractNoCancellableResultData()

            guard
                persistenceFilter.canPersistExtrinsic(for: selectedAccount),
                let callCodingPath = submissionData.callCodingPath,
                let txHashData = try? Data(hexString: submissionData.txHash)
            else {
                return .createWithResult(submissionData.senderResolution)
            }

            let sender = try selectedAccount.accountId.toAddress(using: chain.chainFormat)
            let recipient = try gift.giftAccountId.toAddress(using: chain.chainFormat)

            let details = PersistTransferDetails(
                sender: sender,
                receiver: recipient,
                amount: gift.amount,
                txHash: txHashData,
                callPath: callCodingPath,
                fee: lastFee,
                feeAssetId: asset.assetId
            )

            return persistExtrinsicWrapper(
                details: details,
                sender: submissionData.senderResolution
            )
        }
    }

    func persistExtrinsicWrapper(
        details: PersistTransferDetails,
        sender: ExtrinsicSenderResolution?
    ) -> CompoundOperationWrapper<ExtrinsicSenderResolution?> {
        let operation = AsyncClosureOperation<ExtrinsicSenderResolution?> { [weak self] completion in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            persistExtrinsicService.saveTransfer(
                source: .substrate,
                chainAssetId: ChainAssetId(chainId: chain.chainId, assetId: asset.assetId),
                details: details,
                runningIn: .main,
                completion: { result in
                    switch result {
                    case .success:
                        self.eventCenter.notify(with: WalletTransactionListUpdated())
                        completion(.success(sender))
                    case let .failure(error):
                        completion(.failure(error))
                    }
                }
            )
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }
}

// MARK: - Internal

extension GiftTransferSubmitting {
    func createWrapper(
        amount: OnChainTransferAmount<BigUInt>,
        assetStorageInfo: AssetStorageInfo?,
        feeDescription: GiftFeeDescription?
    ) -> CompoundOperationWrapper<ExtrinsicSenderResolution?> {
        let totalFee = try? feeDescription?.createAccumulatedFee().amount
        let claimFee = feeDescription?.claimFee.amount ?? 0

        let amountWithClaimFee = amount.map { $0 + claimFee }

        /* We use nominal gift value for local model */
        let giftOperation = giftFactory.createGiftOperation(
            amount: amount,
            chainAsset: ChainAsset(chain: chain, asset: asset)
        )

        /* We send amount with claim fee to allow getting
         nominal gift value for final recipient */
        let submitOperation = createSubmitOperation(
            dependingOn: giftOperation,
            amount: amountWithClaimFee,
            assetStorageInfo: assetStorageInfo
        )

        let processResultWrapper = createProcessSubmissionResultWrapper(
            dependingOn: submitOperation,
            giftOperation: giftOperation,
            lastFee: totalFee
        )

        submitOperation.addDependency(giftOperation)
        processResultWrapper.addDependency(operations: [submitOperation])

        let finalWrapper = processResultWrapper
            .insertingHead(operations: [submitOperation])
            .insertingHead(operations: [giftOperation])

        return finalWrapper
    }
}

struct SubmittedGiftTransactionMetadata {
    let txHash: String
    let senderResolution: ExtrinsicSenderResolution?
    let callCodingPath: CallCodingPath?
}
