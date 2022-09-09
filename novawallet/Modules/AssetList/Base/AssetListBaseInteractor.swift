import Foundation
import RobinHood
import SubstrateSdk
import SoraKeystore
import BigInt

class AssetListBaseInteractor {
    weak var basePresenter: AssetListBaseInteractorOutputProtocol?

    let selectedWalletSettings: SelectedWalletSettings
    let chainRegistry: ChainRegistryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let logger: LoggerProtocol?

    private(set) var assetBalanceSubscriptions: [AccountId: StreamableProvider<AssetBalance>] = [:]
    private(set) var assetLocksSubscriptions: [AccountId: StreamableProvider<AssetLock>] = [:]
    private(set) var assetBalanceIdMapping: [String: AssetBalanceId] = [:]
    private(set) var priceSubscription: AnySingleValueProvider<[PriceData]>?
    private(set) var availableTokenPrice: [ChainAssetId: AssetModel.PriceId] = [:]
    private(set) var availableChains: [ChainModel.Id: ChainModel] = [:]
    private(set) var accountLocks: [AccountId: [AssetLock]] = [:]

    init(
        selectedWalletSettings: SelectedWalletSettings,
        chainRegistry: ChainRegistryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.selectedWalletSettings = selectedWalletSettings
        self.chainRegistry = chainRegistry
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.logger = logger
        self.currencyManager = currencyManager
    }

    func clearAccountSubscriptions() {
        assetBalanceSubscriptions.values.forEach { $0.removeObserver(self) }
        assetBalanceSubscriptions = [:]

        assetBalanceIdMapping = [:]

        assetLocksSubscriptions.values.forEach { $0.removeObserver(self) }
        assetLocksSubscriptions = [:]
    }

    private func handle(changes: [DataProviderChange<ChainModel>]) {
        guard let selectedMetaAccount = selectedWalletSettings.value else {
            return
        }

        let accountDependentChanges = changes.filter { change in
            switch change {
            case let .insert(newItem), let .update(newItem):
                return selectedMetaAccount.fetch(for: newItem.accountRequest()) != nil ? true : false
            case .delete:
                return true
            }
        }

        basePresenter?.didReceiveChainModelChanges(accountDependentChanges)
        applyChanges(allChanges: changes, accountDependentChanges: accountDependentChanges)
    }

    func applyChanges(
        allChanges: [DataProviderChange<ChainModel>],
        accountDependentChanges: [DataProviderChange<ChainModel>]
    ) {
        updateAvailableChains(from: allChanges)
        updateAccountInfoSubscription(from: accountDependentChanges)
        updatePriceSubscription(from: allChanges)
    }

    func updateAvailableChains(from changes: [DataProviderChange<ChainModel>]) {
        for change in changes {
            switch change {
            case let .insert(newItem), let .update(newItem):
                availableChains[newItem.chainId] = newItem
            case let .delete(deletedIdentifier):
                availableChains[deletedIdentifier] = nil
            }
        }
    }

    func updateAccountInfoSubscription(from changes: [DataProviderChange<ChainModel>]) {
        guard let selectedMetaAccount = selectedWalletSettings.value else {
            return
        }

        assetBalanceIdMapping = changes.reduce(into: assetBalanceIdMapping) { result, change in
            switch change {
            case let .insert(chain), let .update(chain):
                guard let accountId = selectedMetaAccount.fetch(
                    for: chain.accountRequest()
                )?.accountId else {
                    return
                }

                for asset in chain.assets {
                    let assetBalanceRawId = AssetBalance.createIdentifier(
                        for: ChainAssetId(chainId: chain.chainId, assetId: asset.assetId),
                        accountId: accountId
                    )

                    if result[assetBalanceRawId] == nil {
                        result[assetBalanceRawId] = AssetBalanceId(
                            chainId: chain.chainId,
                            assetId: asset.assetId,
                            accountId: accountId
                        )
                    }
                }
            case let .delete(deletedIdentifier):
                result = result.filter { $0.value.chainId != deletedIdentifier }
            }
        }

        assetBalanceSubscriptions = changes.reduce(
            intitial: assetBalanceSubscriptions,
            selectedMetaAccount: selectedMetaAccount
        ) { [weak self] in
            self?.subscribeToAccountBalanceProvider(for: $0)
        }

        assetLocksSubscriptions = changes.reduce(
            intitial: assetLocksSubscriptions,
            selectedMetaAccount: selectedMetaAccount
        ) { [weak self] in
            self?.subscribeToAllLocksProvider(for: $0)
        }
    }

