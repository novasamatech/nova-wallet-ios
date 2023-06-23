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

    var all: [StakingDashboardItemModel] {
        active + inactive + more
    }
}

extension Array where Element == StakingDashboardItemModel {
    static var totalStakeOrder: [ChainModel.Id: Int] {
        [
            KnowChainId.polkadot: 0,
            KnowChainId.kusama: 1,
            KnowChainId.alephZero: 2,
            KnowChainId.moonbeam: 3,
            KnowChainId.moonriver: 4,
            KnowChainId.ternoa: 5,
            KnowChainId.polkadex: 6,
            KnowChainId.calamari: 7,
            KnowChainId.zeitgeist: 8
        ]
    }

    func sortedByStake() -> [StakingDashboardItemModel] {
        sorted { item1, item2 in
            CompoundComparator.compare(list: [{
                let stake1 = item1.stakeValue()
                let stake2 = item2.stakeValue()

                return CompoundComparator.compare(item1: stake1, item2: stake2, isAsc: false)
            }, {
                let chain1 = item1.stakingOption.chainAsset.chain
                let chain2 = item2.stakingOption.chainAsset.chain

                return ChainModelCompator.priorityAndTestnetComparator(chain1: chain1, chain2: chain2)
            }, {
                let chain1 = item1.stakingOption.chainAsset.chain
                let chain2 = item2.stakingOption.chainAsset.chain

                return chain1.name.localizedCaseInsensitiveCompare(chain2.name)
            }])
        }
    }

    func sortedByBalance() -> [StakingDashboardItemModel] {
        sorted { item1, item2 in
            CompoundComparator.compare(list: [{
                let chain1 = item1.stakingOption.chainAsset.chain
                let chain2 = item2.stakingOption.chainAsset.chain

                return ChainModelCompator.priorityAndTestnetComparator(chain1: chain1, chain2: chain2)
            }, {
                let balance1 = item1.balanceValue()
                let balance2 = item2.balanceValue()

                return CompoundComparator.compare(item1: balance1, item2: balance2, isAsc: false)
            }, {
                let hasBalance1 = item1.balance != nil ? 0 : 1
                let hasBalance2 = item2.balance != nil ? 0 : 1

                return CompoundComparator.compare(item1: hasBalance1, item2: hasBalance2, isAsc: true)
            }, {
                let chain1 = item1.stakingOption.chainAsset.chain
                let chain2 = item2.stakingOption.chainAsset.chain

                let totalStaked1 = Self.totalStakeOrder[chain1.chainId] ?? Int.max
                let totalStaked2 = Self.totalStakeOrder[chain2.chainId] ?? Int.max

                return CompoundComparator.compare(item1: totalStaked1, item2: totalStaked2, isAsc: true)
            }, {
                let chain1 = item1.stakingOption.chainAsset.chain
                let chain2 = item2.stakingOption.chainAsset.chain

                return chain1.name.localizedCaseInsensitiveCompare(chain2.name)
            }])
        }
    }
}

extension StakingDashboardItemModel {
    func byChangingSyncState(isOnchainSync: Bool, isOffchainSync: Bool) -> StakingDashboardItemModel {
        StakingDashboardItemModel(
            stakingOption: stakingOption,
            dashboardItem: dashboardItem,
            accountId: accountId,
            balance: balance,
            price: price,
            isOnchainSync: isOnchainSync,
            isOffchainSync: isOffchainSync
        )
    }
}
