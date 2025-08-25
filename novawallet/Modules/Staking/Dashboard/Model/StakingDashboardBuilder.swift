import Foundation
import Operation_iOS
import BigInt

final class StakingDashboardBuilder {
    let workingQueue: DispatchQueue
    let callbackQueue: DispatchQueue
    let resultClosure: (StakingDashboardBuilderResult) -> Void

    private var chainAssets: Set<ChainAsset> = []
    private var dashboardItems: [Multistaking.Option: Multistaking.DashboardItem] = [:]
    private var balances: [ChainAssetId: AssetBalance] = [:]
    private var prices: [AssetModel.PriceId: PriceData] = [:]
    private var wallet: MetaAccountModel?
    private var syncState: MultistakingSyncState?
    private var chainAssetSyncState: [ChainAssetId: Bool]?
    private var currentModel: StakingDashboardModel?

    init(
        workingQueue: DispatchQueue = .init(label: "com.nova.wallet.staking.dashboard", qos: .userInteractive),
        callbackQueue: DispatchQueue = .main,
        resultClosure: @escaping (StakingDashboardBuilderResult) -> Void
    ) {
        self.workingQueue = workingQueue
        self.callbackQueue = callbackQueue
        self.resultClosure = resultClosure
    }

    private func getAvailableBalance(for stakingType: StakingType?, chainAssetId: ChainAssetId) -> BigUInt? {
        let optAssetBalance = balances[chainAssetId]
        return optAssetBalance.flatMap { assetBalance in
            StakingTypeBalanceFactory(stakingType: stakingType).getAvailableBalance(from: assetBalance)
        }
    }

    private func reindexChainAssetSyncState() {
        chainAssetSyncState = syncState?.isOnchainSyncing.reduce(into: [ChainAssetId: Bool]()) { accum, keyValue in
            let option = keyValue.key
            let isSyncing = keyValue.value

            accum[option.chainAssetId] = (accum[option.chainAssetId] ?? false) || isSyncing
        }
    }

    private func deriveOnchainSync(for stakingOption: Multistaking.ChainAssetOption) -> Bool {
        let account = wallet?.fetch(for: stakingOption.chainAsset.chain.accountRequest())

        if account == nil {
            // don't need onchain sync if no account
            return false
        } else {
            return syncState?.isOnchainSyncing[stakingOption.option] ?? true
        }
    }

    private func deriveOnchainSync(for chainAsset: ChainAsset) -> Bool {
        let account = wallet?.fetch(for: chainAsset.chain.accountRequest())

        if account == nil {
            // don't need onchain sync if no account
            return false
        } else {
            return chainAssetSyncState?[chainAsset.chainAssetId] ?? true
        }
    }

    private func deriveOffchainSync() -> Bool {
        syncState?.isOffchainSyncing ?? true
    }

    private func buildDashboardItem(
        for stakingOption: Multistaking.ChainAssetOption
    ) -> StakingDashboardItemModel.Concrete {
        let account = wallet?.fetch(for: stakingOption.chainAsset.chain.accountRequest())

        let priceData = stakingOption.chainAsset.asset.priceId.flatMap { prices[$0] }

        let isOnchainSyncing = deriveOnchainSync(for: stakingOption)
        let isOffchainSyncing = deriveOffchainSync()

        let availableBalance = getAvailableBalance(
            for: stakingOption.type,
            chainAssetId: stakingOption.chainAsset.chainAssetId
        )

        return .init(
            stakingOption: stakingOption,
            dashboardItem: dashboardItems[stakingOption.option],
            accountId: account?.accountId,
            availableBalance: availableBalance,
            price: priceData,
            isOnchainSync: isOnchainSyncing,
            isOffchainSync: isOffchainSyncing
        )
    }

