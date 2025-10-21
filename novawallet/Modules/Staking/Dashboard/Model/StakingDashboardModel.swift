import Foundation
import Operation_iOS
import BigInt

protocol StakingDashboardItemModelCommonProtocol {
    var chainAsset: ChainAsset { get }
    var accountId: AccountId? { get }
    var availableBalance: BigUInt? { get }
    var price: PriceData? { get }
    var maxApy: Decimal? { get }
    var isOnchainSync: Bool { get }
    var isOffchainSync: Bool { get }
}

extension StakingDashboardItemModelCommonProtocol {
    var hasAnySync: Bool {
        isOnchainSync || isOffchainSync
    }

    func balanceValue() -> Decimal {
        Decimal.fiatValue(
            from: availableBalance,
            price: price,
            precision: chainAsset.assetDisplayInfo.assetPrecision
        )
    }
}

enum StakingDashboardItemModel: Equatable {
    struct Concrete: Equatable, StakingDashboardItemModelCommonProtocol {
        let stakingOption: Multistaking.ChainAssetOption
        let dashboardItem: Multistaking.DashboardItem?
        let accountId: AccountId?
        let availableBalance: BigUInt?
        let price: PriceData?
        let isOnchainSync: Bool
        let isOffchainSync: Bool

        var chainAsset: ChainAsset {
            stakingOption.chainAsset
        }

        var hasStaking: Bool {
            dashboardItem?.hasStaking ?? false
        }

        var maxApy: Decimal? {
            dashboardItem?.maxApy
        }

        func stakeValue() -> Decimal {
            Decimal.fiatValue(
                from: dashboardItem?.stake,
                price: price,
                precision: chainAsset.assetDisplayInfo.assetPrecision
            )
        }
    }

    struct Combined: Equatable, StakingDashboardItemModelCommonProtocol {
        let chainAsset: ChainAsset
        let maxApy: Decimal?
        let accountId: AccountId?
        let availableBalance: BigUInt?
        let price: PriceData?
        let isOnchainSync: Bool
        let isOffchainSync: Bool

        init(
            chainAsset: ChainAsset,
            maxApy: Decimal?,
            accountId: AccountId?,
            availableBalance: BigUInt?,
            price: PriceData?,
            isOnchainSync: Bool,
            isOffchainSync: Bool
        ) {
            self.chainAsset = chainAsset
            self.maxApy = maxApy
            self.accountId = accountId
            self.availableBalance = availableBalance
            self.price = price
            self.isOnchainSync = isOnchainSync
            self.isOffchainSync = isOffchainSync
        }

        init(concrete: Concrete, availableBalance: BigUInt?) {
            self.init(
                chainAsset: concrete.chainAsset,
                maxApy: concrete.dashboardItem?.maxApy,
                accountId: concrete.accountId,
                availableBalance: availableBalance,
                price: concrete.price,
                isOnchainSync: concrete.isOnchainSync,
                isOffchainSync: concrete.isOffchainSync
            )
        }

        func replacingWithGreatestApy(for newApy: Decimal?) -> Combined {
            let updatedApy: Decimal?

            if let maxApy = maxApy, let newApy = newApy {
                updatedApy = max(maxApy, newApy)
            } else {
                updatedApy = maxApy ?? newApy
            }

            return .init(
                chainAsset: chainAsset,
                maxApy: updatedApy,
                accountId: accountId,
                availableBalance: availableBalance,
                price: price,
                isOnchainSync: isOnchainSync,
                isOffchainSync: isOffchainSync
            )
        }
    }

    case concrete(Concrete)
    case combined(Combined)
}

struct StakingDashboardModel: Equatable {
    let active: [StakingDashboardItemModel.Concrete]
    let inactive: [StakingDashboardItemModel.Combined]
    let more: [StakingDashboardItemModel]

    init(
        active: [StakingDashboardItemModel.Concrete] = [],
        inactive: [StakingDashboardItemModel.Combined] = [],
        more: [StakingDashboardItemModel] = []
    ) {
        self.active = active
        self.inactive = inactive
        self.more = more
    }

    var isEmpty: Bool {
        active.isEmpty && inactive.isEmpty && more.isEmpty
    }

    var allConcrete: [StakingDashboardItemModel.Concrete] {
        let moreOptionsConcrete: [StakingDashboardItemModel.Concrete] = more.compactMap { item in
            switch item {
            case let .concrete(concrete):
                return concrete
            case .combined:
                return nil
            }
        }

        return active + moreOptionsConcrete
    }

    var all: [StakingDashboardItemModelCommonProtocol] {
        active + inactive + more
    }

    func getActiveCounters() -> [ChainAssetId: Int] {
        active.reduce(into: [ChainAssetId: Int]()) { accum, item in
            accum[item.chainAsset.chainAssetId] = (accum[item.chainAsset.chainAssetId] ?? 0) + 1
        }
    }
}

