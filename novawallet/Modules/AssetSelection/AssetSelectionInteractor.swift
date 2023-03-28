import UIKit
import RobinHood
import BigInt

final class AssetSelectionInteractor {
    weak var presenter: AssetSelectionInteractorOutputProtocol?

    let selectedMetaAccount: MetaAccountModel
    let repository: AnyDataProviderRepository<ChainModel>
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let assetFilter: AssetSelectionFilter
    let operationQueue: OperationQueue
    let balanceSlice: KeyPath<AssetBalance, BigUInt>

    private var assetBalanceSubscriptions: [AccountId: StreamableProvider<AssetBalance>] = [:]
    private var assetBalanceIdMapping: [String: AssetBalanceId] = [:]
    private var availableTokenPrice: [ChainAssetId: AssetModel.PriceId] = [:]
    private var priceSubscription: StreamableProvider<PriceData>?

    init(
        selectedMetaAccount: MetaAccountModel,
        balanceSlice: KeyPath<AssetBalance, BigUInt>,
        repository: AnyDataProviderRepository<ChainModel>,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        assetFilter: @escaping AssetSelectionFilter,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.selectedMetaAccount = selectedMetaAccount
        self.balanceSlice = balanceSlice
        self.repository = repository
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.assetFilter = assetFilter
        self.operationQueue = operationQueue
        self.currencyManager = currencyManager
    }

    private func fetchChainsAndSubscribeBalance() {
        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        fetchOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.handleChains(result: fetchOperation.result)
            }
        }

        operationQueue.addOperation(fetchOperation)
    }

    private func handleChains(result: Result<[ChainModel], Error>?) {
        switch result {
        case let .success(chains):
            let chainAssets: [ChainAsset] = chains.reduce(into: []) { result, item in
                let assets: [ChainAsset] = item.assets.compactMap { asset in
                    let chainAsset = ChainAsset(chain: item, asset: asset)
                    if assetFilter(chainAsset) {
                        return chainAsset
                    } else {
                        return nil
                    }
                }

                result.append(contentsOf: assets)
            }

            presenter?.didReceiveChainAssets(result: .success(chainAssets))
            subscribeAssetBalance(for: chainAssets)
            setupPriceSubscription(from: chains)
        case let .failure(error):
            presenter?.didReceiveChainAssets(result: .failure(error))
        case .none:
            presenter?.didReceiveChainAssets(result: .failure(BaseOperationError.parentOperationCancelled))
        }
    }

    private func subscribeAssetBalance(for chainAssets: [ChainAsset]) {
        assetBalanceIdMapping = chainAssets.reduce(into: assetBalanceIdMapping) { result, chainAsset in
            guard let accountId = selectedMetaAccount.fetch(
                for: chainAsset.chain.accountRequest()
            )?.accountId else {
                return
            }

            let chainAssetId = chainAsset.chainAssetId

            let assetBalanceRawId = AssetBalance.createIdentifier(
                for: ChainAssetId(chainId: chainAssetId.chainId, assetId: chainAssetId.assetId),
                accountId: accountId
            )

            if result[assetBalanceRawId] == nil {
                result[assetBalanceRawId] = AssetBalanceId(
                    chainId: chainAssetId.chainId,
                    assetId: chainAssetId.assetId,
                    accountId: accountId
                )
            }
        }

        assetBalanceSubscriptions = chainAssets.reduce(into: assetBalanceSubscriptions) { result, chainAsset in
            guard let accountId = selectedMetaAccount.fetch(
                for: chainAsset.chain.accountRequest()
            )?.accountId else {
                return
            }

            if result[accountId] == nil {
                result[accountId] = subscribeToAccountBalanceProvider(for: accountId)
            }
        }

        if assetBalanceSubscriptions.isEmpty {
            presenter?.didReceiveBalance(results: [:])
        }
    }

    private func setupPriceSubscription(from chains: [ChainModel]) {
        for chain in chains {
            availableTokenPrice = chain.assets.reduce(into: availableTokenPrice) { result, asset in
                guard let priceId = asset.priceId else {
                    return
                }

                let chainAssetId = ChainAssetId(chainId: chain.chainId, assetId: asset.assetId)
                result[chainAssetId] = priceId
            }
        }

        setupPriceProvider(for: Set(availableTokenPrice.values), currency: selectedCurrency)
    }

    private func setupPriceProvider(for priceIdSet: Set<AssetModel.PriceId>, currency: Currency) {
        priceSubscription = nil

        let priceIds = Array(priceIdSet).sorted()

        guard !priceIds.isEmpty else {
            presenter?.didReceivePrice(changes: [:])
            return
        }

        priceSubscription = priceLocalSubscriptionFactory.getAllPricesStreamableProvider(
            for: priceIds,
            currency: currency
        )

        let updateClosure = { [weak self] (changes: [DataProviderChange<PriceData>]) in
            guard let strongSelf = self else {
                return
            }

            let mappedChanges = changes.reduce(
                using: .init(),
                availableTokenPrice: strongSelf.availableTokenPrice,
                currency: currency
            )

            self?.presenter?.didReceivePrice(changes: mappedChanges)
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.presenter?.didReceivePrice(error: error)
            return
        }

        let options = StreamableProviderObserverOptions(
            alwaysNotifyOnRefresh: true,
            waitsInProgressSyncOnAdd: false,
            initialSize: 0,
            refreshWhenEmpty: false
        )

        priceSubscription?.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        priceSubscription?.refresh()
    }
}

