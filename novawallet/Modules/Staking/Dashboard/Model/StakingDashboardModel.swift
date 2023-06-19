import Foundation
import RobinHood

struct StakingDashboardItemModel: Equatable {
    let stakingOption: Multistaking.ChainAssetOption
    let dashboardItem: Multistaking.DashboardItem?
    let accountId: AccountId?
    let balance: AssetBalance?
    let price: PriceData?
    let isOnchainSync: Bool
    let isOffchainSync: Bool

    var hasStaking: Bool {
        guard let dashboardItem = dashboardItem else {
            return false
        }

        return dashboardItem.stake != nil
    }

    var hasAnySync: Bool {
        isOnchainSync || isOffchainSync
    }

    func balanceValue() -> Decimal {
        Decimal.fiatValue(
            from: balance?.freeInPlank,
            price: price,
            precision: stakingOption.chainAsset.assetDisplayInfo.assetPrecision
        )
    }

    func stakeValue() -> Decimal {
        Decimal.fiatValue(
            from: dashboardItem?.stake,
            price: price,
            precision: stakingOption.chainAsset.assetDisplayInfo.assetPrecision
        )
    }
}

struct StakingDashboardModel: Equatable {
    let active: [StakingDashboardItemModel]
    let inactive: [StakingDashboardItemModel]
    let more: [StakingDashboardItemModel]

    init(
        active: [StakingDashboardItemModel] = [],
        inactive: [StakingDashboardItemModel] = [],
        more: [StakingDashboardItemModel] = []
    ) {
        self.active = active
        self.inactive = inactive
        self.more = more
    }

    var isEmpty: Bool {
        active.isEmpty && inactive.isEmpty && more.isEmpty
    }
}

extension Array where Element == StakingDashboardItemModel {
    func sortedByStake() -> [StakingDashboardItemModel] {
        sorted { item1, item2 in
            let stake1 = item1.stakeValue()
            let stake2 = item2.stakeValue()

            if stake1 > 0, stake2 > 0 {
                return stake1 > stake2
            } else if stake1 > 0 {
                return true
            } else if stake2 > 0 {
                return false
            } else {
                let chain1 = item1.stakingOption.chainAsset.chain
                let chain2 = item2.stakingOption.chainAsset.chain

                return chain1.name.lexicographicallyPrecedes(chain2.name)
            }
        }
    }

    func sortedByBalance() -> [StakingDashboardItemModel] {
        sorted { item1, item2 in
            let chain1 = item1.stakingOption.chainAsset.chain
            let chain2 = item2.stakingOption.chainAsset.chain

            let chainPriority1 = ChainModelCompator.chainPriority(for: chain1.chainId)
            let chainPriority2 = ChainModelCompator.chainPriority(for: chain2.chainId)

            guard chainPriority1 == chainPriority2 else {
                return chainPriority1 < chainPriority2
            }

            let balance1 = item1.balanceValue()
            let balance2 = item2.balanceValue()

            if balance1 > 0, balance2 > 0 {
                return balance1 > balance2
            } else if balance1 > 0 {
                return true
            } else if balance2 > 0 {
                return false
            } else {
                return chain1.name.lexicographicallyPrecedes(chain2.name)
            }
        }
    }
}
