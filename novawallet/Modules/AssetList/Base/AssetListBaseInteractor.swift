import Foundation
import RobinHood
import SubstrateSdk
import SoraKeystore
import BigInt

class AssetListBaseInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    weak var basePresenter: AssetListBaseInteractorOutputProtocol?

    let selectedWalletSettings: SelectedWalletSettings
    let chainRegistry: ChainRegistryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let crowdloansLocalSubscriptionFactory: CrowdloanContributionLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let logger: LoggerProtocol?

    private(set) var assetBalanceSubscriptions: [AccountId: StreamableProvider<AssetBalance>] = [:]
    private(set) var assetBalanceIdMapping: [String: AssetBalanceId] = [:]

    private var crowdloansSubscriptions: [ChainModel.Id: StreamableProvider<CrowdloanContributionData>] = [:]
    private var crowdloans: [ChainModel.Id: [CrowdloanContributionData]] = [:]
    private var crowdloanChainIds = Set<ChainModel.Id>()

    private(set) var priceSubscription: AnySingleValueProvider<[PriceData]>?
    private(set) var availableTokenPrice: [ChainAssetId: AssetModel.PriceId] = [:]
    private(set) var availableChains: [ChainModel.Id: ChainModel] = [:]
    private(set) var enabledChains: [ChainModel.Id: ChainModel] = [:]

    init(
        selectedWalletSettings: SelectedWalletSettings,
        chainRegistry: ChainRegistryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        crowdloansLocalSubscriptionFactory: CrowdloanContributionLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.selectedWalletSettings = selectedWalletSettings
        self.chainRegistry = chainRegistry
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.crowdloansLocalSubscriptionFactory = crowdloansLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.logger = logger
        self.currencyManager = currencyManager
    }

    func clearAccountSubscriptions() {
        assetBalanceSubscriptions.values.forEach { $0.removeObserver(self) }
        assetBalanceSubscriptions = [:]

        assetBalanceIdMapping = [:]
    }

    func clearCrowdloansSubscription() {
        crowdloansSubscriptions.values.forEach { $0.removeObserver(self) }
        crowdloansSubscriptions = [:]
        crowdloans = [:]
        crowdloanChainIds = .init()
    }

    private func convertToAccountDependentChanges(
        _ changes: [DataProviderChange<ChainModel>],
        selectedWallet: MetaAccountModel
    ) -> [DataProviderChange<ChainModel>] {
        changes.filter { change in
            switch change {
            case let .insert(newItem), let .update(newItem):
                return selectedWallet.fetch(for: newItem.accountRequest()) != nil ? true : false
            case .delete:
                return true
            }
        }
    }

    private func convertToAssetEnabledChanges(
        _ changes: [DataProviderChange<ChainModel>],
        allEnabledChains: [ChainModel.Id: ChainModel]
    ) -> [DataProviderChange<ChainModel>] {
        changes.compactMap { change in
            switch change {
            case let .insert(newItem), let .update(newItem):
                let exists = allEnabledChains[newItem.chainId] != nil

                let enabledAssets = newItem.assets.filter { $0.enabled }
                let updatedChain = newItem.byChanging(assets: Set(enabledAssets))
                let hasEnabledAssets = !enabledAssets.isEmpty

                if !exists, hasEnabledAssets {
                    return .insert(newItem: updatedChain)
                } else if exists, hasEnabledAssets {
                    return .update(newItem: updatedChain)
                } else if exists, !hasEnabledAssets {
                    return .delete(deletedIdentifier: updatedChain.chainId)
                } else {
                    return nil
                }

            case let .delete(deletedIdentifier):
                let exists = allEnabledChains[deletedIdentifier] != nil

                if exists {
                    return .delete(deletedIdentifier: deletedIdentifier)
                } else {
                    return nil
                }
            }
        }
    }

    private func handle(changes: [DataProviderChange<ChainModel>]) {
        guard let selectedMetaAccount = selectedWalletSettings.value else {
            return
        }

        let accountDependentChanges = convertToAccountDependentChanges(changes, selectedWallet: selectedMetaAccount)
        let assetDependentChanges = convertToAssetEnabledChanges(
            accountDependentChanges,
            allEnabledChains: enabledChains
        )

        basePresenter?.didReceiveChainModelChanges(assetDependentChanges)
        applyChanges(allChanges: changes, enabledChainChanges: assetDependentChanges)
    }

    func applyChanges(
        allChanges: [DataProviderChange<ChainModel>],
        enabledChainChanges: [DataProviderChange<ChainModel>]
    ) {
        availableChains = allChanges.mergeToDict(availableChains)
        enabledChains = enabledChainChanges.mergeToDict(enabledChains)

        updateAssetBalanceSubscription(from: enabledChainChanges)
        updatePriceSubscription(from: allChanges)
        updateCrowdloansSubscription(from: Array(enabledChains.values))
    }

    func resetWallet() {
        clearAccountSubscriptions()
        clearCrowdloansSubscription()

        guard let selectedMetaAccount = selectedWalletSettings.value else {
            return
        }

        let changes = availableChains.values.map { DataProviderChange.insert(newItem: $0) }

        enabledChains = [:]
        availableChains = [:]

        let accountDependentChanges = convertToAccountDependentChanges(changes, selectedWallet: selectedMetaAccount)
        let assetDependentChanges = convertToAssetEnabledChanges(
            accountDependentChanges,
            allEnabledChains: enabledChains
        )

        basePresenter?.didReceiveChainModelChanges(assetDependentChanges)

        didResetWallet(allChanges: changes, enabledChainChanges: assetDependentChanges)
    }

    func didResetWallet(
        allChanges: [DataProviderChange<ChainModel>],
        enabledChainChanges: [DataProviderChange<ChainModel>]
    ) {
        availableChains = allChanges.mergeToDict(availableChains)
        enabledChains = enabledChainChanges.mergeToDict(enabledChains)

        updateAssetBalanceSubscription(from: enabledChainChanges)
        updateCrowdloansSubscription(from: Array(enabledChains.values))
    }

    func updateAssetBalanceSubscription(from changes: [DataProviderChange<ChainModel>]) {
        guard let selectedMetaAccount = selectedWalletSettings.value else {
            return
        }

        let previousMappingIds = Set(assetBalanceIdMapping.keys)

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

        let newMappingKeys = Set(assetBalanceIdMapping.keys)

        for newKey in newMappingKeys {
            if !previousMappingIds.contains(newKey), let accountId = assetBalanceIdMapping[newKey]?.accountId {
                assetBalanceSubscriptions[accountId] = nil
            }
        }

        assetBalanceSubscriptions = changes.reduce(
            intitial: assetBalanceSubscriptions,
            selectedMetaAccount: selectedMetaAccount
        ) { [weak self] in
            self?.subscribeToAccountBalanceProvider(for: $0)
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

    func updateCrowdloansSubscription(from allChains: [ChainModel]) {
        guard let selectedMetaAccount = selectedWalletSettings.value else {
            return
        }

        let crowdloanChains = allChains.filter { $0.hasCrowdloans }
        let newCrowdloanChainIds = Set(crowdloanChains.map(\.chainId))

        guard !crowdloanChains.isEmpty, crowdloanChainIds != newCrowdloanChainIds else {
            return
        }

        clearCrowdloansSubscription()
        crowdloanChainIds = newCrowdloanChainIds

        crowdloanChains.forEach { chain in
            let request = chain.accountRequest()

            guard let accountId = selectedMetaAccount.fetch(for: request)?.accountId else {
                return
            }

            crowdloansSubscriptions[chain.identifier] = subscribeToCrowdloansProvider(for: accountId, chain: chain)
        }
    }

    func subscribeChains() {
        chainRegistry.chainsSubscribe(self, runningInQueue: .main) { [weak self] changes in
            self?.handle(changes: changes)
        }
    }

    func setup() {
        subscribeChains()
    }

    func getFullChain(for chainId: ChainModel.Id) -> ChainModel? {
        availableChains[chainId]
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

    func handleAccountLocks(result _: Result<[DataProviderChange<AssetLock>], Error>, accountId _: AccountId) {}
}

extension AssetListBaseInteractor {
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
}

extension AssetListBaseInteractor: CrowdloanContributionLocalSubscriptionHandler, CrowdloansLocalStorageSubscriber {
    func handleCrowdloans(
        result: Result<[DataProviderChange<CrowdloanContributionData>], Error>,
        accountId: AccountId,
        chain: ChainModel
    ) {
        guard let selectedMetaAccount = selectedWalletSettings.value else {
            return
        }
        guard let chainAccountId = selectedMetaAccount.fetch(
            for: chain.accountRequest()
        )?.accountId, chainAccountId == accountId else {
            logger?.warning(
                "Crowdloans updates can't be handled because account for selected wallet for chain: \(chain.name) is different"
            )
            return
        }

        switch result {
        case let .failure(error):
            basePresenter?.didReceiveCrowdloans(result: .failure(error))
        case let .success(changes):
            crowdloans = changes.reduce(
                into: crowdloans
            ) { result, change in
                switch change {
                case let .insert(crowdloan), let .update(crowdloan):
                    var items = result[chain.chainId] ?? []
                    items.addOrReplaceSingle(crowdloan)
                    result[chain.chainId] = items
                case let .delete(deletedIdentifier):
                    result[chain.chainId]?.removeAll(where: { $0.identifier == deletedIdentifier })
                }
            }

            basePresenter?.didReceiveCrowdloans(result: .success(crowdloans))
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
