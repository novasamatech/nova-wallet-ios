import XCTest
@testable import novawallet
import BigInt
import Foundation_iOS
import UIKit

final class SwapRouteDetailsPresenterTests: XCTestCase {
    func testChargingAndLaterHopsRenderNet() throws {
        let viewModelFactory = makeViewModelFactory()
        let locale = LocalizationManager.shared.selectedLocale

        func expected(_ amount: Balance, asset assetId: AssetModel.Id) throws -> String {
            try expectedAmount(amount, asset: assetId, using: viewModelFactory, locale: locale)
        }

        let amounts: [(in: Balance, out: Balance)] = [
            (in: 2_000_000, out: 2_000_000),
            (in: 2_000_000, out: 1_000_000),
            (in: 1_000_000, out: 1_000_000)
        ]

        let chargingQuote = try makeQuote(amounts: amounts)
        let chargingFee = makeFee(
            operationsCount: amounts.count,
            commission: makeCommission(chargingOperationIndex: 1)
        )
        let (chargingPresenter, chargingView) = makePresenter(
            quote: chargingQuote,
            fee: chargingFee,
            viewModelFactory: viewModelFactory
        )
        chargingPresenter.setup()

        let chargingViewModel = try XCTUnwrap(chargingView.viewModel)
        XCTAssertEqual(chargingViewModel.count, 3)
        XCTAssertEqual(chargingViewModel[0].amountItems[1].amount, try expected(2_000_000, asset: 1))
        XCTAssertEqual(chargingViewModel[1].amountItems[1].amount, try expected(991_500, asset: 2))
        XCTAssertEqual(chargingViewModel[2].amountItems[1].amount, try expected(991_500, asset: 3))

        let noCommissionQuote = try makeQuote(amounts: amounts)
        let noCommissionFee = makeFee(operationsCount: amounts.count, commission: nil)
        let (noCommissionPresenter, noCommissionView) = makePresenter(
            quote: noCommissionQuote,
            fee: noCommissionFee,
            viewModelFactory: viewModelFactory
        )
        noCommissionPresenter.setup()

        let noCommissionViewModel = try XCTUnwrap(noCommissionView.viewModel)
        XCTAssertEqual(noCommissionViewModel[0].amountItems[1].amount, try expected(2_000_000, asset: 1))
        XCTAssertEqual(noCommissionViewModel[1].amountItems[1].amount, try expected(1_000_000, asset: 2))
        XCTAssertEqual(noCommissionViewModel[2].amountItems[1].amount, try expected(1_000_000, asset: 3))
    }

    func testChargingOperationInputStaysGross() throws {
        let viewModelFactory = makeViewModelFactory()
        let locale = LocalizationManager.shared.selectedLocale

        func expected(_ amount: Balance, asset assetId: AssetModel.Id) throws -> String {
            try expectedAmount(amount, asset: assetId, using: viewModelFactory, locale: locale)
        }

        let amounts: [(in: Balance, out: Balance)] = [
            (in: 1_000_000, out: 1_000_000),
            (in: 1_000_000, out: 1_000_000)
        ]

        let quote = try makeQuote(amounts: amounts)
        let fee = makeFee(operationsCount: amounts.count, commission: makeCommission(chargingOperationIndex: 1))
        let (presenter, view) = makePresenter(quote: quote, fee: fee, viewModelFactory: viewModelFactory)
        presenter.setup()

        let viewModel = try XCTUnwrap(view.viewModel)
        XCTAssertEqual(viewModel[1].amountItems[0].amount, try expected(1_000_000, asset: 1))
        XCTAssertEqual(viewModel[1].amountItems[1].amount, try expected(991_500, asset: 2))
    }

    func testLaterOperationInputIsNet() throws {
        let viewModelFactory = makeViewModelFactory()
        let locale = LocalizationManager.shared.selectedLocale

        func expected(_ amount: Balance, asset assetId: AssetModel.Id) throws -> String {
            try expectedAmount(amount, asset: assetId, using: viewModelFactory, locale: locale)
        }

        let amounts: [(in: Balance, out: Balance)] = [
            (in: 1_000_000, out: 1_000_000),
            (in: 1_000_000, out: 1_000_000)
        ]

        let quote = try makeQuote(amounts: amounts)
        let fee = makeFee(operationsCount: amounts.count, commission: makeCommission(chargingOperationIndex: 0))
        let (presenter, view) = makePresenter(quote: quote, fee: fee, viewModelFactory: viewModelFactory)
        presenter.setup()

        let viewModel = try XCTUnwrap(view.viewModel)
        // the same physical transfer: operation 0's output and operation 1's input must read as
        // one number
        XCTAssertEqual(viewModel[0].amountItems[1].amount, try expected(991_500, asset: 1))
        XCTAssertEqual(viewModel[1].amountItems[0].amount, try expected(991_500, asset: 1))
    }

    func testDisclosureShownIffCommissionPresent() throws {
        let viewModelFactory = makeViewModelFactory()
        let locale = LocalizationManager.shared.selectedLocale
        let expectedDisclosure = viewModelFactory.commissionDisclosureViewModel(
            rate: AssetExchangeCommissionConstants.rate,
            locale: locale
        )

        let amounts: [(in: Balance, out: Balance)] = [(in: 1_000_000, out: 1_000_000)]

        let chargingQuote = try makeQuote(amounts: amounts)
        let chargingFee = makeFee(
            operationsCount: amounts.count,
            commission: makeCommission(chargingOperationIndex: 0)
        )
        let (chargingPresenter, chargingView) = makePresenter(
            quote: chargingQuote,
            fee: chargingFee,
            viewModelFactory: viewModelFactory
        )
        chargingPresenter.setup()

        XCTAssertEqual(chargingView.commissionDisclosureViewModel, expectedDisclosure)

        let noCommissionQuote = try makeQuote(amounts: amounts)
        let noCommissionFee = makeFee(operationsCount: amounts.count, commission: nil)
        let (noCommissionPresenter, noCommissionView) = makePresenter(
            quote: noCommissionQuote,
            fee: noCommissionFee,
            viewModelFactory: viewModelFactory
        )
        noCommissionPresenter.setup()

        XCTAssertNil(noCommissionView.commissionDisclosureViewModel)
    }
}

