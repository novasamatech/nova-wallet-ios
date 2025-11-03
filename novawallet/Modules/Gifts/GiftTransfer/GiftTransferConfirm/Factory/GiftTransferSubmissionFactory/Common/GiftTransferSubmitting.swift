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

    var giftsRepository: AnyDataProviderRepository<GiftModel> { get }

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

            do {
                let gift = try giftOperation.extractNoCancellableResultData()
                let submissionData = try submitOperation.extractNoCancellableResultData()

                return createPersistWrapper(
                    gift: gift,
                    submissionData: submissionData,
                    lastFee: lastFee
                )
            } catch {
                guard
                    case let GiftTransferConfirmError.giftSubmissionFailed(
                        _,
                        underlyingError
                    ) = error,
                    let underlyingError
                else { throw error }

                throw underlyingError
            }
        }
    }

    func createProcessFailedSubmission(
        submitOperation: BaseOperation<SubmittedGiftTransactionMetadata>,
        chainAsset: ChainAsset
    ) -> CompoundOperationWrapper<Void> {
        OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            do {
                _ = try submitOperation.extractNoCancellableResultData()
                return .createWithResult(())
            } catch {
                guard
                    case let GiftTransferConfirmError.giftSubmissionFailed(
                        giftAccountId,
                        _
                    ) = error
                else { throw error }

                let secretInfo = GiftSecretKeyInfo(
                    accountId: giftAccountId,
                    ethereumBased: chainAsset.chain.isEthereumBased
                )

                let cleanSecretsOperation = self.giftFactory.cleanSecrets(for: secretInfo)

                return CompoundOperationWrapper(targetOperation: cleanSecretsOperation)
            }
        }
    }

    func createPersistWrapper(
        gift: GiftModel,
        submissionData: SubmittedGiftTransactionMetadata,
        lastFee: BigUInt?
    ) -> CompoundOperationWrapper<ExtrinsicSenderResolution?> {
        let giftPersistWrapper = createPersistGiftWrapper(gift: gift)

        let extrinsicPersistWrapper = createPersistExtrinsicWrapper(
            submissionData: submissionData,
            recipient: gift.giftAccountId,
            amount: gift.amount,
            lastFee: lastFee
        )

        let resultOperation = ClosureOperation<ExtrinsicSenderResolution?> {
            try giftPersistWrapper.targetOperation.extractNoCancellableResultData()
            try extrinsicPersistWrapper.targetOperation.extractNoCancellableResultData()

            return submissionData.senderResolution
        }

        resultOperation.addDependency(giftPersistWrapper.targetOperation)
        resultOperation.addDependency(extrinsicPersistWrapper.targetOperation)

        let dependencies = giftPersistWrapper.allOperations + extrinsicPersistWrapper.allOperations

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: dependencies
        )
    }

    func createPersistGiftWrapper(
        gift: GiftModel
    ) -> CompoundOperationWrapper<Void> {
        let saveOperation = giftsRepository.saveOperation(
            { [gift] },
            { [] }
        )

        return CompoundOperationWrapper(targetOperation: saveOperation)
    }

    func createPersistExtrinsicWrapper(
        submissionData: SubmittedGiftTransactionMetadata,
        recipient: AccountId,
        amount: BigUInt,
        lastFee: BigUInt?
    ) -> CompoundOperationWrapper<Void> {
        let operation = AsyncClosureOperation<Void> { [weak self] completion in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            guard
                persistenceFilter.canPersistExtrinsic(for: selectedAccount),
                let callCodingPath = submissionData.callCodingPath,
                let txHashData = try? Data(hexString: submissionData.txHash)
            else {
                completion(.success(()))
                return
            }

            let sender = try selectedAccount.accountId.toAddress(using: chain.chainFormat)
            let recipient = try recipient.toAddress(using: chain.chainFormat)

            let details = PersistTransferDetails(
                sender: sender,
                receiver: recipient,
                amount: amount,
                txHash: txHashData,
                callPath: callCodingPath,
                fee: lastFee,
                feeAssetId: asset.assetId
            )

            persistExtrinsicService.saveTransfer(
                source: .substrate,
                chainAssetId: ChainAssetId(chainId: chain.chainId, assetId: asset.assetId),
                details: details,
                runningIn: .main,
                completion: { result in
                    switch result {
                    case .success:
                        self.eventCenter.notify(with: WalletTransactionListUpdated())
                        completion(.success(()))
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

        let chainAsset = ChainAsset(chain: chain, asset: asset)

        /* We use nominal gift value for local model */
        let giftOperation = giftFactory.createGiftOperation(
            amount: amount,
            chainAsset: chainAsset
        )

        /* We send amount with claim fee to allow getting
         nominal gift value for final recipient */
        let submitOperation = createSubmitOperation(
            dependingOn: giftOperation,
            amount: amountWithClaimFee,
            assetStorageInfo: assetStorageInfo
        )
        let processPossibleFailureWrapper = createProcessFailedSubmission(
            submitOperation: submitOperation,
            chainAsset: chainAsset
        )
        let processResultWrapper = createProcessSubmissionResultWrapper(
            dependingOn: submitOperation,
            giftOperation: giftOperation,
            lastFee: totalFee
        )

        submitOperation.addDependency(giftOperation)
        processPossibleFailureWrapper.addDependency(operations: [submitOperation])
        processResultWrapper.addDependency(wrapper: processPossibleFailureWrapper)

        let finalWrapper = processResultWrapper
            .insertingHead(operations: processPossibleFailureWrapper.allOperations)
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
