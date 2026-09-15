import Foundation
import Operation_iOS
import SubstrateSdk
import Keystore_iOS
import BigInt

class AssetListBaseInteractor: WalletLocalStorageSubscriber,
    WalletLocalSubscriptionHandler,
    AnyProviderAutoCleaning {
    var baseBuilder: AssetListBaseBuilder?

    let selectedWalletSettings: SelectedWalletSettings
    let chainRegistry: ChainRegistryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let externalBalancesSubscriptionFactory: ExternalBalanceLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let assetVisibilitySubscriptionFactory: AssetVisibilityLocalSubscriptionFactoryProtocol
    let defaultAssetsProvider: DefaultAssetsProviding
    let operationQueue: OperationQueue
    let logger: LoggerProtocol?

    private(set) var assetBalanceSubscriptions: [AccountId: StreamableProvider<AssetBalance>] = [:]
    private(set) var assetBalanceIdMapping: [String: AssetBalanceId] = [:]

    private var externalBalancesSubscriptions: [ChainAssetId: StreamableProvider<ExternalAssetBalance>] = [:]
    private var externalBalances: [ChainAssetId: [ExternalAssetBalance]] = [:]
    private var externalBalancesChainAssetIds = Set<ChainAssetId>()

    private(set) var priceSubscription: StreamableProvider<PriceData>?
    private(set) var availableTokenPrice: [ChainAssetId: AssetModel.PriceId] = [:]
    private(set) var availableChains: [ChainModel.Id: ChainModel] = [:]
    private(set) var enabledChains: [ChainModel.Id: ChainModel] = [:]
    private(set) var accountChains: [ChainModel.Id: ChainModel] = [:]
    private(set) var visibility: AssetVisibility?

    private var visibilitySubscription: StreamableProvider<AssetVisibilityLocal>?
    private var visibilityRows: [String: AssetVisibilityLocal]?
    private var visibilitySubscriptionFailed = false
    private var defaultAssets: DefaultAssetsList?
    private var pendingChainChanges: [DataProviderChange<ChainModel>] = []

    init(
        selectedWalletSettings: SelectedWalletSettings,
        chainRegistry: ChainRegistryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        externalBalancesSubscriptionFactory: ExternalBalanceLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        assetVisibilitySubscriptionFactory: AssetVisibilityLocalSubscriptionFactoryProtocol,
        defaultAssetsProvider: DefaultAssetsProviding,
        operationQueue: OperationQueue,
        currencyManager: CurrencyManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.selectedWalletSettings = selectedWalletSettings
        self.chainRegistry = chainRegistry
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.externalBalancesSubscriptionFactory = externalBalancesSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.assetVisibilitySubscriptionFactory = assetVisibilitySubscriptionFactory
        self.defaultAssetsProvider = defaultAssetsProvider
        self.operationQueue = operationQueue
        self.logger = logger
        self.currencyManager = currencyManager
    }

    func clearAccountSubscriptions() {
        assetBalanceSubscriptions.values.forEach { $0.removeObserver(self) }
        assetBalanceSubscriptions = [:]

        assetBalanceIdMapping = [:]
    }

    func clearExternalBalancesSubscription() {
        externalBalancesSubscriptions.values.forEach { $0.removeObserver(self) }
        externalBalancesSubscriptions = [:]
        externalBalances = [:]
        externalBalancesChainAssetIds = .init()
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

    private func convertToAssetVisibleChanges(
        _ changes: [DataProviderChange<ChainModel>],
        visibility: AssetVisibility
    ) -> [DataProviderChange<ChainModel>] {
        changes.compactMap { change in
            switch change {
            case let .insert(newItem), let .update(newItem):
                let exists = enabledChains[newItem.chainId] != nil

                let visibleAssets = newItem.assets.filter { asset in
                    visibility.isVisible(ChainAssetId(chainId: newItem.chainId, assetId: asset.assetId))
                }
                let updatedChain = newItem.byChanging(assets: Set(visibleAssets))
                let hasVisibleAssets = !visibleAssets.isEmpty

                if !exists, hasVisibleAssets {
                    return .insert(newItem: updatedChain)
                } else if exists, hasVisibleAssets {
                    return .update(newItem: updatedChain)
                } else if exists, !hasVisibleAssets {
                    return .delete(deletedIdentifier: updatedChain.chainId)
                } else {
                    return nil
                }

            case let .delete(deletedIdentifier):
                let exists = enabledChains[deletedIdentifier] != nil

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
        accountChains = accountDependentChanges.mergeToDict(accountChains)

        guard let visibility else {
            availableChains = changes.mergeToDict(availableChains)
            pendingChainChanges.append(contentsOf: changes)
            return
        }

        let visibleChanges = convertToAssetVisibleChanges(accountDependentChanges, visibility: visibility)

        baseBuilder?.applyChainModelChanges(visibleChanges)
        applyChanges(allChanges: changes, enabledChainChanges: visibleChanges)
        notifyHiddenAssets()
    }

    func applyChanges(
        allChanges: [DataProviderChange<ChainModel>],
        enabledChainChanges: [DataProviderChange<ChainModel>]
    ) {
        availableChains = allChanges.mergeToDict(availableChains)
        enabledChains = enabledChainChanges.mergeToDict(enabledChains)

        updateAssetBalanceSubscription()
        updatePriceSubscription(from: allChanges)
        updateExternalBalancesSubscription(from: Array(enabledChains.values))
    }

    func resetWallet() {
        clearAccountSubscriptions()
        clearExternalBalancesSubscription()
        clearVisibilitySubscription()

        accountChains = [:]

        guard let selectedMetaAccount = selectedWalletSettings.value else {
            return
        }

        let changes = availableChains.values.map { DataProviderChange.insert(newItem: $0) }

        pendingChainChanges = changes
        enabledChains = [:]
        availableChains = [:]

        let accountDependentChanges = convertToAccountDependentChanges(changes, selectedWallet: selectedMetaAccount)
        accountChains = accountDependentChanges.mergeToDict([:])

        didResetWallet(allChanges: changes, enabledChainChanges: [])

        subscribeVisibility()
    }

    func didResetWallet(
        allChanges: [DataProviderChange<ChainModel>],
        enabledChainChanges: [DataProviderChange<ChainModel>]
    ) {
        availableChains = allChanges.mergeToDict(availableChains)
        enabledChains = enabledChainChanges.mergeToDict(enabledChains)

        updateAssetBalanceSubscription()
        updateExternalBalancesSubscription(from: Array(enabledChains.values))
    }

    func updateAssetBalanceSubscription() {
        guard let selectedMetaAccount = selectedWalletSettings.value else {
            return
        }

        let previousMappingIds = Set(assetBalanceIdMapping.keys)

        assetBalanceIdMapping = accountChains.values.reduce(
            into: [String: AssetBalanceId]()
        ) { result, chain in
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

                result[assetBalanceRawId] = AssetBalanceId(
                    chainId: chain.chainId,
                    assetId: asset.assetId,
                    accountId: accountId
                )
            }
        }

        let addedMappingKeys = Set(assetBalanceIdMapping.keys).subtracting(previousMappingIds)

        for addedKey in addedMappingKeys {
            if let accountId = assetBalanceIdMapping[addedKey]?.accountId {
                assetBalanceSubscriptions[accountId] = nil
            }
        }

        assetBalanceSubscriptions = accountChains.values
            .map { DataProviderChange.update(newItem: $0) }
            .reduce(
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
                    let chainAssetId = ChainAssetId(chainId: chain.chainId, assetId: asset.assetId)
                    result[chainAssetId] = asset.priceId
                }
            case let .delete(deletedIdentifier):
                availableTokenPrice = availableTokenPrice.filter { $0.key.chainId != deletedIdentifier }
            }
        }

        if prevPrices != availableTokenPrice {
            removeNotExistingPriceIds(from: Set(availableTokenPrice.keys))
            updatePriceProvider(currency: selectedCurrency)
        }
    }

    func handlePriceChanges(_ result: Result<[ChainAssetId: DataProviderChange<PriceData>], Error>) {
        switch result {
        case let .success(changes):
            baseBuilder?.applyPriceChanges(changes)
        case let .failure(error):
            baseBuilder?.applyPrice(error: error)
        }
    }

    private func removeNotExistingPriceIds(from chainAssetIds: Set<ChainAssetId>) {
        baseBuilder?.applyRemovedPriceChainAssets(chainAssetIds)
    }

    private func updatePriceProvider(currency: Currency) {
        clear(streamableProvider: &priceSubscription)
        priceSubscription = subscribeAllPrices(currency: currency)
    }

    func updateExternalBalancesSubscription(from allChains: [ChainModel]) {
        guard let selectedMetaAccount = selectedWalletSettings.value else {
            return
        }

        let chainAssets = allChains.flatMap { $0.chainAssetsWithExternalBalances() }
        let newChainAssetIds = Set(chainAssets.map(\.chainAssetId))

        guard !chainAssets.isEmpty, externalBalancesChainAssetIds != newChainAssetIds else {
            return
        }

        clearExternalBalancesSubscription()
        externalBalancesChainAssetIds = newChainAssetIds

        chainAssets.forEach { chainAsset in
            let request = chainAsset.chain.accountRequest()

            guard let accountId = selectedMetaAccount.fetch(for: request)?.accountId else {
                return
            }

            externalBalancesSubscriptions[chainAsset.chainAssetId] = subscribeToExternalAssetBalancesProvider(
                for: accountId,
                chainAsset: chainAsset
            )
        }
    }

    func subscribeChains() {
        chainRegistry.chainsSubscribe(
            self, runningInQueue: .main,
            filterStrategy: .enabledChains
        ) { [weak self] changes in
            self?.handle(changes: changes)
        }
    }

    func setup() {
        subscribeChains()
        fetchDefaultAssets()
        subscribeVisibility()
    }

    func getFullChain(for chainId: ChainModel.Id) -> ChainModel? {
        availableChains[chainId]
    }

    func didResolveVisibility(hasHiddenAssets _: Bool) {}

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

    func handleAccountHolds(result _: Result<[DataProviderChange<AssetHold>], Error>, accountId _: AccountId) {}
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

        baseBuilder?.applyBalances(results)
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

        baseBuilder?.applyBalances(results)
    }
}

