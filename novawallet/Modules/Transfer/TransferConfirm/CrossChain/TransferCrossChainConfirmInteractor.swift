import UIKit
import BigInt
import Operation_iOS

final class TransferCrossChainConfirmInteractor: CrossChainTransferInteractor {
    let signingWrapper: SigningWrapperProtocol
    let persistExtrinsicService: PersistentExtrinsicServiceProtocol
    let persistenceFilter: ExtrinsicPersistenceFilterProtocol
    let eventCenter: EventCenterProtocol

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
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.signingWrapper = signingWrapper
        self.persistExtrinsicService = persistExtrinsicService
        self.persistenceFilter = persistenceFilter
        self.eventCenter = eventCenter

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
        details: PersistExtrinsicDetails
    ) {
        guard let utilityAsset = originChainAsset.chain.utilityAssets().first else {
            submitionPresenter?.didCompleteSubmition()
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
                self?.submitionPresenter?.didCompleteSubmition()
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

            let destination = transferParties.destination.replacing(accountId: recepientAccountId)
            let unweightedRequest = XcmUnweightedTransferRequest(
                origin: transferParties.origin,
                destination: destination,
                reserve: transferParties.reserve,
                metadata: transferParties.metadata,
                amount: amount
            )

            let transferRequest = XcmTransferRequest(unweighted: unweightedRequest)

            let sender = try selectedAccount.accountId.toAddress(using: originChainAsset.chain.chainFormat)

            extrinsicService.submit(
                request: transferRequest,
                signer: signingWrapper,
                runningIn: .main
            ) { [weak self] result in
                guard let self else { return }

                switch result {
                case let .success(result):
                    guard persistenceFilter.canPersistExtrinsic(for: selectedAccount) else {
                        submitionPresenter?.didCompleteSubmition()
                        return
                    }

                    if
                        let txHashData = try? Data(hexString: result.txHash) {
                        let details = PersistExtrinsicDetails(
                            sender: sender,
                            txHash: txHashData,
                            callPath: result.callPath,
                            fee: originFee?.amount
                        )

                        persistExtrinsicAndComplete(details: details)
                    } else {
                        submitionPresenter?.didReceiveError(CommonError.dataCorruption)
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