    private func updateCombined(
        store: inout [ChainAssetId: StakingDashboardItemModel.Combined],
        item: StakingDashboardItemModel.Concrete
    ) {
        let chainAssetId = item.stakingOption.chainAsset.chainAssetId

        var currentValue = store[chainAssetId] ??
            StakingDashboardItemModel.Combined(
                concrete: item,
                availableBalance: getAvailableBalance(
                    for: nil,
                    chainAssetId: item.stakingOption.chainAsset.chainAssetId
                )
            )

        currentValue = currentValue
            .byChangingSyncState(
                isOnchainSync: currentValue.isOnchainSync || item.isOnchainSync,
                isOffchainSync: currentValue.isOffchainSync || item.isOffchainSync
            )
            .replacingWithGreatestApy(for: item.maxApy)

        store[chainAssetId] = currentValue
    }

    private func rebuildModel() {
        let dashboardItems = chainAssets.flatMap { chainAsset in
            let chainStakings = chainAsset.asset.supportedStakings ?? []

            let dashboardItems: [StakingDashboardItemModel.Concrete] = chainStakings.map { staking in
                let stakingOption = Multistaking.ChainAssetOption(chainAsset: chainAsset, type: staking)
                return buildDashboardItem(for: stakingOption)
            }

            return dashboardItems
        }

        // separate active stakings

        let activeStakings = dashboardItems.filter { $0.hasStaking }
        let activeStakingAssets = Set(activeStakings.map(\.stakingOption.chainAsset.chainAssetId))

        let allInactiveStakings = dashboardItems
            .filter { !$0.hasStaking }
            .sorted { item1, item2 in
                item1.stakingOption.type.isMorePreferred(than: item2.stakingOption.type)
            }

        /**
         * We allow staking to be in inactive set if:
         * - there is no active staking for the asset
         * - the asset is not in the testnet
         *
         * Otherwise staking goes to the More Options
         */

        var inactiveStakings: [ChainAssetId: StakingDashboardItemModel.Combined] = [:]
        var moreOptionsConcrete: [StakingDashboardItemModel.Concrete] = []
        var moreOptionsCombined: [ChainAssetId: StakingDashboardItemModel.Combined] = [:]

        allInactiveStakings.forEach { dashboardItem in
            let stakingOption = dashboardItem.stakingOption.option
            let chain = dashboardItem.stakingOption.chainAsset.chain

            if activeStakingAssets.contains(stakingOption.chainAssetId) {
                moreOptionsConcrete.append(dashboardItem)
            } else if chain.isTestnet {
                updateCombined(store: &moreOptionsCombined, item: dashboardItem)
            } else {
                updateCombined(store: &inactiveStakings, item: dashboardItem)
            }
        }

        let moreOptions = moreOptionsConcrete.map { StakingDashboardItemModel.concrete($0) } +
            moreOptionsCombined.values.map { StakingDashboardItemModel.combined($0) }

        let model = StakingDashboardModel(
            active: activeStakings.sortedByStake(),
            inactive: Array(inactiveStakings.values).sortedByBalance(),
            more: moreOptions.sortedByBalance()
        )

        currentModel = model

        let result = StakingDashboardBuilderResult(
            walletId: wallet?.metaId,
            model: model,
            changeKind: .reload
        )

        callbackQueue.async { [weak self] in
            self?.resultClosure(result)
        }
    }

    private func createSyncChange(
        for currentModel: StakingDashboardModel,
        newOffchainSync: Bool
    ) -> StakingDashboardBuilderResult.SyncChange {
        let changeByChainAsset = currentModel.all.reduce(into: Set<ChainAsset>()) { accum, item in
            if newOffchainSync != item.isOffchainSync {
                accum.insert(item.chainAsset)
                return
            }

            let newOnchainSync = deriveOnchainSync(for: item.chainAsset)

            if newOnchainSync != item.isOnchainSync {
                accum.insert(item.chainAsset)
            }
        }

        let changeByChainOption = currentModel.allConcrete.reduce(
            into: Set<Multistaking.ChainAssetOption>()
        ) { accum, item in
            if newOffchainSync != item.isOffchainSync {
                accum.insert(item.stakingOption)
                return
            }

            let newOnchainSync = deriveOnchainSync(for: item.stakingOption)

            if newOnchainSync != item.isOnchainSync {
                accum.insert(item.stakingOption)
            }
        }

        return .init(byStakingOption: changeByChainOption, byStakingChainAsset: changeByChainAsset)
    }

