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
    func assetDisplayInfo(basedOn taoDisplayInfo: AssetBalanceDisplayInfo) -> AssetBalanceDisplayInfo {
        switch self {
        case .root:
            return taoDisplayInfo
        case let .subnet(info, _):
            let symbol = info.displaySymbol

            return AssetBalanceDisplayInfo(
                displayPrecision: taoDisplayInfo.displayPrecision,
                assetPrecision: taoDisplayInfo.assetPrecision,
                symbol: symbol.isEmpty ? "SN\(info.netuid)" : symbol,
                symbolValueSeparator: taoDisplayInfo.symbolValueSeparator,
                symbolPosition: taoDisplayInfo.symbolPosition,
                icon: nil
            )
        }
    }
}