extension Array where Element: StakingDashboardItemModelCommonProtocol {
    static var totalStakeOrder: [ChainModel.Id: Int] {
        [
            KnowChainId.polkadotAssetHub: 0,
            KnowChainId.kusamaAssetHub: 1,
            KnowChainId.alephZero: 2,
            KnowChainId.moonbeam: 3,
            KnowChainId.moonriver: 4,
            KnowChainId.ternoa: 5,
            KnowChainId.polkadex: 6,
            KnowChainId.calamari: 7,
            KnowChainId.zeitgeist: 8
        ]
    }

    func sortedByBalance() -> [Element] {
        sorted { item1, item2 in
            CompoundComparator.compare(list: [{
                let chain1 = item1.chainAsset.chain
                let chain2 = item2.chainAsset.chain

                return ChainModelCompator.priorityAndTestnetComparator(chain1: chain1, chain2: chain2)
            }, {
                let balance1 = item1.balanceValue()
                let balance2 = item2.balanceValue()

                return CompoundComparator.compare(item1: balance1, item2: balance2, isAsc: false)
            }, {
                let hasBalance1 = item1.availableBalance != nil ? 0 : 1
                let hasBalance2 = item2.availableBalance != nil ? 0 : 1

                return CompoundComparator.compare(item1: hasBalance1, item2: hasBalance2, isAsc: true)
            }, {
                let chain1 = item1.chainAsset.chain
                let chain2 = item2.chainAsset.chain

                let totalStaked1 = Self.totalStakeOrder[chain1.chainId] ?? Int.max
                let totalStaked2 = Self.totalStakeOrder[chain2.chainId] ?? Int.max

                return CompoundComparator.compare(item1: totalStaked1, item2: totalStaked2, isAsc: true)
            }, {
                let chain1 = item1.chainAsset.chain
                let chain2 = item2.chainAsset.chain

                return chain1.name.localizedCaseInsensitiveCompare(chain2.name)
            }])
        }
    }
}

extension Array where Element == StakingDashboardItemModel.Concrete {
    func sortedByStake() -> [StakingDashboardItemModel.Concrete] {
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
            }, {
                let type1 = item1.stakingOption.type
                let type2 = item2.stakingOption.type

                return type1.isMorePreferred(than: type2) ? .orderedAscending : .orderedDescending
            }])
        }
    }
}

extension StakingDashboardItemModel.Combined {
    func byChangingSyncState(isOnchainSync: Bool, isOffchainSync: Bool) -> StakingDashboardItemModel.Combined {
        StakingDashboardItemModel.Combined(
            chainAsset: chainAsset,
            maxApy: maxApy,
            accountId: accountId,
            availableBalance: availableBalance,
            price: price,
            isOnchainSync: isOnchainSync,
            isOffchainSync: isOffchainSync
        )
    }
}

extension StakingDashboardItemModel.Concrete {
    func byChangingSyncState(isOnchainSync: Bool, isOffchainSync: Bool) -> StakingDashboardItemModel.Concrete {
        StakingDashboardItemModel.Concrete(
            stakingOption: stakingOption,
            dashboardItem: dashboardItem,
            accountId: accountId,
            availableBalance: availableBalance,
            price: price,
            isOnchainSync: isOnchainSync,
            isOffchainSync: isOffchainSync
        )
    }
}

extension StakingDashboardItemModel {
    func byChangingSyncState(isOnchainSync: Bool, isOffchainSync: Bool) -> StakingDashboardItemModel {
        switch self {
        case let .combined(value):
            let newValue = value.byChangingSyncState(isOnchainSync: isOnchainSync, isOffchainSync: isOffchainSync)
            return .combined(newValue)
        case let .concrete(value):
            let newValue = value.byChangingSyncState(isOnchainSync: isOnchainSync, isOffchainSync: isOffchainSync)
            return .concrete(newValue)
        }
    }
}

extension StakingDashboardItemModel: StakingDashboardItemModelCommonProtocol {
    var chainAsset: ChainAsset {
        switch self {
        case let .combined(value):
            return value.chainAsset
        case let .concrete(value):
            return value.chainAsset
        }
    }

    var accountId: AccountId? {
        switch self {
        case let .combined(value):
            return value.accountId
        case let .concrete(value):
            return value.accountId
        }
    }

    var availableBalance: BigUInt? {
        switch self {
        case let .combined(value):
            return value.availableBalance
        case let .concrete(value):
            return value.availableBalance
        }
    }

    var price: PriceData? {
        switch self {
        case let .combined(value):
            return value.price
        case let .concrete(value):
            return value.price
        }
    }

    var maxApy: Decimal? {
        switch self {
        case let .combined(value):
            return value.maxApy
        case let .concrete(value):
            return value.maxApy
        }
    }

    var isOnchainSync: Bool {
        switch self {
        case let .combined(value):
            return value.isOnchainSync
        case let .concrete(value):
            return value.isOnchainSync
        }
    }

    var isOffchainSync: Bool {
        switch self {
        case let .combined(value):
            return value.isOffchainSync
        case let .concrete(value):
            return value.isOffchainSync
        }
    }
}
