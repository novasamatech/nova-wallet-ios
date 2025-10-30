import UIKit
import BigInt
import Operation_iOS

final class TransferEvmOnChainConfirmInteractor: EvmOnChainTransferInteractor {
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
        feeProxy: EvmTransactionFeeProxyProtocol,
        transferCommandFactory: EvmTransferCommandFactory,
        extrinsicService: EvmTransactionServiceProtocol,
        validationProviderFactory: EvmValidationProviderFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        signingWrapper: SigningWrapperProtocol,
        persistExtrinsicService: PersistentExtrinsicServiceProtocol,
        persistenceFilter: ExtrinsicPersistenceFilterProtocol,
        eventCenter: EventCenterProtocol,
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

    private func persistExtrinsicAndComplete(
        details: PersistTransferDetails,
        type: TransferType
    ) {
        persistExtrinsicService.saveTransfer(
            source: type.transactionSource,
            chainAssetId: ChainAssetId(chainId: chain.chainId, assetId: asset.assetId),
            details: details,
            runningIn: .main
        ) { [weak self] result in
            guard let self = self else {
                return
            }

            switch result {
            case .success:
                self.eventCenter.notify(with: WalletTransactionListUpdated())
                self.submitionPresenter?.didCompleteSubmition(by: nil)
            case let .failure(error):
                self.presenter?.didReceiveError(error)
            }
        }
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

            extrinsicService.submit(
                extrinsicClosure,
                price: EvmTransactionPrice(gasLimit: lastFeeModel.gasLimit, gasPrice: lastFeeModel.gasPrice),
                signer: signingWrapper,
                runningIn: .main
            ) { [weak self] result in
                guard let self else { return }

                switch result {
                case let .success(txHash):
                    guard persistenceFilter.canPersistExtrinsic(for: selectedAccount) else {
                        submitionPresenter?.didCompleteSubmition(by: nil)
                        return
                    }

                    if
                        let callCodingPath = callCodingPath,
                        let txHashData = try? Data(hexString: txHash) {
                        let details = PersistTransferDetails(
                            sender: sender,
                            receiver: recepient,
                            amount: amount.value,
                            txHash: txHashData,
                            callPath: callCodingPath,
                            fee: lastFee,
                            feeAssetId: nil
                        )

                        persistExtrinsicAndComplete(details: details, type: transferType)
                    } else {
                        submitionPresenter?.didCompleteSubmition(by: nil)
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
