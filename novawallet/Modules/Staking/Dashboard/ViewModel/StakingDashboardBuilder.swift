import Foundation
import RobinHood

final class StakingDashboardBuilder {
    let workingQueue: DispatchQueue
    let callbackQueue: DispatchQueue
    let resultClosure: (StakingDashboardModel) -> Void

    private var chainAssets: Set<ChainAsset> = []
    private var dashboardItems: [Multistaking.Option: Multistaking.DashboardItem] = [:]
    private var balances: [ChainAssetId: AssetBalance] = [:]
    private var prices: [AssetModel.PriceId: PriceData] = [:]
    private var wallet: MetaAccountModel?
    private var syncState: MultistakingSyncState?

    init(
        workingQueue: DispatchQueue = .init(label: "com.nova.wallet.staking.dashboard"),
        callbackQueue: DispatchQueue = .main,
        resultClosure: @escaping (StakingDashboardModel) -> Void
    ) {
        self.workingQueue = workingQueue
        self.callbackQueue = callbackQueue
        self.resultClosure = resultClosure
    }

    private func buildDashboardItem(for stakingOption: Multistaking.ChainAssetOption) -> StakingDashboardItemModel {
        let account = wallet?.fetch(for: stakingOption.chainAsset.chain.accountRequest())

        let priceData = stakingOption.chainAsset.asset.priceId.flatMap { prices[$0] }

        return StakingDashboardItemModel(
            stakingOption: stakingOption,
            dashboardItem: dashboardItems[stakingOption.option],
            accountId: account?.accountId,
            balance: balances[stakingOption.chainAsset.chainAssetId],
            price: priceData,
            isOnchainSync: syncState?.isOnchainSyncing[stakingOption.option] ?? true,
            isOffchainSync: syncState?.isOffchainSyncing ?? true
        )
    }

    private func buildModel() {
        let dashboardItems = chainAssets.flatMap { chainAsset in
            (chainAsset.asset.stakings ?? []).map { staking in
                let stakingOption = Multistaking.ChainAssetOption(chainAsset: chainAsset, type: staking)
                return buildDashboardItem(for: stakingOption)
            }
        }

        // separate active stakings

        let activeStakings = dashboardItems.filter { $0.hasStaking }
        let activeAssets = Set(activeStakings.map(\.stakingOption.chainAsset.chainAssetId))

        let allInactiveStakings = dashboardItems.filter { !$0.hasStaking }

        /**
         * We allow staking to be in inactive set if:
         * - there is no active staking for the asset
         * - there is no inactive staking for the asset
         * - the asset is not in the testnet
         *
         * Otherwise staking goes to the More Options
         */

        var inactiveStakings: [ChainAssetId: StakingDashboardItemModel] = [:]
        var moreOptions: [StakingDashboardItemModel] = []

        allInactiveStakings.forEach { dashboardItem in
            let chainAsset = dashboardItem.stakingOption.chainAsset
            let chainAssetId = chainAsset.chainAssetId

            if
                activeAssets.contains(chainAssetId) ||
                inactiveStakings[chainAssetId] != nil ||
                chainAsset.chain.isTestnet {
                moreOptions.append(dashboardItem)
            } else {
                inactiveStakings[chainAssetId] = dashboardItem
            }
        }

        let model = StakingDashboardModel(
            active: activeStakings.sortedByStaking(),
            inactive: Array(inactiveStakings.values).sortedByStaking(),
            more: moreOptions.sortedByStaking()
        )

        callbackQueue.async { [weak self] in
            self?.resultClosure(model)
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

            self?.buildModel()
        }
    }

    func applyDashboardItem(changes: [DataProviderChange<Multistaking.DashboardItem>]) {
        workingQueue.async { [weak self] in
            guard let self = self else {
                return
            }

            changes.forEach { change in
                switch change {
                case let .insert(newItem), let .update(newItem):
                    self.dashboardItems[newItem.stakingOption.option] = newItem
                case let .delete(deletedIdentifier):
                    self.dashboardItems = self.dashboardItems.filter { $0.value.identifier != deletedIdentifier }
                }
            }

            self.buildModel()
        }
    }

    func applyAssets(models: Set<ChainAsset>) {
        workingQueue.async { [weak self] in
            self?.chainAssets = models
            self?.buildModel()
        }
    }

    func applyBalance(model: AssetBalance?, chainAssetId: ChainAssetId) {
        workingQueue.async { [weak self] in
            self?.balances[chainAssetId] = model
            self?.buildModel()
        }
    }

    func applyPrice(model: PriceData?, priceId: AssetModel.PriceId) {
        workingQueue.async { [weak self] in
            self?.prices[priceId] = model
            self?.buildModel()
        }
    }

    func applySync(state: MultistakingSyncState) {
        workingQueue.async { [weak self] in
            self?.syncState = state
            self?.buildModel()
        }
    }
}
