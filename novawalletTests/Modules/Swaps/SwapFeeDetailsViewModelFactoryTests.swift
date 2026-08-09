import XCTest
@testable import novawallet
import BigInt
import Foundation_iOS

final class SwapFeeDetailsViewModelFactoryTests: XCTestCase {
    func testNoCommissionRow() throws {
        let factory = makeFactory()
        let operations = [try makeOperation()]
        let locale = LocalizationManager.shared.selectedLocale

        let feeWithCommission = makeFee(commission: CommissionTestFixtures.makeCommission())
        let feeWithoutCommission = makeFee(commission: nil)

        let viewModelWithCommission = factory.createViewModel(from: operations, fee: feeWithCommission, locale: locale)
        let viewModelWithoutCommission = factory.createViewModel(from: operations, fee: feeWithoutCommission, locale: locale)

        XCTAssertEqual(viewModelWithCommission.total, viewModelWithoutCommission.total)
        XCTAssertEqual(viewModelWithCommission.operationFees.count, viewModelWithoutCommission.operationFees.count)
        XCTAssertEqual(
            viewModelWithCommission.operationFees.flatMap { $0.feeGroups.map(\.title) },
            viewModelWithoutCommission.operationFees.flatMap { $0.feeGroups.map(\.title) }
        )
        XCTAssertEqual(
            viewModelWithCommission.operationFees.flatMap { $0.feeGroups.flatMap { $0.amounts.map(\.amount) } },
            viewModelWithoutCommission.operationFees.flatMap { $0.feeGroups.flatMap { $0.amounts.map(\.amount) } }
        )
    }

    func testNetworkFeeIsSubmissionFee() throws {
        let factory = makeFactory()
        let operations = [try makeOperation()]
        let locale = LocalizationManager.shared.selectedLocale

        let firstFee = makeFee(submissionAmount: 12345, commission: nil)
        let secondFee = makeFee(submissionAmount: 54321, commission: nil)

        let firstViewModel = factory.createViewModel(from: operations, fee: firstFee, locale: locale)
        let secondViewModel = factory.createViewModel(from: operations, fee: secondFee, locale: locale)

        XCTAssertNotEqual(firstViewModel.total, secondViewModel.total)
    }
}

private extension SwapFeeDetailsViewModelFactoryTests {
    func makeFactory() -> SwapFeeDetailsViewModelFactory {
        SwapFeeDetailsViewModelFactory(
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: CurrencyManagerStub()),
            priceStore: StubExchangePriceStore(
                prices: [CommissionTestFixtures.asset(0): PriceData.amount(1, identifier: "usd", currencyId: 0)]
            )
        )
    }

    func makeOperation() throws -> AssetExchangeMetaOperationProtocol {
        StubMetaOperation(
            assetIn: try XCTUnwrap(CommissionTestFixtures.chain.chainAsset(for: 0)),
            assetOut: try XCTUnwrap(CommissionTestFixtures.chain.chainAsset(for: 1)),
            amountIn: 1_000_000,
            amountOut: 1_000_000
        )
    }

    func makeFee(submissionAmount: Balance = 12345, commission: AssetExchangeCommission?) -> AssetExchangeFee {
        let operationFee = AssetExchangeOperationFee(
            submissionFee: .init(
                amountWithAsset: .init(amount: submissionAmount, asset: CommissionTestFixtures.asset(0)),
                payer: nil,
                weight: .zero
            ),
            postSubmissionFee: .init(paidByAccount: [], paidFromAmount: [])
        )

        return AssetExchangeFee(
            route: CommissionTestFixtures.createRoute([.hydraSwap], amount: 1_000_000),
            operationFees: [operationFee],
            intermediateFeesInAssetIn: 0,
            slippage: BigRational(numerator: 0, denominator: 100),
            feeAssetId: CommissionTestFixtures.asset(0),
            commission: commission
        )
    }
}
