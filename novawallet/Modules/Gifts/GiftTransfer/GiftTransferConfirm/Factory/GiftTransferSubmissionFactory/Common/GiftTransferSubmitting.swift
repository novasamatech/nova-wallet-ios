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

    func createSubmitWrapper(
        dependingOn giftOperation: BaseOperation<GiftModel>,
        amount: OnChainTransferAmount<BigUInt>,
        assetStorageInfo: AssetStorageInfo?
    ) -> CompoundOperationWrapper<SubmittedGiftTransactionMetadata>
}

// MARK: - Private

private extension GiftTransferSubmitting {
    func createProcessSubmissionResultWrapper(
        dependingOn submitWrapper: CompoundOperationWrapper<SubmittedGiftTransactionMetadata>,
        giftOperation: BaseOperation<GiftModel>,
        lastFee: BigUInt?
    ) -> CompoundOperationWrapper<GiftTransferSubmissionResult> {
        OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            do {
                let submissionData = try submitWrapper.targetOperation.extractNoCancellableResultData()
                let gift = try giftOperation.extractNoCancellableResultData()

                return createPersistExtrinsicWrapper(
                    submissionData: submissionData,
                    recipient: gift.giftAccountId,
                    amount: gift.amount,
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
        submitWrapper: CompoundOperationWrapper<SubmittedGiftTransactionMetadata>,
        chainAsset: ChainAsset
    ) -> CompoundOperationWrapper<Void> {
        OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            do {
                _ = try submitWrapper.targetOperation.extractNoCancellableResultData()
                return .createWithResult(())
            } catch {
                guard
                    case let GiftTransferConfirmError.giftSubmissionFailed(
                        giftAccountId,
                        _
                    ) = error
                else { throw error }

                return self.createCleanGiftWrapper(
                    for: giftAccountId,
                    chainAsset: chainAsset
                )
            }
        }
    }

    func createCleanGiftWrapper(
        for giftAccountId: AccountId,
        chainAsset: ChainAsset
    ) -> CompoundOperationWrapper<Void> {
        let secretInfo = GiftSecretKeyInfo(
            accountId: giftAccountId,
            ethereumBased: chainAsset.chain.isEthereumBased
        )

        resultOperation.addDependency(giftPersistWrapper.targetOperation)
        resultOperation.addDependency(extrinsicPersistWrapper.targetOperation)
        let cleanSecretsOperation = giftFactory.cleanSecrets(for: secretInfo)
        let cleanLocalGiftOperation = giftsRepository.saveOperation(
            { [] },
            { [giftAccountId.toHex()] }
        )
        let resultOperation = ClosureOperation {
            try cleanSecretsOperation.extractNoCancellableResultData()
            try cleanLocalGiftOperation.extractNoCancellableResultData()
        }

        resultOperation.addDependency(cleanSecretsOperation)
        resultOperation.addDependency(cleanLocalGiftOperation)

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: [cleanSecretsOperation, cleanLocalGiftOperation]
        )
    }

    func createPersistGiftWrapper(
        dependingOn giftOperation: BaseOperation<GiftModel>
    ) -> CompoundOperationWrapper<Void> {
        let saveOperation = giftsRepository.saveOperation(
            { [try giftOperation.extractNoCancellableResultData()] },
            { [] }
        )

        return CompoundOperationWrapper(targetOperation: saveOperation)
    }

    func createPersistExtrinsicWrapper(
        submissionData: SubmittedGiftTransactionMetadata,
        recipient: AccountId,
        amount: BigUInt,
        lastFee: BigUInt?
    ) -> CompoundOperationWrapper<ExtrinsicSenderResolution?> {
        let operation = AsyncClosureOperation<ExtrinsicSenderResolution?> { [weak self] completion in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            guard
                persistenceFilter.canPersistExtrinsic(for: selectedAccount),
                let callCodingPath = submissionData.callCodingPath,
                let txHashData = try? Data(hexString: submissionData.txHash)
            else {
                completion(.success(submissionData.senderResolution))
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
                        completion(.success(submissionData.senderResolution))
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
    ) -> CompoundOperationWrapper<GiftTransferSubmissionResult> {
        let totalFee = try? feeDescription?.createAccumulatedFee().amount
        let claimFee = feeDescription?.claimFee.amount ?? 0

        let amountWithClaimFee = amount.map { $0 + claimFee }

        let chainAsset = ChainAsset(chain: chain, asset: asset)

        /* We use nominal gift value for local model */
        let giftOperation = giftFactory.createGiftOperation(
            amount: amount,
            chainAsset: chainAsset
        )
        let persistGiftWrapper = createPersistGiftWrapper(dependingOn: giftOperation)

        /* We send amount with claim fee to allow getting
         nominal gift value for final recipient */
        let submitWrapper = createSubmitWrapper(
            dependingOn: giftOperation,
            amount: amountWithClaimFee,
            assetStorageInfo: assetStorageInfo
        )
        let processPossibleFailureWrapper = createProcessFailedSubmission(
            submitWrapper: submitWrapper,
            chainAsset: chainAsset
        )
        let processResultWrapper = createProcessSubmissionResultWrapper(
            dependingOn: submitWrapper,
            giftOperation: giftOperation,
            lastFee: totalFee
        )

        persistGiftWrapper.addDependency(operations: [giftOperation])
        submitWrapper.addDependency(wrapper: persistGiftWrapper)
        processPossibleFailureWrapper.addDependency(wrapper: submitWrapper)
        processResultWrapper.addDependency(wrapper: processPossibleFailureWrapper)

        let finalWrapper = processResultWrapper
            .insertingHead(operations: processPossibleFailureWrapper.allOperations)
            .insertingHead(operations: submitWrapper.allOperations)
            .insertingHead(operations: persistGiftWrapper.allOperations)
            .insertingHead(operations: [giftOperation])

        return finalWrapper
    }
}

struct SubmittedGiftTransactionMetadata {
    let txHash: String
    let senderResolution: ExtrinsicSenderResolution?
    let callCodingPath: CallCodingPath?
}
