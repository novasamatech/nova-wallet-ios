import UIKit
import BigInt
import Operation_iOS

final class TransferEvmOnChainConfirmInteractor: EvmOnChainTransferInteractor {
    let signingWrapper: SigningWrapperProtocol
    let trackedSubmissionFactory: EvmTrackedSubmissionFactoryProtocol
    let persistenceFilter: ExtrinsicPersistenceFilterProtocol
    let eventCenter: EventCenterProtocol
    let selfReceiveRevealer: TransferSelfReceiveRevealer

    var submitionPresenter: TransferConfirmOnChainInteractorOutputProtocol? {
        presenter as? TransferConfirmOnChainInteractorOutputProtocol
    }

    init(
        selectedAccount: ChainAccountResponse,
        chain: ChainModel,
        asset: AssetModel,
        feeProxy: EvmTransactionFeeProxyProtocol,
        transferCommandFactory: EvmTransferCommandFactory,
        extrinsicService: EvmTransactionServiceProtocol,
        validationProviderFactory: EvmValidationProviderFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        signingWrapper: SigningWrapperProtocol,
        trackedSubmissionFactory: EvmTrackedSubmissionFactoryProtocol,
        persistenceFilter: ExtrinsicPersistenceFilterProtocol,
        eventCenter: EventCenterProtocol,
        selfReceiveRevealer: TransferSelfReceiveRevealer,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.signingWrapper = signingWrapper
        self.trackedSubmissionFactory = trackedSubmissionFactory
        self.persistenceFilter = persistenceFilter
        self.eventCenter = eventCenter
        self.selfReceiveRevealer = selfReceiveRevealer

        super.init(
            selectedAccount: selectedAccount,
            chain: chain,
            asset: asset,
            feeProxy: feeProxy,
            transferCommandFactory: transferCommandFactory,
            extrinsicService: extrinsicService,
            validationProviderFactory: validationProviderFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            currencyManager: currencyManager,
            operationQueue: operationQueue
        )
    }
}

extension TransferEvmOnChainConfirmInteractor: TransferConfirmOnChainInteractorInputProtocol {
    func submit(amount: OnChainTransferAmount<BigUInt>, recepient: AccountAddress, lastFee: BigUInt?) {
        do {
            guard let transferType = transferType, let lastFeeModel = lastFeeModel else {
                presenter?.didReceiveError(CommonError.dataCorruption)
                return
            }

            var callCodingPath: CallCodingPath?

            let extrinsicClosure: EvmTransactionBuilderClosure = { [weak self] builder in
                guard let self else {
                    throw BaseOperationError.unexpectedDependentResult
                }

                let (newBuilder, codingPath) = try transferCommandFactory.addingTransferCommand(
                    to: builder,
                    amount: amount,
                    recipient: recepient,
                    type: transferType
                )

                callCodingPath = codingPath

                return newBuilder
            }

            let sender = try selectedAccount.accountId.toAddress(using: chain.chainFormat)

            let chainAssetId = ChainAssetId(chainId: chain.chainId, assetId: asset.assetId)

            let historyDraft: EvmHistoryDraftClosure = { [persistenceFilter, selectedAccount] transaction in
                guard persistenceFilter.canPersistExtrinsic(for: selectedAccount), let callCodingPath else {
                    return nil
                }

                return PersistExtrinsicFactory.createTransferItem(
                    source: transferType.transactionSource,
                    chainAssetId: chainAssetId,
                    details: PersistTransferDetails(
                        sender: sender,
                        receiver: recepient,
                        amount: amount.value,
                        txHash: try Data(hexString: transaction.transactionHash),
                        callPath: callCodingPath,
                        fee: lastFee,
                        feeAssetId: nil,
                        nonce: transaction.nonce
                    )
                )
            }

            let submissionWrapper = trackedSubmissionFactory.submitAndTrackWrapper(
                extrinsicClosure,
                price: lastFeeModel.transactionPrice,
                signer: signingWrapper,
                historyDraft: historyDraft
            )

            execute(
                wrapper: submissionWrapper,
                inOperationQueue: operationQueue,
                runningCallbackIn: .main
            ) { [weak self] result in
                guard let self else { return }

                switch result {
                case .success:
                    eventCenter.notify(with: WalletTransactionListUpdated())
                    completeSubmission(recepient: recepient)
                case let .failure(error):
                    presenter?.didReceiveError(error)
                }
            }
        } catch {
            presenter?.didReceiveError(error)
        }
    }
}

// MARK: Private

private extension TransferEvmOnChainConfirmInteractor {
    func completeSubmission(recepient: AccountAddress) {
        submitionPresenter?.didCompleteSubmition(by: nil)

        guard let recipientAccountId = try? recepient.toAccountId(using: chain.chainFormat) else {
            return
        }

        selfReceiveRevealer.reveal(
            destination: ChainAsset(chain: chain, asset: asset),
            recipientAccountId: recipientAccountId
        )
    }
}