    func updatePriceSubscription(from changes: [DataProviderChange<ChainModel>]) {
        let prevPrices = availableTokenPrice
        for change in changes {
            switch change {
            case let .insert(chain), let .update(chain):
                availableTokenPrice = availableTokenPrice.filter { $0.key.chainId != chain.chainId }

                availableTokenPrice = chain.assets.reduce(into: availableTokenPrice) { result, asset in
                    guard let priceId = asset.priceId else {
                        return
                    }

                    let chainAssetId = ChainAssetId(chainId: chain.chainId, assetId: asset.assetId)
                    result[chainAssetId] = priceId
                }
            case let .delete(deletedIdentifier):
                availableTokenPrice = availableTokenPrice.filter { $0.key.chainId != deletedIdentifier }
            }
        }

        if prevPrices != availableTokenPrice {
            updatePriceProvider(for: Set(availableTokenPrice.values), currency: selectedCurrency)
        }
    }

    private func updatePriceProvider(
        for priceIdSet: Set<AssetModel.PriceId>,
        currency: Currency
    ) {
        priceSubscription = nil

        let priceIds = Array(priceIdSet).sorted()

        guard !priceIds.isEmpty else {
            return
        }

        priceSubscription = priceLocalSubscriptionFactory.getPriceListProvider(
            for: priceIds,
            currency: currency
        )

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

                self?.basePresenter?.didReceivePrices(result: .success(chainPrices))
            case .none:
                self?.basePresenter?.didReceivePrices(result: nil)
            }
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.basePresenter?.didReceivePrices(result: .failure(error))
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

    func subscribeChains() {
        chainRegistry.chainsSubscribe(self, runningInQueue: .main) { [weak self] changes in
            self?.handle(changes: changes)
        }
    }

    func setup() {
        subscribeChains()
    }
}

extension AssetListBaseInteractor: AssetListBaseInteractorInputProtocol {}

extension AssetListBaseInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    private func handleAccountBalanceError(_ error: Error, accountId: AccountId) {
        let results = assetBalanceIdMapping.values.reduce(
            into: [ChainAssetId: Result<CalculatedAssetBalance?, Error>]()
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

        basePresenter?.didReceiveBalance(results: results)
    }

    func handleAccountLocks(result: Result<[DataProviderChange<AssetLock>], Error>, accountId _: AccountId) {
        switch result {
        case let .failure(error):
            basePresenter?.didReceiveLocks(result: .failure(error))
        case let .success(changes):
            var locks: [AssetLock] = []
            changes.forEach {
                switch $0 {
                case let .insert(newItem), let .update(newItem):
                    guard let index = locks.firstIndex(where: { $0.identifier == newItem.identifier }) else {
                        locks.append(newItem)
                        return
                    }
                    locks[index] = newItem
                case let .delete(deletedIdentifier):
                    locks.removeAll(where: { $0.identifier == deletedIdentifier })
                }
            }
            basePresenter?.didReceiveLocks(result: .success(locks))
        }
    }

    private func handleAccountBalanceChanges(
        _ changes: [DataProviderChange<AssetBalance>],
        accountId: AccountId
    ) {
        // prepopulate non existing balances with zeros
        let initialItems = assetBalanceIdMapping.values.reduce(
            into: [ChainAssetId: Result<CalculatedAssetBalance?, Error>]()
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

                accum[chainAssetId] = .success(.init(balance: balance, total: balance.totalInPlank))
            case let .delete(deletedIdentifier):
                guard let assetBalanceId = assetBalanceIdMapping[deletedIdentifier] else {
                    return
                }

                let chainAssetId = ChainAssetId(
                    chainId: assetBalanceId.chainId,
                    assetId: assetBalanceId.assetId
                )

                accum[chainAssetId] = .success(.init(total: 0))
            }
        }

        basePresenter?.didReceiveBalance(results: results)
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

extension AssetListBaseInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard basePresenter != nil else {
            return
        }

        updatePriceProvider(for: Set(availableTokenPrice.values), currency: selectedCurrency)
    }
}

extension Array where Element == DataProviderChange<ChainModel> {
    func reduce<Value>(
        intitial: [AccountId: StreamableProvider<Value>],
        selectedMetaAccount: MetaAccountModel,
        subscription: @escaping (AccountId) -> StreamableProvider<Value>?
    ) -> [AccountId: StreamableProvider<Value>] {
        reduce(into: intitial) { result, change in
            switch change {
            case let .insert(chain), let .update(chain):
                guard let accountId = selectedMetaAccount.fetch(
                    for: chain.accountRequest()
                )?.accountId else {
                    return
                }

                if result[accountId] == nil {
                    result[accountId] = subscription(accountId)
                }
            case .delete:
                break
            }
        }
    }
}

struct CalculatedAssetBalance {
    var balance: AssetBalance?
    var total: BigUInt
}
