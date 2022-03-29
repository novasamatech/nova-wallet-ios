import UIKit
import BigInt
import RobinHood

final class TransferConfirmInteractor: TransferInteractor {
    let signingWrapper: SigningWrapperProtocol
    let persistExtrinsicService: PersistentExtrinsicServiceProtocol
    let eventCenter: EventCenterProtocol

    var submitionPresenter: TransferConfirmInteractorOutputProtocol? {
        presenter as? TransferConfirmInteractorOutputProtocol
    }

    init(
        selectedAccount: ChainAccountResponse,
        chain: ChainModel,
        asset: AssetModel,
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
        operationQueue: OperationQueue
    ) {
        self.signingWrapper = signingWrapper
        self.persistExtrinsicService = persistExtrinsicService
        self.eventCenter = eventCenter

        super.init(
            selectedAccount: selectedAccount,
            chain: chain,
            asset: asset,
            runtimeService: runtimeService,
            feeProxy: feeProxy,
            extrinsicService: extrinsicService,
            walletRemoteWrapper: walletRemoteWrapper,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            substrateStorageFacade: substrateStorageFacade,
            operationQueue: operationQueue
        )
    }

    private func persistExtrinsicAndComplete(
        details: PersistTransferDetails
    ) {
        persistExtrinsicService.saveTransfer(
            chainAssetId: ChainAssetId(chainId: chain.chainId, assetId: asset.assetId),
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

extension TransferConfirmInteractor: TransferConfirmInteractorInputProtocol {
    func submit(amount: BigUInt, recepient: AccountAddress, lastFee: BigUInt?) {
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
                signer: signingWrapper,
                runningIn: .main,
                completion: { [weak self] result in
                    switch result {
                    case let .success(txHash):
                        if
                            let callCodingPath = callCodingPath,
                            let txHashData = try? Data(hexString: txHash) {
                            let details = PersistTransferDetails(
                                sender: sender,
                                receiver: recepient,
                                amount: amount,
                                txHash: txHashData,
                                callPath: callCodingPath,
                                fee: lastFee
                            )

                            self?.persistExtrinsicAndComplete(details: details)
                        } else {
                            self?.presenter?.didCompleteSetup()
                        }

                    case let .failure(error):
                        self?.presenter?.didReceiveError(error)
                    }
                }
            )
        } catch {
            presenter?.didReceiveError(error)
        }
    }
}
