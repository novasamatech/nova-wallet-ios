import Foundation
import BigInt
import Operation_iOS

final class EvmGiftTransferConfirmInteractor: EvmGiftTransferInteractor {
    let giftSubmissionFactory: EvmGiftSubmissionFactoryProtocol

    var submissionPresenter: GiftTransferConfirmInteractorOutputProtocol? {
        presenter as? GiftTransferConfirmInteractorOutputProtocol
    }

    init(
        giftSubmissionFactory: EvmGiftSubmissionFactoryProtocol,
        selectedAccount: ChainAccountResponse,
        chain: ChainModel,
        asset: AssetModel,
        feeProxy: EvmTransactionFeeProxyProtocol,
        transferCommandFactory: EvmTransferCommandFactory,
        transactionService: EvmTransactionServiceProtocol,
        validationProviderFactory: EvmValidationProviderFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.giftSubmissionFactory = giftSubmissionFactory

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

// MARK: - GiftTransferConfirmInteractorInputProtocol

extension EvmGiftTransferConfirmInteractor: GiftTransferConfirmInteractorInputProtocol {
    func submit(
        amount: OnChainTransferAmount<BigUInt>,
        lastFeeDescription: GiftFeeDescription?
    ) {
        guard
            let lastFeeModel,
            let lastFeeDescription,
            let transferType
        else { return }

        let wrapper = giftSubmissionFactory.createSubmissionWrapper(
            amount: amount,
            feeDescription: lastFeeDescription,
            evmFee: lastFeeModel,
            transferType: transferType
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
