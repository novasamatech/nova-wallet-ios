import UIKit
import BigInt
import RobinHood

final class TransferEvmOnChainConfirmInteractor: EvmOnChainTransferInteractor {
    let signingWrapper: SigningWrapperProtocol
    let persistExtrinsicService: PersistentExtrinsicServiceProtocol
    let eventCenter: EventCenterProtocol

    var submitionPresenter: TransferConfirmOnChainInteractorOutputProtocol? {
        presenter as? TransferConfirmOnChainInteractorOutputProtocol
    }

    init(
        selectedAccount: ChainAccountResponse,
        chain: ChainModel,
        asset: AssetModel,
        feeProxy: EvmTransactionFeeProxyProtocol,
        extrinsicService: EvmTransactionServiceProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        signingWrapper: SigningWrapperProtocol,
        persistExtrinsicService: PersistentExtrinsicServiceProtocol,
        eventCenter: EventCenterProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.signingWrapper = signingWrapper
        self.persistExtrinsicService = persistExtrinsicService
        self.eventCenter = eventCenter

        super.init(
            selectedAccount: selectedAccount,
            chain: chain,
            asset: asset,
            feeProxy: feeProxy,
            extrinsicService: extrinsicService,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            currencyManager: currencyManager,
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
                self?.eventCenter.notify(with: WalletTransactionListUpdated())
                self?.submitionPresenter?.didCompleteSubmition()
            case let .failure(error):
                self?.presenter?.didReceiveError(error)
            }
        }
    }
}

extension TransferEvmOnChainConfirmInteractor: TransferConfirmOnChainInteractorProtocol {
    func submit(amount: OnChainTransferAmount<BigUInt>, recepient: AccountAddress, lastFee: BigUInt?) {
        do {
            guard let contractAddress = contractAddress else {
                return
            }

            var callCodingPath: CallCodingPath?

            let extrinsicClosure: EvmTransactionBuilderClosure = { [weak self] builder in
                guard let strongSelf = self else {
                    throw BaseOperationError.unexpectedDependentResult
                }

                let (newBuilder, codingPath) = try strongSelf.addingTransferCommand(
                    to: builder,
                    amount: amount,
                    recepient: recepient,
                    contract: contractAddress
                )

                callCodingPath = codingPath

                return newBuilder
            }

            let sender = try selectedAccount.accountId.toAddress(using: chain.chainFormat)

            extrinsicService.submit(
                extrinsicClosure,
                signer: signingWrapper,
                runningIn: .main
            ) { [weak self] result in
                switch result {
                case let .success(txHash):
                    if
                        let callCodingPath = callCodingPath,
                        let txHashData = try? Data(hexString: txHash) {
                        let details = PersistTransferDetails(
                            sender: sender,
                            receiver: recepient,
                            amount: amount.value,
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
        } catch {
            presenter?.didReceiveError(error)
        }
    }
}
