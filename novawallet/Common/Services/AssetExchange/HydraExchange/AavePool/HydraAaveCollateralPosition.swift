import Foundation
import BigInt

extension HydraAave {
    static let minSafeHealthFactorBps: BigUInt = 10100

    struct CollateralPosition {
        let accountData: UserAccountData
        let isCollateral: Bool
        let isBlockedByZeroLtvCollateral: Bool
        let liquidationThreshold: BigUInt
        let price: BigUInt
        let decimals: BigUInt
    }
}

extension HydraAave.CollateralPosition {
    init(
        accountData: HydraAave.UserAccountData,
        userConfiguration: HydraAave.UserConfiguration,
        reserve: HydraAave.ReserveData,
        reserves: [HydraAave.ReserveData],
        userEModeCategoryId: BigUInt,
        eModeCategory: HydraAave.EModeCategory?,
        price: BigUInt
    ) {
        let configuration = reserve.configuration

        let hasZeroLtvCollateral = reserves.contains { otherReserve in
            userConfiguration.isUsingAsCollateral(reserveIndex: otherReserve.index) &&
                otherReserve.configuration.liquidationThreshold > 0 &&
                otherReserve.configuration.ltv == 0
        }

        let liquidationThreshold: BigUInt = if
            configuration.liquidationThreshold > 0,
            let eModeCategory = Self.userEModeCategory(
                for: configuration,
                userEModeCategoryId: userEModeCategoryId,
                eModeCategory: eModeCategory
            ) {
            eModeCategory.liquidationThreshold
        } else {
            configuration.liquidationThreshold
        }

        self.init(
            accountData: accountData,
            isCollateral: userConfiguration.isUsingAsCollateral(reserveIndex: reserve.index),
            isBlockedByZeroLtvCollateral: hasZeroLtvCollateral && configuration.ltv > 0,
            liquidationThreshold: liquidationThreshold,
            price: price,
            decimals: configuration.decimals
        )
    }

    static func priceAsset(
        for reserve: HydraAave.Reserve,
        userEModeCategoryId: BigUInt,
        eModeCategory: HydraAave.EModeCategory?
    ) -> AccountId {
        guard
            let eModeCategory = userEModeCategory(
                for: reserve.data.configuration,
                userEModeCategoryId: userEModeCategoryId,
                eModeCategory: eModeCategory
            ),
            eModeCategory.priceSource.contains(where: { $0 != 0 }) else {
            return reserve.address
        }

        return eModeCategory.priceSource
    }

    func calculateLimit() -> HydraAave.CollateralLimit {
        guard isCollateral, accountData.totalDebtBase > 0 else {
            return .unrestricted
        }

        guard !isBlockedByZeroLtvCollateral else {
            return .limited(0)
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

        return .limited(withdrawableBase * BigUInt(10).power(Int(decimals)) / price)
    }
}

private extension HydraAave.CollateralPosition {
    static func userEModeCategory(
        for configuration: HydraAave.ReserveConfiguration,
        userEModeCategoryId: BigUInt,
        eModeCategory: HydraAave.EModeCategory?
    ) -> HydraAave.EModeCategory? {
        guard userEModeCategoryId > 0, configuration.eModeCategory == userEModeCategoryId else {
            return nil
        }

        return eModeCategory
    }
}