// MARK: Private

private extension AssetListBaseInteractor {
    func fetchDefaultAssets() {
        let wrapper: CompoundOperationWrapper<DefaultAssetsList>

        if let cached = defaultAssetsProvider.cachedDefaultAssets {
            apply(defaultAssets: cached)
            wrapper = defaultAssetsProvider.createRefreshDefaultAssetsWrapper()
        } else {
            wrapper = defaultAssetsProvider.createDefaultAssetsWrapper()
        }

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(list):
                self?.apply(defaultAssets: list)
            case let .failure(error):
                self?.logger?.error("Default assets are unavailable: \(error)")
                self?.apply(defaultAssets: self?.defaultAssets ?? .empty)
            }
        }
    }

    func apply(defaultAssets list: DefaultAssetsList) {
        guard defaultAssets != list else {
            return
        }

        defaultAssets = list

        baseBuilder?.applyDefaultAssets(list)

        resolveVisibilityIfPossible()
    }

    func subscribeVisibility() {
        clearVisibilitySubscription()

        guard let metaId = selectedWalletSettings.value?.metaId else {
            return
        }

        visibilitySubscription = subscribeToAssetVisibilityProvider(for: metaId)
    }

    func clearVisibilitySubscription() {
        clear(streamableProvider: &visibilitySubscription)

        visibilityRows = nil
        visibilitySubscriptionFailed = false
        visibility = nil
    }

    func resolveVisibilityIfPossible() {
        if visibilitySubscriptionFailed {
            visibility = AssetVisibility(defaults: .empty, rows: [:])
        } else {
            guard let defaultAssets = defaultAssets ?? visibility?.defaults, let visibilityRows else {
                return
            }

            let rows = visibilityRows.values.reduce(into: [ChainAssetId: AssetVisibilityState]()) { accum, row in
                accum[row.chainAssetId] = row.state
            }

            visibility = AssetVisibility(defaults: defaultAssets, rows: rows)
        }

        let bufferedChanges = pendingChainChanges
        pendingChainChanges = []

        if !bufferedChanges.isEmpty {
            applyChanges(allChanges: bufferedChanges, enabledChainChanges: [])
        }

        reapplyVisibility()
    }

    func reapplyVisibility() {
        guard let visibility else {
            return
        }

        let changes = accountChains.values.map { DataProviderChange.update(newItem: $0) }
        let visibleChanges = convertToAssetVisibleChanges(changes, visibility: visibility)

        baseBuilder?.applyChainModelChanges(visibleChanges)
        applyChanges(allChanges: [], enabledChainChanges: visibleChanges)
        notifyHiddenAssets()
    }

    func notifyHiddenAssets() {
        guard let visibility else {
            return
        }

        let hasHiddenAssets = accountChains.values.contains { chain in
            chain.assets.contains { asset in
                !visibility.isVisible(ChainAssetId(chainId: chain.chainId, assetId: asset.assetId))
            }
        }

        didResolveVisibility(hasHiddenAssets: hasHiddenAssets)
    }
}

