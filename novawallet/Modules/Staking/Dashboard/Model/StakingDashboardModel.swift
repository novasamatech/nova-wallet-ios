import Foundation
import RobinHood

struct StakingDashboardItemModel {
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

    func balanceValue() -> Decimal {
        guard let balance = balance,
              let rate = price?.decimalRate else {
            return 0
        }

        let decimalBalance = Decimal.fromSubstrateAmount(
            balance.totalInPlank,
            precision: stakingOption.chainAsset.assetDisplayInfo.assetPrecision
        ) ?? 0

        return decimalBalance * rate
    }
}

struct StakingDashboardModel {
    let active: [StakingDashboardItemModel]
    let inactive: [StakingDashboardItemModel]
    let more: [StakingDashboardItemModel]
}

extension Array where Element == StakingDashboardItemModel {
    func sortedByStaking() -> [StakingDashboardItemModel] {
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
