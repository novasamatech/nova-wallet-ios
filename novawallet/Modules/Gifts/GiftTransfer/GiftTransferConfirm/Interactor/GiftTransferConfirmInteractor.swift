import Foundation
import BigInt
import Operation_iOS

final class GiftTransferConfirmInteractor: GiftTransferInteractor {
    let giftTransferSubmissionFactory: GiftTransferSubmissionFactoryProtocol

    var submissionPresenter: GiftTransferConfirmInteractorOutputProtocol? {
        presenter as? GiftTransferConfirmInteractorOutputProtocol
    }

    init(
        giftTransferSubmissionFactory: GiftTransferSubmissionFactoryProtocol,
        selectedAccount: ChainAccountResponse,
        chain: ChainModel,
        asset: AssetModel,
        runtimeService: RuntimeCodingServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        transferCommandFactory: SubstrateTransferCommandFactory,
        extrinsicService: ExtrinsicServiceProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        transferAggregationWrapperFactory: AssetTransferAggregationFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.giftTransferSubmissionFactory = giftTransferSubmissionFactory

        super.init(
            selectedAccount: selectedAccount,
            chain: chain,
            asset: asset,
            runtimeService: runtimeService,
            feeProxy: feeProxy,
            transferCommandFactory: transferCommandFactory,
            extrinsicService: extrinsicService,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            transferAggregationWrapperFactory: transferAggregationWrapperFactory,
            currencyManager: currencyManager,
            operationQueue: operationQueue
        )
    }
}

// MARK: - GiftTransferConfirmInteractorInputProtocol

extension GiftTransferConfirmInteractor: GiftTransferConfirmInteractorInputProtocol {
    func submit(
        amount: OnChainTransferAmount<BigUInt>,
        lastFeeDescription: GiftFeeDescription?
    ) {
        let wrapper = giftTransferSubmissionFactory.createSubmissionWrapper(
            amount: amount,
            assetStorageInfo: sendingAssetInfo,
            feeDescription: lastFeeDescription
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in

            switch result {
            case let .success(sender):
                self?.submissionPresenter?.didCompleteSubmition(by: sender)
            case let .failure(error):
                self?.presenter?.didReceiveError(error)
            }
        }
    }
}