// MARK: AssetVisibilityLocalStorageSubscriber

extension AssetListBaseInteractor: AssetVisibilityLocalStorageSubscriber, AssetVisibilitySubscriptionHandler {
    func handleAssetVisibility(
        result: Result<[DataProviderChange<AssetVisibilityLocal>], Error>,
        metaId: MetaAccountModel.Id
    ) {
        guard metaId == selectedWalletSettings.value?.metaId else {
            return
        }

        switch result {
        case let .success(changes):
            visibilitySubscriptionFailed = false
            visibilityRows = changes.mergeToDict(visibilityRows ?? [:])
            resolveVisibilityIfPossible()
        case let .failure(error):
            logger?.error("Can't observe asset visibility: \(error)")
            visibilitySubscriptionFailed = true
            resolveVisibilityIfPossible()
        }
    }
}

extension AssetListBaseInteractor: ExternalAssetBalanceSubscriptionHandler, ExternalAssetBalanceSubscriber {
    func handleExternalAssetBalances(
        result: Result<[DataProviderChange<ExternalAssetBalance>], Error>,
        accountId: AccountId,
        chainAsset: ChainAsset
    ) {
        guard let selectedMetaAccount = selectedWalletSettings.value else {
            return
        }
        guard let chainAccountId = selectedMetaAccount.fetch(
            for: chainAsset.chain.accountRequest()
        )?.accountId, chainAccountId == accountId else {
            logger?.warning(
                "Missing account for chain: \(chainAsset.chain.name)"
            )
            return
        }

        switch result {
        case let .failure(error):
            baseBuilder?.applyExternalBalances(.failure(error))
        case let .success(changes):
            externalBalances = changes.reduce(
                into: externalBalances
            ) { result, change in
                switch change {
                case let .insert(externalBalance), let .update(externalBalance):
                    var items = result[chainAsset.chainAssetId] ?? []
                    items.addOrReplaceSingle(externalBalance)
                    result[chainAsset.chainAssetId] = items
                case let .delete(deletedIdentifier):
                    result[chainAsset.chainAssetId]?.removeAll(where: { $0.identifier == deletedIdentifier })
                }
            }

            baseBuilder?.applyExternalBalances(.success(externalBalances))
        }
    }
}

extension AssetListBaseInteractor: PriceLocalSubscriptionHandler, PriceLocalStorageSubscriber {
    func handleAllPrices(result: Result<[Operation_iOS.DataProviderChange<PriceData>], any Error>) {
        switch result {
        case let .success(changes):
            let mappedChanges = changes.reduce(
                using: .init(),
                availableTokenPrice: availableTokenPrice,
                currency: selectedCurrency
            )

            handlePriceChanges(.success(mappedChanges))
        case let .failure(error):
            handlePriceChanges(.failure(error))
        }
    }
}

extension AssetListBaseInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard baseBuilder != nil else {
            return
        }

        updatePriceProvider(currency: selectedCurrency)
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
