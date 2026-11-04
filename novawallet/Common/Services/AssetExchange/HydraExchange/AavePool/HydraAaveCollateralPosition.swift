import Foundation
import BigInt

extension HydraAave {
    static let minSafeHealthFactorBps: BigUInt = 10100

    enum CollateralPosition {
        static func userEModeCategory(
            for configuration: ReserveConfiguration,
            userEModeCategoryId: BigUInt,
            eModeCategory: EModeCategory?
        ) -> EModeCategory? {
            guard userEModeCategoryId > 0, configuration.eModeCategory == userEModeCategoryId else {
                return nil
            }

            return eModeCategory
        }

        static func priceAsset(for reserve: Reserve, eModeCategory: EModeCategory?) -> AccountId {
            guard let priceSource = eModeCategory?.priceSource, priceSource.contains(where: { $0 != 0 }) else {
                return reserve.address
            }

            return priceSource
        }

        static func calculateLimit(
            accountData: UserAccountData,
            reserve: ReserveData,
            collateralReserves: [ReserveData],
            eModeCategory: EModeCategory?,
            price: BigUInt
        ) -> CollateralLimit {
            let configuration = reserve.configuration

            let isBlockedByZeroLtvCollateral = configuration.ltv > 0 && collateralReserves.contains {
                $0.configuration.liquidationThreshold > 0 && $0.configuration.ltv == 0
            }

            guard !isBlockedByZeroLtvCollateral else {
                return .limited(0)
            }

            let liquidationThreshold = if configuration.liquidationThreshold > 0, let eModeCategory {
                eModeCategory.liquidationThreshold
            } else {
                configuration.liquidationThreshold
            }

            let weightedCollateral = accountData.totalCollateralBase * accountData.currentLiquidationThreshold
            let requiredCollateral = accountData.totalDebtBase * HydraAave.minSafeHealthFactorBps

            guard liquidationThreshold > 0, price > 0 else {
                return weightedCollateral >= requiredCollateral ? .unrestricted : .limited(0)
            }

            guard weightedCollateral > requiredCollateral else {
                return .limited(0)
            }

            let withdrawableBase = (weightedCollateral - requiredCollateral) / liquidationThreshold

            return .limited(withdrawableBase * BigUInt(10).power(Int(configuration.decimals)) / price)
        }
    }
}
