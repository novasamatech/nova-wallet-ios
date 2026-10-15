import BigInt
import Foundation

enum SubtensorStakeTarget: Equatable {
    case root
    case subnet(info: SubtensorStakingPallet.DynamicInfo, price: Balance)
}

extension SubtensorStakeTarget {
    var netuid: UInt16 {
        switch self {
        case .root:
            return SubtensorStakingPallet.rootNetuid
        case let .subnet(info, _):
            return info.netuid
        }
    }

    var isRoot: Bool {
        if case .root = self {
            return true
        }

        return false
    }

    var subnetInfo: SubtensorStakingPallet.DynamicInfo? {
        if case let .subnet(info, _) = self {
            return info
        }

        return nil
    }

    var subnetRef: SubtensorSubnetRef {
        SubtensorSubnetRef(netuid: netuid, registeredAt: subnetInfo?.networkRegisteredAt ?? 0)
    }

    var listedPrice: Balance? {
        if case let .subnet(_, price) = self {
            return price
        }

        return nil
    }

    // root is mechanism 0: the chain treats any buy limit >= 1e9 as full fill and
    // below as guaranteed kill, so limit trades on root are degenerate and never emitted
    func stakeLimitPrice(spot: Balance?, tolerance: BigRational) -> Balance? {
        guard case .subnet = self, let spot else {
            return nil
        }

        return try? SubtensorLimitPriceCalculator.buyLimit(spot: spot, tolerance: tolerance)
    }

    func unstakeLimitPrice(spot: Balance?, tolerance: BigRational) -> Balance? {
        guard case .subnet = self, let spot else {
            return nil
        }

        return try? SubtensorLimitPriceCalculator.sellLimit(spot: spot, tolerance: tolerance)
    }
}

extension SubtensorStakeTarget {
    func assetDisplayInfo(
        basedOn taoDisplayInfo: AssetBalanceDisplayInfo,
        catalogue: SubtensorSubnetCatalogue?
    ) -> AssetBalanceDisplayInfo {
        guard !isRoot else {
            return taoDisplayInfo
        }

        return taoDisplayInfo.subtensorAlpha(symbol: SubtensorSubnetNaming.symbol(for: netuid, in: catalogue))
    }
}
