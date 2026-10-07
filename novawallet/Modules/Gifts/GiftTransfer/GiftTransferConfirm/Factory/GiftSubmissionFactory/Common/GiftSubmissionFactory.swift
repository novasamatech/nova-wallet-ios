import Foundation
import BigInt
import Operation_iOS

typealias GiftSubmissionWrapperProvider = (
    _ giftWrapper: CompoundOperationWrapper<GiftModel>,
    _ amount: OnChainTransferAmount<BigUInt>
) -> CompoundOperationWrapper<SubmittedGiftTransactionMetadata>

protocol GiftSubmissionFactoryProtocol {
    func createWrapper(
        submissionWrapperProvider: GiftSubmissionWrapperProvider,
        amount: OnChainTransferAmount<BigUInt>,
        feeDescription: GiftFeeDescription?
    ) -> CompoundOperationWrapper<GiftTransferSubmissionResult>
}

final class GiftSubmissionFactory {
    let giftsRepository: AnyDataProviderRepository<GiftModel>
    let giftFactory: GiftOperationFactoryProtocol
    let giftSecretsCleaningFactory: GiftSecretsCleaningProtocol
    let persistExtrinsicService: PersistentExtrinsicServiceProtocol
    let persistenceFilter: ExtrinsicPersistenceFilterProtocol
    let eventCenter: EventCenterProtocol
    let chainAsset: ChainAsset
    let selectedAccount: ChainAccountResponse
    let operationQueue: OperationQueue

    init(
        giftsRepository: AnyDataProviderRepository<GiftModel>,
        giftFactory: GiftOperationFactoryProtocol,
        giftSecretsCleaningFactory: GiftSecretsCleaningProtocol,
        persistExtrinsicService: PersistentExtrinsicServiceProtocol,
        persistenceFilter: ExtrinsicPersistenceFilterProtocol,
        eventCenter: EventCenterProtocol,
        chainAsset: ChainAsset,
        selectedAccount: ChainAccountResponse,
        operationQueue: OperationQueue
    ) {
        self.giftsRepository = giftsRepository
        self.giftFactory = giftFactory
        self.giftSecretsCleaningFactory = giftSecretsCleaningFactory
        self.persistExtrinsicService = persistExtrinsicService
        self.persistenceFilter = persistenceFilter
        self.eventCenter = eventCenter
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.operationQueue = operationQueue
    }
}

// MARK: - Private