private extension SwapRouteDetailsPresenterTests {
    func makeViewModelFactory() -> SwapRouteDetailsViewModelFactory {
        SwapRouteDetailsViewModelFactory(
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: CurrencyManagerStub()),
            priceStore: StubExchangePriceStore(prices: [:]),
            percentFormatter: NumberFormatter.percentSingle.localizableResource()
        )
    }

    func makeOperationFee() -> AssetExchangeOperationFee {
        AssetExchangeOperationFee(
            submissionFee: .init(
                amountWithAsset: .init(amount: 0, asset: CommissionTestFixtures.asset(0)),
                payer: nil,
                weight: .zero
            ),
            postSubmissionFee: .init(paidByAccount: [], paidFromAmount: [])
        )
    }

    func makeCommission(chargingOperationIndex: Int) -> AssetExchangeCommission {
        AssetExchangeCommission(
            chargingOperationIndex: chargingOperationIndex,
            asset: CommissionTestFixtures.asset(0),
            estimatedAmount: 999_999_999,
            beneficiary: CommissionTestFixtures.beneficiary,
            rate: AssetExchangeCommissionConstants.rate
        )
    }

    /// Operation *i* runs `asset(i)` → `asset(i + 1)`, so consecutive operations chain exactly as
    /// a real route does: operation *i*'s `assetOut` is operation *i+1*'s `assetIn`.
    func makeQuote(amounts: [(in: Balance, out: Balance)]) throws -> AssetExchangeQuote {
        let chain = CommissionTestFixtures.chain

        let operations = try amounts.enumerated().map { index, pair -> AssetExchangeMetaOperationProtocol in
            let assetIn = try XCTUnwrap(chain.chainAsset(for: AssetModel.Id(index)))
            let assetOut = try XCTUnwrap(chain.chainAsset(for: AssetModel.Id(index + 1)))

            return StubMetaOperation(assetIn: assetIn, assetOut: assetOut, amountIn: pair.in, amountOut: pair.out)
        }

        return AssetExchangeQuote(
            route: CommissionTestFixtures.createRoute([.hydraSwap], amount: 0),
            metaOperations: operations,
            executionTimes: Array(repeating: 0, count: amounts.count)
        )
    }

    func makeFee(operationsCount: Int, commission: AssetExchangeCommission?) -> AssetExchangeFee {
        AssetExchangeFee(
            route: CommissionTestFixtures.createRoute([.hydraSwap], amount: 0),
            operationFees: Array(repeating: makeOperationFee(), count: operationsCount),
            intermediateFeesInAssetIn: 0,
            slippage: BigRational(numerator: 0, denominator: 100),
            feeAssetId: CommissionTestFixtures.asset(0),
            commission: commission
        )
    }

    func makePresenter(
        quote: AssetExchangeQuote,
        fee: AssetExchangeFee,
        viewModelFactory: SwapRouteDetailsViewModelFactoryProtocol
    ) -> (presenter: SwapRouteDetailsPresenter, view: RecordingSwapRouteDetailsView) {
        let view = RecordingSwapRouteDetailsView()

        let presenter = SwapRouteDetailsPresenter(
            quote: quote,
            fee: fee,
            prices: [:],
            viewModelFactory: viewModelFactory,
            commissionPolicy: CommissionTestFixtures.createPolicy(beneficiaryFree: 10, minBalance: 1).policy,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return (presenter, view)
    }

    /// Renders, through the same factory the presenter under test uses, a one-operation stub
    /// whose `assetIn` and `assetOut` are both `asset(assetId)`. Because both slots then carry the
    /// same asset, `.amountItems[1].amount` is a valid oracle for an input slot as well as an
    /// output one.
    func expectedAmount(
        _ amount: Balance,
        asset assetId: AssetModel.Id,
        using viewModelFactory: SwapRouteDetailsViewModelFactoryProtocol,
        locale: Locale
    ) throws -> String {
        let chainAsset = try XCTUnwrap(CommissionTestFixtures.chain.chainAsset(for: assetId))
        let operation = StubMetaOperation(
            assetIn: chainAsset,
            assetOut: chainAsset,
            amountIn: amount,
            amountOut: amount
        )

        let viewModel = viewModelFactory.createViewModel(
            for: operation,
            fee: makeOperationFee(),
            netAmountIn: amount,
            netAmountOut: amount,
            locale: locale
        )

        return viewModel.amountItems[1].amount
    }
}

private final class RecordingSwapRouteDetailsView: SwapRouteDetailsViewProtocol {
    let isSetup = true
    let controller = UIViewController()

    private(set) var viewModel: SwapRouteDetailsViewModel?
    private(set) var commissionDisclosureViewModel: String?

    func didReceive(viewModel: SwapRouteDetailsViewModel) {
        self.viewModel = viewModel
    }

    func didReceiveCommissionDisclosure(viewModel: String?) {
        commissionDisclosureViewModel = viewModel
    }
}
