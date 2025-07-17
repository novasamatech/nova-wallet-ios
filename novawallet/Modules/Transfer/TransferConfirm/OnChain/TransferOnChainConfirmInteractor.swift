import UIKit
import BigInt
import Operation_iOS

final class TransferOnChainConfirmInteractor: OnChainTransferInteractor {
    let signingWrapper: SigningWrapperProtocol
    let persistExtrinsicService: PersistentExtrinsicServiceProtocol
    let persistenceFilter: ExtrinsicPersistenceFilterProtocol
    let eventCenter: EventCenterProtocol

    var submitionPresenter: TransferConfirmOnChainInteractorOutputProtocol? {
        presenter as? TransferConfirmOnChainInteractorOutputProtocol
    }

    init(
        selectedAccount: ChainAccountResponse,
        chain: ChainModel,
        asset: AssetModel,
        feeAsset: ChainAsset?,
        runtimeService: RuntimeCodingServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        signingWrapper: SigningWrapperProtocol,
        persistExtrinsicService: PersistentExtrinsicServiceProtocol,
        eventCenter: EventCenterProtocol,
        walletRemoteWrapper: WalletRemoteSubscriptionWrapperProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        substrateStorageFacade: StorageFacadeProtocol,
        transferAggregationWrapperFactory: AssetTransferAggregationFactoryProtocol,
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
            chain: chain,
            asset: asset,
            feeAsset: feeAsset,
            runtimeService: runtimeService,
            feeProxy: feeProxy,
            extrinsicService: extrinsicService,
            walletRemoteWrapper: walletRemoteWrapper,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            substrateStorageFacade: substrateStorageFacade,
            transferAggregationWrapperFactory: transferAggregationWrapperFactory,
            currencyManager: currencyManager,
            operationQueue: operationQueue
        )
    }

    private func persistExtrinsicAndComplete(
        details: PersistTransferDetails,
        sender: ExtrinsicSenderResolution
    ) {
        persistExtrinsicService.saveTransfer(
            source: .substrate,
            chainAssetId: ChainAssetId(chainId: chain.chainId, assetId: asset.assetId),
            details: details,
            runningIn: .main
        ) { [weak self] result in
            switch result {
            case .success:
                self?.eventCenter.notify(with: WalletTransactionListUpdated())
                self?.submitionPresenter?.didCompleteSubmition(by: sender)
            case let .failure(error):
                self?.presenter?.didReceiveError(error)
            }
        }
    }
}

extension TransferOnChainConfirmInteractor: TransferConfirmOnChainInteractorInputProtocol {
    func submit(amount: OnChainTransferAmount<BigUInt>, recepient: AccountAddress, lastFee: BigUInt?) {
        do {
            let accountId = try recepient.toAccountId(using: chain.chainFormat)

            var callCodingPath: CallCodingPath?

            let extrinsicClosure: ExtrinsicBuilderClosure = { [weak self] builder in
                guard let strongSelf = self else {
                    throw BaseOperationError.unexpectedDependentResult
                }

                let (newBuilder, codingPath) = try strongSelf.addingTransferCommand(
                    to: builder,
                    amount: amount,
                    recepient: accountId
                )

                callCodingPath = codingPath

                return newBuilder
            }

            let sender = try selectedAccount.accountId.toAddress(using: chain.chainFormat)

            extrinsicService.submit(
                extrinsicClosure,
                payingIn: feeAsset?.chainAssetId,
                signer: signingWrapper,
                runningIn: .main,
                completion: { [weak self] result in
                    guard let self else { return }

                    switch result {
                    case let .success(submittedModel):
                        guard persistenceFilter.canPersistExtrinsic(for: selectedAccount) else {
                            submitionPresenter?.didCompleteSubmition(by: submittedModel.sender)
                            return
                        }

                        if
                            let callCodingPath = callCodingPath,
                            let txHashData = try? Data(hexString: submittedModel.txHash) {
                            let details = PersistTransferDetails(
                                sender: sender,
                                receiver: recepient,
                                amount: amount.value,
                                txHash: txHashData,
                                callPath: callCodingPath,
                                fee: lastFee,
                                feeAssetId: feeAsset?.asset.assetId
                            )

                            persistExtrinsicAndComplete(details: details, sender: submittedModel.sender)
                        } else {
                            submitionPresenter?.didCompleteSubmition(by: submittedModel.sender)
                        }

                    case let .failure(error):
                        presenter?.didReceiveError(error)
                    }
                }
            )
        } catch {
            presenter?.didReceiveError(error)
        }
    }
}