private extension GiftSubmissionFactory {
    func createProcessSubmissionResultWrapper(
        dependingOn submitWrapper: CompoundOperationWrapper<SubmittedGiftTransactionMetadata>,
        giftOperation: CompoundOperationWrapper<GiftModel>,
        lastFee: BigUInt?
    ) -> CompoundOperationWrapper<GiftTransferSubmissionResult> {
        OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            do {
                let submissionData = try submitWrapper.targetOperation.extractNoCancellableResultData()
                let gift = try giftOperation.targetOperation.extractNoCancellableResultData()

                return createFinalPersistenceWrapper(
                    gift: gift.updating(status: .pending),
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
        let cleanSecretsOperation = giftSecretsCleaningFactory.cleanSecrets(for: secretInfo)
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

    func createFinalPersistenceWrapper(
        gift: GiftModel,
        submissionData: SubmittedGiftTransactionMetadata,
        recipient: AccountId,
        amount: BigUInt,
        lastFee: BigUInt?
    ) -> CompoundOperationWrapper<GiftTransferSubmissionResult> {
        let giftStatusUpdateOperation = giftsRepository.saveOperation(
            { [gift] },
            { [] }
        )
        let extrinsicPersistWrapper = createPersistExtrinsicWrapper(
            submissionData: submissionData,
            recipient: recipient,
            amount: amount,
            lastFee: lastFee
        )

        let resultOperation = ClosureOperation {
            _ = try giftStatusUpdateOperation.extractNoCancellableResultData()

            return try extrinsicPersistWrapper.targetOperation.extractNoCancellableResultData()
        }

        resultOperation.addDependency(giftStatusUpdateOperation)
        resultOperation.addDependency(extrinsicPersistWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: [giftStatusUpdateOperation] + extrinsicPersistWrapper.allOperations
        )
    }

    func createPersistGiftWrapper(
        dependingOn giftOperation: CompoundOperationWrapper<GiftModel>
    ) -> CompoundOperationWrapper<Void> {
        let saveOperation = giftsRepository.saveOperation(
            { [try giftOperation.targetOperation.extractNoCancellableResultData()] },
            { [] }
        )

        return CompoundOperationWrapper(targetOperation: saveOperation)
    }

    func createPersistExtrinsicWrapper(
        submissionData: SubmittedGiftTransactionMetadata,
        recipient: AccountId,
        amount: BigUInt,
        lastFee: BigUInt?
    ) -> CompoundOperationWrapper<GiftTransferSubmissionResult> {
        let operation = AsyncClosureOperation<GiftTransferSubmissionResult> { [weak self] completion in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            let submissionResult = GiftTransferSubmissionResult(
                giftId: recipient.toHex(),
                giftAccountId: recipient,
                sender: submissionData.senderResolution
            )

            guard
                persistenceFilter.canPersistExtrinsic(for: selectedAccount),
                let callCodingPath = submissionData.callCodingPath,
                let txHashData = try? Data(hexString: submissionData.txHash)
            else {
                completion(.success(submissionResult))
                return
            }

            let sender = try selectedAccount.accountId.toAddress(using: chainAsset.chain.chainFormat)
            let recipient = try recipient.toAddress(using: chainAsset.chain.chainFormat)

            let details = PersistTransferDetails(
                sender: sender,
                receiver: recipient,
                amount: amount,
                txHash: txHashData,
                callPath: callCodingPath,
                fee: lastFee,
                feeAssetId: chainAsset.asset.assetId
            )

            persistExtrinsicService.saveTransfer(
                source: .substrate,
                chainAssetId: chainAsset.chainAssetId,
                details: details,
                runningIn: .main,
                completion: { result in
                    switch result {
                    case .success:
                        self.eventCenter.notify(with: WalletTransactionListUpdated())
                        completion(.success(submissionResult))
                    case let .failure(error):
                        completion(.failure(error))
                    }
                }
            )
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }
}

// MARK: - GiftSubmissionFactoryProtocol

extension GiftSubmissionFactory: GiftSubmissionFactoryProtocol {
    func createWrapper(
        submissionWrapperProvider: GiftSubmissionWrapperProvider,
        amount: OnChainTransferAmount<BigUInt>,
        feeDescription: GiftFeeDescription?
    ) -> CompoundOperationWrapper<GiftTransferSubmissionResult> {
        let totalFee = try? feeDescription?.createAccumulatedFee().amount
        let claimFee = feeDescription?.claimFee.amount ?? 0

        let amountWithClaimFee = amount.map { $0 + claimFee }

        /* We use nominal gift value for local model */
        let giftWrapper = giftFactory.createGiftWrapper(
            amount: amount.value,
            chainAsset: chainAsset
        )
        let persistGiftWrapper = createPersistGiftWrapper(dependingOn: giftWrapper)

        /* We send amount with claim fee to allow getting
         nominal gift value for final recipient */
        let submitWrapper = submissionWrapperProvider(
            giftWrapper,
            amountWithClaimFee
        )
        let processPossibleFailureWrapper = createProcessFailedSubmission(
            submitWrapper: submitWrapper,
            chainAsset: chainAsset
        )
        let processResultWrapper = createProcessSubmissionResultWrapper(
            dependingOn: submitWrapper,
            giftOperation: giftWrapper,
            lastFee: totalFee
        )

        persistGiftWrapper.addDependency(wrapper: giftWrapper)
        submitWrapper.addDependency(wrapper: persistGiftWrapper)
        processPossibleFailureWrapper.addDependency(wrapper: submitWrapper)
        processResultWrapper.addDependency(wrapper: processPossibleFailureWrapper)

        let finalWrapper = processResultWrapper
            .insertingHead(operations: processPossibleFailureWrapper.allOperations)
            .insertingHead(operations: submitWrapper.allOperations)
            .insertingHead(operations: persistGiftWrapper.allOperations)
            .insertingHead(operations: giftWrapper.allOperations)

        return finalWrapper
    }
}

struct SubmittedGiftTransactionMetadata {
    let txHash: String
    let senderResolution: ExtrinsicSenderResolution?
    let callCodingPath: CallCodingPath?
}