    private func updateModelAfterSyncChange() {
        guard let currentModel = currentModel else {
            return
        }

        let newOffchainSync = deriveOffchainSync()

        let syncChange = createSyncChange(for: currentModel, newOffchainSync: newOffchainSync)

        let newActive = currentModel.active.map { item in
            item.byChangingSyncState(
                isOnchainSync: deriveOnchainSync(for: item.stakingOption),
                isOffchainSync: newOffchainSync
            )
        }

        let newInactive = currentModel.inactive.map { item in
            item.byChangingSyncState(
                isOnchainSync: deriveOnchainSync(for: item.chainAsset),
                isOffchainSync: newOffchainSync
            )
        }

        let newMoreOptions = currentModel.more.map { item in
            switch item {
            case let .concrete(concrete):
                let newConcrete = concrete.byChangingSyncState(
                    isOnchainSync: deriveOnchainSync(for: concrete.stakingOption),
                    isOffchainSync: newOffchainSync
                )

                return StakingDashboardItemModel.concrete(newConcrete)
            case let .combined(combined):
                let newCombined = combined.byChangingSyncState(
                    isOnchainSync: deriveOnchainSync(for: combined.chainAsset),
                    isOffchainSync: newOffchainSync
                )

                return StakingDashboardItemModel.combined(newCombined)
            }
        }

        let newModel = StakingDashboardModel(
            active: newActive,
            inactive: newInactive,
            more: newMoreOptions
        )

        self.currentModel = newModel
        let result = StakingDashboardBuilderResult(
            walletId: wallet?.metaId,
            model: newModel,
            changeKind: .sync(syncChange)
        )

        callbackQueue.async { [weak self] in
            self?.resultClosure(result)
        }
    }
}

extension StakingDashboardBuilder: StakingDashboardBuilderProtocol {
    func applyWallet(model: MetaAccountModel) {
        workingQueue.async { [weak self] in
            self?.wallet = model
            self?.dashboardItems = [:]
            self?.balances = [:]
            self?.syncState = nil
            self?.currentModel = nil
            self?.rebuildModel()
        }
    }

    func applyDashboardItem(changes: [DataProviderChange<Multistaking.DashboardItem>]) {
        workingQueue.async { [weak self] in
            guard let self = self else {
                return
            }

            var isModelChanged: Bool = false

            changes.forEach { change in
                switch change {
                case let .insert(newItem), let .update(newItem):
                    isModelChanged = isModelChanged || (self.dashboardItems[newItem.stakingOption.option] != newItem)

                    self.dashboardItems[newItem.stakingOption.option] = newItem
                case let .delete(deletedIdentifier):
                    isModelChanged = true
                    self.dashboardItems = self.dashboardItems.filter { $0.value.identifier != deletedIdentifier }
                }
            }

            if isModelChanged {
                self.rebuildModel()
            }
        }
    }

    func applyAssets(models: Set<ChainAsset>) {
        workingQueue.async { [weak self] in
            self?.chainAssets = models
            self?.rebuildModel()
        }
    }

    func applyBalance(model: AssetBalance?, chainAssetId: ChainAssetId) {
        workingQueue.async { [weak self] in
            if self?.balances[chainAssetId] != model {
                self?.balances[chainAssetId] = model
                self?.rebuildModel()
            }
        }
    }

    func applyPrice(model: PriceData?, priceId: AssetModel.PriceId) {
        workingQueue.async { [weak self] in
            if self?.prices[priceId] != model {
                self?.prices[priceId] = model
                self?.rebuildModel()
            }
        }
    }

    func applySync(state: MultistakingSyncState) {
        workingQueue.async { [weak self] in
            if self?.syncState != state {
                self?.syncState = state
                self?.reindexChainAssetSyncState()
                self?.updateModelAfterSyncChange()
            }
        }
    }
}
