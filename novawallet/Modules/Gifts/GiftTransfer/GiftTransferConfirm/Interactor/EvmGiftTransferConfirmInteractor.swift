import Foundation
import BigInt
import Operation_iOS

final class EvmGiftTransferConfirmInteractor: EvmGiftTransferInteractor {
    let giftFactory: GiftOperationFactoryProtocol
    let signingWrapper: SigningWrapperProtocol
    let persistExtrinsicService: PersistentExtrinsicServiceProtocol
    let persistenceFilter: ExtrinsicPersistenceFilterProtocol
    let eventCenter: EventCenterProtocol

    var submissionPresenter: GiftTransferConfirmInteractorOutputProtocol? {
        presenter as? GiftTransferConfirmInteractorOutputProtocol
    }

    init(
        giftFactory: GiftOperationFactoryProtocol,
        signingWrapper: SigningWrapperProtocol,
        persistExtrinsicService: PersistentExtrinsicServiceProtocol,
        persistenceFilter: ExtrinsicPersistenceFilterProtocol,
        eventCenter: EventCenterProtocol,
        selectedAccount: ChainAccountResponse,
        chain: ChainModel,
        asset: AssetModel,
        feeProxy: any EvmTransactionFeeProxyProtocol,
        transferCommandFactory: EvmTransferCommandFactory,
        transactionService: any EvmTransactionServiceProtocol,
        validationProviderFactory: EvmValidationProviderFactoryProtocol,
        walletLocalSubscriptionFactory: any WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: any PriceProviderFactoryProtocol,
        currencyManager: any CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.giftFactory = giftFactory
        self.signingWrapper = signingWrapper
        self.persistExtrinsicService = persistExtrinsicService
        self.persistenceFilter = persistenceFilter
        self.eventCenter = eventCenter

        super.init(
            selectedAccount: selectedAccount,
            chain: chain,
            asset: asset,
            feeProxy: feeProxy,
            transferCommandFactory: transferCommandFactory,
            transactionService: transactionService,
            validationProviderFactory: validationProviderFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            currencyManager: currencyManager,
            operationQueue: operationQueue
        )
    }
}

// MARK: - Private

private extension EvmGiftTransferConfirmInteractor {
    func createWrapper(
        amount: OnChainTransferAmount<BigUInt>,
        lastFeeDescription: GiftFeeDescription?,
        transferType: TransferType,
        lastFeeModel: EvmFeeModel
    ) -> CompoundOperationWrapper<Void> {
        let totalFee = try? lastFeeDescription?.createAccumulatedFee().amount
        let claimFee = lastFeeDescription?.claimFee.amount ?? 0

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
            transferType: transferType,
            lastFeeModel: lastFeeModel
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

    func createSubmitOperation(
        dependingOn giftOperation: BaseOperation<GiftModel>,
        amount: OnChainTransferAmount<BigUInt>,
        transferType: TransferType,
        lastFeeModel: EvmFeeModel
    ) -> BaseOperation<(AccountAddress, CallCodingPath?)> {
        AsyncClosureOperation { [weak self] completion in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            let gift = try giftOperation.extractNoCancellableResultData()

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
                gasLimit: lastFeeModel.gasLimit,
                gasPrice: lastFeeModel.gasPrice
            )

            transactionService.submit(
                extrinsicClosure,
                price: EvmTransactionPrice(gasLimit: lastFeeModel.gasLimit, gasPrice: lastFeeModel.gasPrice),
                signer: signingWrapper,
                runningIn: .main,
                completion: { result in
                    switch result {
                    case let .success(txHash):
                        completion(.success((txHash, callCodingPath)))
                    case let .failure(error):
                        completion(.failure(error))
                    }
                }
            )
        }
    }

    func createProcessSubmissionResultWrapper(
        dependingOn submitOperation: BaseOperation<(AccountAddress, CallCodingPath?)>,
        giftOperation: BaseOperation<GiftModel>,
        lastFee: BigUInt?
    ) -> CompoundOperationWrapper<Void> {
        OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            let gift = try giftOperation.extractNoCancellableResultData()
            let submissionResult = try submitOperation.extractNoCancellableResultData()
            let txHash = submissionResult.0

            guard
                persistenceFilter.canPersistExtrinsic(for: selectedAccount),
                let callCodingPath = submissionResult.1,
                let txHashData = try? Data(hexString: txHash)
            else {
                return .createWithResult(())
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
                details: details
            )
        }
    }

    func persistExtrinsicWrapper(
        details: PersistTransferDetails
    ) -> CompoundOperationWrapper<Void> {
        let operation = AsyncClosureOperation<Void> { [weak self] completion in
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

// MARK: - GiftTransferConfirmInteractorInputProtocol

extension EvmGiftTransferConfirmInteractor: GiftTransferConfirmInteractorInputProtocol {
    func submit(
        amount: OnChainTransferAmount<BigUInt>,
        lastFeeDescription: GiftFeeDescription?
    ) {
        guard
            let transferType,
            let lastFeeDescription,
            let lastFeeModel
        else {
            submissionPresenter?.didReceiveError(CommonError.dataCorruption)
            return
        }
        
        let wrapper = createWrapper(
            amount: amount,
            lastFeeDescription: lastFeeDescription,
            transferType: transferType,
            lastFeeModel: lastFeeModel
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in

            switch result {
            case .success:
                self?.submissionPresenter?.didCompleteSubmition(by: nil)
            case let .failure(error):
                self?.presenter?.didReceiveError(error)
            }
        }
    }
}
