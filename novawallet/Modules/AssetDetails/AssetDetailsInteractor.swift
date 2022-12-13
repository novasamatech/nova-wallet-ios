import UIKit
import RobinHood

final class AssetDetailsInteractor {
    weak var presenter: AssetDetailsInteractorOutputProtocol!
    let chainAsset: ChainAsset
    let selectedMetaAccount: MetaAccountModel
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let crowdloansLocalSubscriptionFactory: CrowdloanContributionLocalSubscriptionFactoryProtocol
    let purchaseProvider: PurchaseProviderProtocol
    let assetMapper: CustomAssetMapper

    private var assetLocksSubscription: StreamableProvider<AssetLock>?
    private var priceSubscription: AnySingleValueProvider<PriceData>?
    private var assetBalanceSubscription: StreamableProvider<AssetBalance>?
    private var crowdloansSubscription: StreamableProvider<CrowdloanContributionData>?

    private var accountId: AccountId? {
        selectedMetaAccount.fetch(for: chainAsset.chain.accountRequest())?.accountId
    }

    init(
        selectedMetaAccount: MetaAccountModel,
        chainAsset: ChainAsset,
        purchaseProvider: PurchaseProviderProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        crowdloansLocalSubscriptionFactory: CrowdloanContributionLocalSubscriptionFactoryProtocol,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.crowdloansLocalSubscriptionFactory = crowdloansLocalSubscriptionFactory
        self.selectedMetaAccount = selectedMetaAccount
        self.chainAsset = chainAsset
        self.purchaseProvider = purchaseProvider
        assetMapper = CustomAssetMapper(
            type: chainAsset.asset.type,
            typeExtras: chainAsset.asset.typeExtras
        )
        self.currencyManager = currencyManager
    }

    private func subscribePrice() {
        if let priceId = chainAsset.asset.priceId {
            priceSubscription = subscribeToPrice(for: priceId, currency: selectedCurrency)
        } else {
            presenter.didReceive(price: nil)
        }
    }

    private var isTransfersEnable: Bool {
        if let type = chainAsset.asset.type {
            switch AssetType(rawValue: type) {
            case .statemine, .none, .evm:
                return true
            case .orml:
                if let extras = try? chainAsset.asset.typeExtras?.map(to: OrmlTokenExtras.self) {
                    return extras.transfersEnabled ?? true
                } else {
                    return false
                }
            }
        } else {
            return true
        }
    }

    private func setAvailableOperations() {
        guard let accountId = accountId else {
            return
        }
        var operations: AssetDetailsOperation = .init()

        if isTransfersEnable {
            operations.insert(.send)
        }

        let actions = purchaseProvider.buildPurchaseActions(
            for: chainAsset,
            accountId: accountId
        )

        if !actions.isEmpty {
            operations.insert(.buy)
        }

        operations.insert(.receive)

        presenter.didReceive(purchaseActions: actions)
        presenter.didReceive(availableOperations: operations)
    }
}

extension AssetDetailsInteractor: AssetDetailsInteractorInputProtocol {
    func setup() {
        guard let accountId = accountId else {
            return
        }
        subscribePrice()
        assetBalanceSubscription = subscribeToAssetBalanceProvider(
            for: accountId,
            chainId: chainAsset.chain.chainId,
            assetId: chainAsset.asset.assetId
        )
        assetLocksSubscription = subscribeToLocksProvider(
            for: accountId,
            chainId: chainAsset.chain.chainId,
            assetId: chainAsset.asset.assetId
        )
        if chainAsset.chain.hasCrowdloans {
            crowdloansSubscription = subscribeToCrowdloansProvider(
                for: accountId,
                chain: chainAsset.chain
            )
        } else {
            crowdloansSubscription = nil
        }
        setAvailableOperations()
    }
}

extension AssetDetailsInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) {
        guard chainId == chainAsset.chain.chainId,
              assetId == chainAsset.asset.assetId,
              accountId == self.accountId else {
            return
        }

        switch result {
        case let .success(balance):
            presenter.didReceive(balance: balance ?? AssetBalance.createZero(
                for: chainAsset.chainAssetId,
                accountId: accountId
            ))
        case let .failure(error):
            presenter.didReceive(error: .accountBalance(error))
        }
    }

    func handleAccountLocks(
        result: Result<[DataProviderChange<AssetLock>], Error>,
        accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) {
        guard chainId == chainAsset.chain.chainId,
              assetId == chainAsset.asset.assetId,
              accountId == self.accountId else {
            return
        }

        switch result {
        case let .failure(error):
            presenter.didReceive(error: .locks(error))
        case let .success(changes):
            presenter.didReceive(lockChanges: changes)
        }
    }
}

extension AssetDetailsInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            presenter.didReceive(price: priceData)
        case let .failure(error):
            presenter.didReceive(error: .price(error))
        }
    }
}

extension AssetDetailsInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        if presenter != nil, let priceId = chainAsset.asset.priceId {
            priceSubscription = subscribeToPrice(for: priceId, currency: selectedCurrency)
        }
    }
}

extension AssetDetailsInteractor: CrowdloanContributionLocalSubscriptionHandler, CrowdloansLocalStorageSubscriber {
    func handleCrowdloans(
        result: Result<[DataProviderChange<CrowdloanContributionData>], Error>,
        accountId: AccountId,
        chain: ChainModel
    ) {
        guard self.accountId == accountId,
              chainAsset.chain.chainId == chain.chainId else {
            return
        }

        switch result {
        case let .failure(error):
            presenter.didReceive(error: .crowdloans(error))
        case let .success(changes):
            presenter.didReceive(crowdloanChanges: changes)
        }
    }
}
