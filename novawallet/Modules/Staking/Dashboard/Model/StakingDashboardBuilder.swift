import Foundation
import RobinHood

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

    private func deriveOnchainSync(for stakingOption: Multistaking.ChainAssetOption) -> Bool {
        let account = wallet?.fetch(for: stakingOption.chainAsset.chain.accountRequest())

        if account == nil {
            // don't need onchain sync if no account
            return false
        } else {
            return syncState?.isOnchainSyncing[stakingOption.option] ?? true
        }
    }

    private func deriveOffchainSync() -> Bool {
        syncState?.isOffchainSyncing ?? true
    }

    private func buildDashboardItem(for stakingOption: Multistaking.ChainAssetOption) -> StakingDashboardItemModel {
        let account = wallet?.fetch(for: stakingOption.chainAsset.chain.accountRequest())

        let priceData = stakingOption.chainAsset.asset.priceId.flatMap { prices[$0] }

        let isOnchainSyncing = deriveOnchainSync(for: stakingOption)
        let isOffchainSyncing = deriveOffchainSync()

        return StakingDashboardItemModel(
            stakingOption: stakingOption,
            dashboardItem: dashboardItems[stakingOption.option],
            accountId: account?.accountId,
            balance: balances[stakingOption.chainAsset.chainAssetId],
            price: priceData,
            isOnchainSync: isOnchainSyncing,
            isOffchainSync: isOffchainSyncing
        )
    }

    private func rebuildModel() {
        let dashboardItems = chainAssets.flatMap { chainAsset in
            let chainStakings = chainAsset.asset.supportedStakings ?? []

            let dashboardItems: [StakingDashboardItemModel] = chainStakings.map { staking in
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
         * - there is no inactive staking for the asset
         * - the asset is not in the testnet
         *
         * Otherwise staking goes to the More Options
         */

        var inactiveStakingAssets: Set<ChainAssetId> = Set()
        var inactiveStakings: [Multistaking.Option: StakingDashboardItemModel] = [:]
        var moreOptions: [StakingDashboardItemModel] = []

        allInactiveStakings.forEach { dashboardItem in
            let stakingOption = dashboardItem.stakingOption.option
            let chain = dashboardItem.stakingOption.chainAsset.chain

            if
                activeStakingAssets.contains(stakingOption.chainAssetId) ||
                inactiveStakingAssets.contains(stakingOption.chainAssetId) ||
                chain.isTestnet {
                moreOptions.append(dashboardItem)
            } else {
                inactiveStakings[stakingOption] = dashboardItem
                inactiveStakingAssets.insert(stakingOption.chainAssetId)
            }
        }

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

    private func updateSync(
        for items: [StakingDashboardItemModel],
        syncChange: Set<Multistaking.ChainAssetOption>
    ) -> [StakingDashboardItemModel] {
        let newOffchainSync = deriveOffchainSync()

        return items.map { item in
            guard syncChange.contains(item.stakingOption) else {
                return item
            }

            let newOnchainSync = deriveOnchainSync(for: item.stakingOption)

            return item.byChangingSyncState(isOnchainSync: newOnchainSync, isOffchainSync: newOffchainSync)
        }
    }

    private func updateModelAfterSyncChange() {
        guard let currentModel = currentModel else {
            return
        }

        let newOffchainSync = deriveOffchainSync()

        let syncChange: Set<Multistaking.ChainAssetOption> = currentModel.all.reduce(into: Set()) { state, item in
            if item.isOffchainSync != newOffchainSync {
                state.insert(item.stakingOption)
                return
            }

            let newOnchainSync = deriveOnchainSync(for: item.stakingOption)

            if item.isOnchainSync != newOnchainSync {
                state.insert(item.stakingOption)
            }
        }

        let newActive = updateSync(for: currentModel.active, syncChange: syncChange)
        let newInactive = updateSync(for: currentModel.inactive, syncChange: syncChange)
        let newMoreOptions = updateSync(for: currentModel.more, syncChange: syncChange)

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
                self?.updateModelAfterSyncChange()
            }
        }
    }
}
