import UIKit
import BigInt
import RobinHood

final class TransferCrossChainConfirmInteractor: CrossChainTransferInteractor {
    let signingWrapper: SigningWrapperProtocol
    let persistExtrinsicService: PersistentExtrinsicServiceProtocol
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
        operationQueue: OperationQueue
    ) {
        self.signingWrapper = signingWrapper
        self.persistExtrinsicService = persistExtrinsicService
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
            walletRemoteWrapper: walletRemoteWrapper,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            substrateStorageFacade: substrateStorageFacade,
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
            chainAssetId: chainAssetId,
            details: details,
            runningIn: .main
        ) { [weak self] result in
            switch result {
            case .success:
                self?.eventCenter.notify(with: WalletNewTransactionInserted())
                self?.submitionPresenter?.didCompleteSubmition()
            case let .failure(error):
                self?.presenter?.didReceiveError(error)
            }
        }
    }
}

extension TransferCrossChainConfirmInteractor: TransferConfirmCrossChainInteractorInputProtocol {
    func submit(amount: BigUInt, recepient: AccountAddress, weightLimit: BigUInt, originFee: BigUInt?) {
        do {
            guard let transferParties = transferParties else {
                throw CommonError.dataCorruption
            }

            let recepientAccountId = try recepient.toAccountId(using: destinationChainAsset.chain.chainFormat)

            let destination = transferParties.destination.replacing(accountId: recepientAccountId)
            let unweightedRequest = XcmUnweightedTransferRequest(
                origin: originChainAsset,
                destination: destination,
                reserve: transferParties.reserve,
                amount: amount
            )

            let transferRequest = XcmTransferRequest(unweighted: unweightedRequest, maxWeight: weightLimit)

            let sender = try selectedAccount.accountId.toAddress(using: originChainAsset.chain.chainFormat)

            extrinsicService.submit(
                request: transferRequest,
                xcmTransfers: xcmTransfers,
                signer: signingWrapper,
                runningIn: .main
            ) { [weak self] result in
                switch result {
                case let .success(result):
                    if let txHashData = try? Data(hexString: result.txHash) {
                        let details = PersistExtrinsicDetails(
                            sender: sender,
                            txHash: txHashData,
                            callPath: result.callPath,
                            fee: originFee
                        )

                        self?.persistExtrinsicAndComplete(details: details)
                    } else {
                        self?.submitionPresenter?.didReceiveError(CommonError.dataCorruption)
                    }

                case let .failure(error):
                    self?.presenter?.didReceiveError(error)
                }
            }
        } catch {
            presenter?.didReceiveError(error)
        }
    }
}
