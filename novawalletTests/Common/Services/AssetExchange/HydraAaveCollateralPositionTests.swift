import XCTest
@testable import novawallet
import BigInt

final class HydraAaveCollateralPositionTests: XCTestCase {
    func testBorrowerAtLiquidationEdgeCannotSwapCollateral() {
        let position = makePosition(
            collateral: 1_909_921_790,
            debt: 1_601_343_823,
            liquidationThreshold: 8387,
            userConfiguration: 0x20C0,
            reserve: makeReserve(index: 3, ltv: 8000, liquidationThreshold: 8500, eModeCategory: 2),
            price: 95_093_401
        )

        XCTAssertEqual(position.calculateLimit(), .limited(0))
    }

    func testHealthyBorrowerCanSwapUntilHealthFactorMargin() {
        let position = makePosition(
            collateral: 10_000_000_000,
            debt: 2_000_000_000,
            liquidationThreshold: 8387,
            userConfiguration: 0xC0,
            reserve: makeReserve(index: 3, ltv: 8000, liquidationThreshold: 8387),
            price: 400_000_000
        )

        XCTAssertEqual(position.calculateLimit(), .limited(189_787_766_775))
    }

    func testEModeBorrowerUsesCategoryLiquidationThreshold() {
        let position = makePosition(
            collateral: 10_000_000_000,
            debt: 2_000_000_000,
            liquidationThreshold: 9200,
            userConfiguration: 0xC0,
            reserve: makeReserve(index: 3, ltv: 8000, liquidationThreshold: 8500, eModeCategory: 2),
            userEModeCategoryId: 2,
            eModeCategory: HydraAave.EModeCategory(liquidationThreshold: 9200, priceSource: Data(count: 20)),
            price: 400_000_000
        )

        XCTAssertEqual(position.calculateLimit(), .limited(195_108_695_650))
    }

    func testAccountWithoutDebtIsUnrestricted() {
        let position = makePosition(
            collateral: 10_000_000_000,
            debt: 0,
            liquidationThreshold: 8387,
            userConfiguration: 0x80,
            reserve: makeReserve(index: 3, ltv: 8000, liquidationThreshold: 8387),
            price: 400_000_000
        )

        XCTAssertEqual(position.calculateLimit(), .unrestricted)
    }

    func testTokenNotEnabledAsCollateralIsUnrestricted() {
        let position = makePosition(
            collateral: 1_909_921_790,
            debt: 1_601_343_823,
            liquidationThreshold: 8387,
            userConfiguration: 0x2040,
            reserve: makeReserve(index: 3, ltv: 8000, liquidationThreshold: 8500),
            price: 95_093_401
        )

        XCTAssertEqual(position.calculateLimit(), .unrestricted)
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

    private func makePosition(
        collateral: BigUInt,
        debt: BigUInt,
        liquidationThreshold: BigUInt,
        userConfiguration: BigUInt,
        reserve: HydraAave.ReserveData,
        userEModeCategoryId: BigUInt = 0,
        eModeCategory: HydraAave.EModeCategory? = nil,
        price: BigUInt
    ) -> HydraAave.CollateralPosition {
        HydraAave.CollateralPosition(
            accountData: HydraAave.UserAccountData(
                totalCollateralBase: collateral,
                totalDebtBase: debt,
                currentLiquidationThreshold: liquidationThreshold,
                healthFactor: 0
            ),
            userConfiguration: HydraAave.UserConfiguration(rawValue: userConfiguration),
            reserve: reserve,
            reserves: [reserve],
            userEModeCategoryId: userEModeCategoryId,
            eModeCategory: eModeCategory,
            price: price
        )
    }
}
