import UIKit
import BigInt
import Operation_iOS

final class TransferCrossChainConfirmInteractor: CrossChainTransferInteractor {
    let signingWrapper: SigningWrapperProtocol
    let persistExtrinsicService: PersistentExtrinsicServiceProtocol
    let persistenceFilter: ExtrinsicPersistenceFilterProtocol
    let eventCenter: EventCenterProtocol
    let selfReceiveRevealer: TransferSelfReceiveRevealer

    var submitionPresenter: TransferConfirmCrossChainInteractorOutputProtocol? {
        presenter as? TransferConfirmCrossChainInteractorOutputProtocol
    }

    init(
        selectedAccount: ChainAccountResponse,
        xcmTransfers: XcmTransfers,
        originChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        chainRegistry: ChainRegistryProtocol,
        feeProxy: XcmExtrinsicFeeProxyProtocol,
        extrinsicService: XcmTransferServiceProtocol,
        resolutionFactory: XcmTransferResolutionFactoryProtocol,
        signingWrapper: SigningWrapperProtocol,
        persistExtrinsicService: PersistentExtrinsicServiceProtocol,
        eventCenter: EventCenterProtocol,
        walletRemoteWrapper: WalletRemoteSubscriptionWrapperProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        substrateStorageFacade: StorageFacadeProtocol,
        persistenceFilter: ExtrinsicPersistenceFilterProtocol,
        selfReceiveRevealer: TransferSelfReceiveRevealer,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.signingWrapper = signingWrapper
        self.persistExtrinsicService = persistExtrinsicService
        self.persistenceFilter = persistenceFilter
        self.eventCenter = eventCenter
        self.selfReceiveRevealer = selfReceiveRevealer

        super.init(
            selectedAccount: selectedAccount,
            xcmTransfers: xcmTransfers,
            originChainAsset: originChainAsset,
            destinationChainAsset: destinationChainAsset,
            chainRegistry: chainRegistry,
            feeProxy: feeProxy,
            extrinsicService: extrinsicService,
            resolutionFactory: resolutionFactory,
            fungibilityPreservationProvider: AssetFungibilityPreservationProvider.createFromKnownChains(),
            walletRemoteWrapper: walletRemoteWrapper,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            substrateStorageFacade: substrateStorageFacade,
            currencyManager: currencyManager,
            operationQueue: operationQueue
        )
    }

    private func persistExtrinsicAndComplete(
        details: PersistExtrinsicDetails,
        sender: ExtrinsicSenderResolution,
        recipientAccountId: AccountId
    ) {
        guard let utilityAsset = originChainAsset.chain.utilityAssets().first else {
            completeSubmission(by: sender, recipientAccountId: recipientAccountId)
            return
        }

        let chainAssetId = ChainAssetId(chainId: originChainAsset.chain.chainId, assetId: utilityAsset.assetId)

        persistExtrinsicService.saveExtrinsic(
            source: .substrate,
            chainAssetId: chainAssetId,
            details: details,
            runningIn: .main
        ) { [weak self] result in
            switch result {
            case .success:
                self?.eventCenter.notify(with: WalletTransactionListUpdated())
                self?.completeSubmission(by: sender, recipientAccountId: recipientAccountId)
            case let .failure(error):
                self?.presenter?.didReceiveError(error)
            }
        }
    }
}

extension TransferCrossChainConfirmInteractor: TransferConfirmCrossChainInteractorInputProtocol {
    func submit(amount: BigUInt, recepient: AccountAddress, originFee: ExtrinsicFeeProtocol?) {
        do {
            guard let transferParties = transferParties else {
                throw CommonError.dataCorruption
            }

            let recepientAccountId = try recepient.toAccountId(using: destinationChainAsset.chain.chainFormat)

            let transferRequest = makeTransferRequest(
                parties: transferParties,
                amount: amount,
                recepientAccountId: recepientAccountId
            )

            let sender = try selectedAccount.accountId.toAddress(using: originChainAsset.chain.chainFormat)

            extrinsicService.submit(
                request: transferRequest,
                signer: signingWrapper,
                runningIn: .main
            ) { [weak self] result in
                guard let self else { return }

                switch result {
                case let .success(result):
                    let submissionSender = result.submittedModel.sender

                    guard persistenceFilter.canPersistExtrinsic(for: selectedAccount) else {
                        completeSubmission(by: submissionSender, recipientAccountId: recepientAccountId)
                        return
                    }

                    if
                        let txHashData = try? Data(hexString: result.submittedModel.txHash) {
                        let details = PersistExtrinsicDetails(
                            sender: sender,
                            txHash: txHashData,
                            callPath: result.callPath,
                            fee: originFee?.amount
                        )

                        persistExtrinsicAndComplete(
                            details: details,
                            sender: submissionSender,
                            recipientAccountId: recepientAccountId
                        )
                    } else {
                        completeSubmission(by: submissionSender, recipientAccountId: recepientAccountId)
                    }

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

private extension TransferCrossChainConfirmInteractor {
    func makeTransferRequest(
        parties: XcmTransferParties,
        amount: BigUInt,
        recepientAccountId: AccountId
    ) -> XcmTransferRequest {
        let destination = parties.destination.replacing(accountId: recepientAccountId)

        let unweightedRequest = XcmUnweightedTransferRequest(
            origin: parties.origin,
            destination: destination,
            reserve: parties.reserve,
            metadata: parties.metadata,
            amount: amount
        )

        return XcmTransferRequest(unweighted: unweightedRequest)
    }

    func completeSubmission(by sender: ExtrinsicSenderResolution, recipientAccountId: AccountId) {
        submitionPresenter?.didCompleteSubmition(by: sender)

        selfReceiveRevealer.reveal(
            destination: destinationChainAsset,
            recipientAccountId: recipientAccountId
        )
    }
}
