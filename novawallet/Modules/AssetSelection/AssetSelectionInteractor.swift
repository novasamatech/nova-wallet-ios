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

    private var assetBalanceSubscriptions: [AccountId: StreamableProvider<AssetBalance>] = [:]
    private var assetBalanceIdMapping: [String: AssetBalanceId] = [:]
    private var availableTokenPrice: [ChainAssetId: AssetModel.PriceId] = [:]
    private var priceSubscription: AnySingleValueProvider<[PriceData]>?

    init(
        selectedMetaAccount: MetaAccountModel,
        repository: AnyDataProviderRepository<ChainModel>,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        assetFilter: @escaping AssetSelectionFilter,
        operationQueue: OperationQueue
    ) {
        self.selectedMetaAccount = selectedMetaAccount
        self.repository = repository
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.assetFilter = assetFilter
        self.operationQueue = operationQueue
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

        setupPriceProvider(for: Set(availableTokenPrice.values))
    }

    private func setupPriceProvider(for priceIdSet: Set<AssetModel.PriceId>) {
        priceSubscription = nil

        let priceIds = Array(priceIdSet).sorted()

        guard !priceIds.isEmpty else {
            return
        }

        priceSubscription = priceLocalSubscriptionFactory.getPriceListProvider(for: priceIds)

        let updateClosure = { [weak self] (changes: [DataProviderChange<[PriceData]>]) in
            let finalValue = changes.reduceToLastChange()

            switch finalValue {
            case let .some(prices):
                let chainPrices = zip(priceIds, prices).reduce(
                    into: [ChainAssetId: PriceData]()
                ) { result, item in
                    guard let chainAssetIds = self?.availableTokenPrice.filter({ $0.value == item.0 })
                        .map(\.key) else {
                        return
                    }

                    for chainAssetId in chainAssetIds {
                        result[chainAssetId] = item.1
                    }
                }

                self?.presenter?.didReceivePrices(result: .success(chainPrices))
            case .none:
                self?.presenter?.didReceivePrices(result: nil)
            }
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.presenter?.didReceivePrices(result: .failure(error))
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: true,
            waitsInProgressSyncOnAdd: false
        )

        priceSubscription?.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
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

                accum[chainAssetId] = .success(balance.transferable)
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