extension AssetSelectionInteractor: AssetSelectionInteractorInputProtocol {
    func setup() {
        fetchChainsAndSubscribeBalance()
    }
}

extension AssetSelectionInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    private func handleAccountBalanceError(_ error: Error, accountId: AccountId) {
        let results = assetBalanceIdMapping.values.reduce(
            into: [ChainAssetId: Result<BigUInt?, Error>]()
        ) { accum, assetBalanceId in
            guard assetBalanceId.accountId == accountId else {
                return
            }

            let chainAssetId = ChainAssetId(
                chainId: assetBalanceId.chainId,
                assetId: assetBalanceId.assetId
            )

            accum[chainAssetId] = .failure(error)
        }

        presenter?.didReceiveBalance(results: results)
    }

    private func handleAccountBalanceChanges(
        _ changes: [DataProviderChange<AssetBalance>],
        accountId: AccountId
    ) {
        // prepopulate non existing balances with zeros
        let initialItems = assetBalanceIdMapping.values.reduce(
            into: [ChainAssetId: Result<BigUInt?, Error>]()
        ) { accum, assetBalanceId in
            guard assetBalanceId.accountId == accountId else {
                return
            }

            let chainAssetId = ChainAssetId(
                chainId: assetBalanceId.chainId,
                assetId: assetBalanceId.assetId
            )

            accum[chainAssetId] = .success(nil)
        }

        let results = changes.reduce(
            into: initialItems
        ) { accum, change in
            switch change {
            case let .insert(balance), let .update(balance):
                guard
                    let assetBalanceId = assetBalanceIdMapping[balance.identifier],
                    assetBalanceId.accountId == accountId else {
                    return
                }

                let chainAssetId = ChainAssetId(
                    chainId: assetBalanceId.chainId,
                    assetId: assetBalanceId.assetId
                )

                accum[chainAssetId] = .success(balance[keyPath: balanceSlice])
            case let .delete(deletedIdentifier):
                guard let assetBalanceId = assetBalanceIdMapping[deletedIdentifier] else {
                    return
                }

                let chainAssetId = ChainAssetId(
                    chainId: assetBalanceId.chainId,
                    assetId: assetBalanceId.assetId
                )

                accum[chainAssetId] = .success(0)
            }
        }

        presenter?.didReceiveBalance(results: results)
    }

    func handleAccountBalance(
        result: Result<[DataProviderChange<AssetBalance>], Error>,
        accountId: AccountId
    ) {
        switch result {
        case let .success(changes):
            handleAccountBalanceChanges(changes, accountId: accountId)
        case let .failure(error):
            handleAccountBalanceError(error, accountId: accountId)
        }
    }
}

extension AssetSelectionInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil else {
            return
        }

        setupPriceProvider(for: Set(availableTokenPrice.values), currency: selectedCurrency)
    }
}
