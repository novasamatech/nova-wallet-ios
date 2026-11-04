import Foundation
import BigInt

extension HydraAave {
    enum CollateralLimit: Equatable {
        case unrestricted
        case limited(Balance)

        func ceiling(afterFee fee: Balance) -> Balance? {
            guard case let .limited(limit) = self else {
                return nil
            }

            return limit.subtractOrZero(fee)
        }
    }

    struct ReserveConfiguration: Equatable {
        let rawValue: BigUInt

        var ltv: BigUInt {
            value(at: 0, bitCount: 16)
        }

        var liquidationThreshold: BigUInt {
            value(at: 16, bitCount: 16)
        }

        var decimals: BigUInt {
            value(at: 48, bitCount: 8)
        }

        var eModeCategory: BigUInt {
            value(at: 168, bitCount: 8)
        }

        private func value(at position: Int, bitCount: Int) -> BigUInt {
            (rawValue >> position) & ((BigUInt(1) << bitCount) - 1)
        }
    }

    struct ReserveData {
        let configuration: ReserveConfiguration
        let index: Int
        let aTokenAddress: AccountId
    }

    struct Reserve {
        let address: AccountId
        let data: ReserveData
    }

    struct UserAccountData: Equatable {
        let totalCollateralBase: BigUInt
        let totalDebtBase: BigUInt
        let currentLiquidationThreshold: BigUInt
    }

    struct UserConfiguration: Equatable {
        let rawValue: BigUInt

        static let maxReservesCount = 128

        var collateralReserveIndices: [Int] {
            (0 ..< Self.maxReservesCount).filter { isUsingAsCollateral(reserveIndex: $0) }
        }

        func isUsingAsCollateral(reserveIndex: Int) -> Bool {
            (rawValue >> (reserveIndex * 2 + 1)) & 1 == 1
        }
    }

    struct EModeCategory: Equatable {
        let liquidationThreshold: BigUInt
        let priceSource: AccountId
    }

    static func evmAddress(for accountId: AccountId) -> AccountId {
        let evmAccountPrefix = Data("ETH\0".utf8)

        if
            accountId.count == 32,
            accountId.prefix(evmAccountPrefix.count) == evmAccountPrefix,
            accountId.suffix(8).allSatisfy({ $0 == 0 }) {
            return Data(accountId.dropFirst(evmAccountPrefix.count).prefix(20))
        }

        return Data(accountId.prefix(20))
    }
}

extension ChainAsset {
    var mayBackHydraAaveLoan: Bool {
        chain.hasSwapHydra && AssetType(rawType: asset.type) == .ormlHydrationEvm
    }
}
