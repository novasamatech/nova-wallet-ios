import XCTest
@testable import novawallet
import BigInt

final class HydraAaveCollateralPositionTests: XCTestCase {
    func testBorrowerAtLiquidationEdgeCannotSwapCollateral() {
        let limit = calculateLimit(
            collateral: 1_909_921_790,
            debt: 1_601_343_823,
            liquidationThreshold: 8387,
            reserve: makeReserve(index: 3, ltv: 8000, liquidationThreshold: 8500, eModeCategory: 2),
            price: 95_093_401
        )

        XCTAssertEqual(limit, .limited(0))
    }

    func testHealthyBorrowerCanSwapUntilHealthFactorMargin() {
        let limit = calculateLimit(
            collateral: 10_000_000_000,
            debt: 2_000_000_000,
            liquidationThreshold: 8387,
            reserve: makeReserve(index: 3, ltv: 8000, liquidationThreshold: 8387),
            price: 400_000_000
        )

        XCTAssertEqual(limit, .limited(189_787_766_775))
    }

    func testEModeBorrowerUsesCategoryLiquidationThreshold() {
        let limit = calculateLimit(
            collateral: 10_000_000_000,
            debt: 2_000_000_000,
            liquidationThreshold: 9200,
            reserve: makeReserve(index: 3, ltv: 8000, liquidationThreshold: 8500, eModeCategory: 2),
            eModeCategory: HydraAave.EModeCategory(liquidationThreshold: 9200, priceSource: Data(count: 20)),
            price: 400_000_000
        )

        XCTAssertEqual(limit, .limited(195_108_695_650))
    }

    private func makeReserve(
        index: Int,
        ltv: BigUInt,
        liquidationThreshold: BigUInt,
        eModeCategory: BigUInt = 0
    ) -> HydraAave.ReserveData {
        let decimals: BigUInt = 10
        let configuration = ltv | liquidationThreshold << 16 | decimals << 48 | eModeCategory << 168

        return HydraAave.ReserveData(
            configuration: HydraAave.ReserveConfiguration(rawValue: configuration),
            index: index,
            aTokenAddress: Data(count: 20)
        )
    }

    private func calculateLimit(
        collateral: BigUInt,
        debt: BigUInt,
        liquidationThreshold: BigUInt,
        reserve: HydraAave.ReserveData,
        eModeCategory: HydraAave.EModeCategory? = nil,
        price: BigUInt
    ) -> HydraAave.CollateralLimit {
        HydraAave.CollateralPosition.calculateLimit(
            accountData: HydraAave.UserAccountData(
                totalCollateralBase: collateral,
                totalDebtBase: debt,
                currentLiquidationThreshold: liquidationThreshold
            ),
            reserve: reserve,
            collateralReserves: [reserve],
            eModeCategory: eModeCategory,
            price: price
        )
    }
}
