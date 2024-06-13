import Foundation
import Operation_iOS

/**
 *  Any on chain transfer flow (evm or substrate) needs sender balance fetch
 *  for sending asset and utility asset. Also price data fetch is required too.
 *
 *  This class is designed to locate afrometioned logic and intended to be
 *  overriden by concrete transfer interactor that depends on asset and network.
 */
class OnChainTransferBaseInteractor {
    weak var presenter: OnChainTransferSetupInteractorOutputProtocol?

    let selectedAccount: ChainAccountResponse
    let chain: ChainModel
    let asset: AssetModel
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let operationQueue: OperationQueue

    private var sendingAssetProvider: StreamableProvider<AssetBalance>?
    private var utilityAssetProvider: StreamableProvider<AssetBalance>?
    private var sendingAssetPriceProvider: StreamableProvider<PriceData>?
    private var utilityAssetPriceProvider: StreamableProvider<PriceData>?

    var isUtilityTransfer: Bool { chain.utilityAssets().first?.assetId == asset.assetId }

    init(
        selectedAccount: ChainAccountResponse,
        chain: ChainModel,
        asset: AssetModel,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.selectedAccount = selectedAccount
        self.chain = chain
        self.asset = asset
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.operationQueue = operationQueue
    }

    func setupSendingAssetBalanceProvider() {
        sendingAssetProvider = subscribeToAssetBalanceProvider(
            for: selectedAccount.accountId,
            chainId: chain.chainId,
            assetId: asset.assetId
        )
    }

    func setupUtilityAssetBalanceProviderIfNeeded() {
        if !isUtilityTransfer, let utilityAsset = chain.utilityAssets().first {
            utilityAssetProvider = subscribeToAssetBalanceProvider(
                for: selectedAccount.accountId,
                chainId: chain.chainId,
                assetId: utilityAsset.assetId
            )
        }
    }

    func setupSendingAssetPriceProviderIfNeeded() {
        if let priceId = asset.priceId {
            sendingAssetPriceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        } else {
            presenter?.didReceiveSendingAssetPrice(nil)
        }
    }

    func setupUtilityAssetPriceProviderIfNeeded() {
        guard !isUtilityTransfer, let utilityAsset = chain.utilityAssets().first else {
            return
        }

        if let priceId = utilityAsset.priceId {
            utilityAssetPriceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        } else {
            presenter?.didReceiveUtilityAssetPrice(nil)
        }
    }

    func handleAssetBalance(
        result _: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        fatalError("Must be overriden by child class")
    }
}

extension OnChainTransferBaseInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {}

extension OnChainTransferBaseInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            if asset.priceId == priceId {
                presenter?.didReceiveSendingAssetPrice(priceData)
            } else if chain.utilityAssets().first?.priceId == priceId {
                presenter?.didReceiveUtilityAssetPrice(priceData)
            }
        case .failure:
            presenter?.didReceiveError(CommonError.databaseSubscription)
        }
    }
}

extension OnChainTransferBaseInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil else {
            return
        }

        setupSendingAssetPriceProviderIfNeeded()
        setupUtilityAssetPriceProviderIfNeeded()
    }
}
