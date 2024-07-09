import Foundation
import Operation_iOS
import SubstrateSdk
import SoraKeystore
import BigInt

class AssetListBaseInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    var baseBuilder: AssetListBaseBuilder?

    let selectedWalletSettings: SelectedWalletSettings
    let chainRegistry: ChainRegistryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let externalBalancesSubscriptionFactory: ExternalBalanceLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
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

    init(
        selectedWalletSettings: SelectedWalletSettings,
        chainRegistry: ChainRegistryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        externalBalancesSubscriptionFactory: ExternalBalanceLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.selectedWalletSettings = selectedWalletSettings
        self.chainRegistry = chainRegistry
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.externalBalancesSubscriptionFactory = externalBalancesSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.logger = logger
        self.currencyManager = currencyManager

        observeChainsSyncModeChanges(on: .main)
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

        baseBuilder?.applyChainModelChanges(assetDependentChanges)
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
        updateExternalBalancesSubscription(from: Array(enabledChains.values))
    }

    func resetWallet() {
        clearAccountSubscriptions()
        clearExternalBalancesSubscription()

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

        baseBuilder?.applyChainModelChanges(assetDependentChanges)

        didResetWallet(allChanges: changes, enabledChainChanges: assetDependentChanges)
    }

    func didResetWallet(
        allChanges: [DataProviderChange<ChainModel>],
        enabledChainChanges: [DataProviderChange<ChainModel>]
    ) {
        availableChains = allChanges.mergeToDict(availableChains)
        enabledChains = enabledChainChanges.mergeToDict(enabledChains)

        updateAssetBalanceSubscription(from: enabledChainChanges)
        updateExternalBalancesSubscription(from: Array(enabledChains.values))
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
                    let chainAssetId = ChainAssetId(chainId: chain.chainId, assetId: asset.assetId)
                    result[chainAssetId] = asset.priceId
                }
            case let .delete(deletedIdentifier):
                availableTokenPrice = availableTokenPrice.filter { $0.key.chainId != deletedIdentifier }
            }
        }

        if prevPrices != availableTokenPrice {
            removeNotExistingPriceIds(from: Set(availableTokenPrice.keys))
            updatePriceProvider(for: Set(availableTokenPrice.values), currency: selectedCurrency)
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

    private func updatePriceProvider(
        for priceIdSet: Set<AssetModel.PriceId>,
        currency: Currency
    ) {
        priceSubscription = nil

        let priceIds = Array(priceIdSet).sorted()

        guard !priceIds.isEmpty else {
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

            self?.handlePriceChanges(.success(mappedChanges))
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.handlePriceChanges(.failure(error))
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

extension AssetListBaseInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard baseBuilder != nil else {
            return
        }

        updatePriceProvider(for: Set(availableTokenPrice.values), currency: selectedCurrency)
    }
}

extension AssetListBaseInteractor: ChainSyncModeChangeProcessor {
    func handle(_ syncModeChange: DataProviderChange<ChainModel>) {
        handle(changes: [syncModeChange])
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
