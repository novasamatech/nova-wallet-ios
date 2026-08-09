import XCTest
@testable import novawallet
import BigInt
import Foundation_iOS
import UIKit

final class SwapExecutionPresenterTests: XCTestCase {
    func testReceiveAndRateAreNet() throws {
        let detailsViewModelFactory = makeDetailsViewModelFactory()
        let locale = LocalizationManager.shared.selectedLocale
        let chainAssetIn = try XCTUnwrap(CommissionTestFixtures.chain.chainAsset(for: 0))
        let chainAssetOut = try XCTUnwrap(CommissionTestFixtures.chain.chainAsset(for: 1))

        func expectedAssetOutAmount(_ amount: Balance) -> String {
            detailsViewModelFactory.assetViewModel(
                chainAsset: chainAssetOut,
                amount: amount,
                priceData: nil,
                locale: locale
            ).amount
        }

        func expectedRate(amountIn: Balance, amountOut: Balance) -> String {
            detailsViewModelFactory.rateViewModel(
                from: RateParams(
                    assetDisplayInfoIn: chainAssetIn.assetDisplayInfo,
                    assetDisplayInfoOut: chainAssetOut.assetDisplayInfo,
                    amountIn: amountIn,
                    amountOut: amountOut
                ),
                locale: locale
            )
        }

        let chargingModel = try makeModel(amountOut: 1_000_000, commission: CommissionTestFixtures.makeCommission())
        let (chargingPresenter, chargingView) = makePresenter(
            model: chargingModel,
            detailsViewModelFactory: detailsViewModelFactory
        )
        chargingPresenter.setup()

        let chargingAssetOut = try XCTUnwrap(chargingView.assetOutViewModel)
        XCTAssertEqual(chargingAssetOut.amount, expectedAssetOutAmount(991_500))

        guard case let .loaded(chargingRate) = chargingView.rateViewModel else {
            XCTFail("expected a loaded rate view model")
            return
        }
        XCTAssertEqual(chargingRate, expectedRate(amountIn: 1_000_000, amountOut: 991_500))

        let noCommissionModel = try makeModel(amountOut: 1_000_000, commission: nil)
        let (noCommissionPresenter, noCommissionView) = makePresenter(
            model: noCommissionModel,
            detailsViewModelFactory: detailsViewModelFactory
        )
        noCommissionPresenter.setup()

        let noCommissionAssetOut = try XCTUnwrap(noCommissionView.assetOutViewModel)
        XCTAssertEqual(noCommissionAssetOut.amount, expectedAssetOutAmount(1_000_000))

        guard case let .loaded(noCommissionRate) = noCommissionView.rateViewModel else {
            XCTFail("expected a loaded rate view model")
            return
        }
        XCTAssertEqual(noCommissionRate, expectedRate(amountIn: 1_000_000, amountOut: 1_000_000))

        // netting `provideAssetOutViewModel`/`provideRateViewModel` must not leak into
        // `providePriceDifferenceViewModel`, which stays on the gross `quote.route.amountOut`
        // whether or not a commission is present
        XCTAssertEqual(
            describePriceDifference(chargingView.priceDifferenceViewModel),
            describePriceDifference(noCommissionView.priceDifferenceViewModel)
        )
    }

    func testDisclosureShownIffCommissionPresent() throws {
        let detailsViewModelFactory = makeDetailsViewModelFactory()
        let locale = LocalizationManager.shared.selectedLocale
        let expectedDisclosure = detailsViewModelFactory.commissionDisclosureViewModel(
            rate: AssetExchangeCommissionConstants.rate,
            locale: locale
        )

        let chargingModel = try makeModel(amountOut: 1_000_000, commission: CommissionTestFixtures.makeCommission())
        let (chargingPresenter, chargingView) = makePresenter(
            model: chargingModel,
            detailsViewModelFactory: detailsViewModelFactory
        )
        chargingPresenter.setup()

        XCTAssertEqual(chargingView.commissionDisclosureViewModel, expectedDisclosure)

        let noCommissionModel = try makeModel(amountOut: 1_000_000, commission: nil)
        let (noCommissionPresenter, noCommissionView) = makePresenter(
            model: noCommissionModel,
            detailsViewModelFactory: detailsViewModelFactory
        )
        noCommissionPresenter.setup()

        XCTAssertNil(noCommissionView.commissionDisclosureViewModel)
    }

    func testCommissionNeverExceedsRateOfActualOutput() throws {
        let policy = CommissionTestFixtures.createPolicy(beneficiaryFree: 10, minBalance: 1).policy
        let commission = CommissionTestFixtures.makeCommission()

        // (G, B): G is the output actually produced by the chain, B is the bound the submitted
        // call enforces. B <= G always — `replacingAmountIn` scales amountOut with amountIn, so a
        // smaller bound never comes from a larger actual output at the same input.
        let pairs: [(g: Balance, b: Balance)] = [
            (1_000_000, 1_000_000),
            (1_000_000, 990_000),
            (500_000, 500_000)
        ]

        for pair in pairs {
            let callArgs = CommissionTestFixtures.makeCallArgs(
                direction: .sell,
                amountIn: 1_000_000,
                amountOut: pair.b,
                slippage: BigRational(numerator: 0, denominator: 100)
            )

            let commissionAmount = HydraExchangeExtrinsicParamsFactory.commissionAmount(
                for: commission,
                callArgs: callArgs
            )

            let landed = pair.g - commissionAmount
            let floorNet = policy.netAmount(from: pair.g, willCharge: true)

            XCTAssertGreaterThanOrEqual(landed, floorNet)
        }
    }
}

private extension SwapExecutionPresenterTests {
    func describePriceDifference(_ viewModel: LoadableViewModelState<DifferenceViewModel>?) -> String {
        switch viewModel {
        case .none:
            "none"
        case .loading:
            "loading"
        case let .cached(value):
            "cached:\(value.details)"
        case let .loaded(value):
            "loaded:\(value.details)"
        }
    }

    func makeDetailsViewModelFactory() -> SwapDetailsViewModelFactory {
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())

        return SwapDetailsViewModelFactory(
            balanceViewModelFactoryFacade: BalanceViewModelFactoryFacade(
                priceAssetInfoFactory: priceAssetInfoFactory
            ),
            priceAssetInfoFactory: priceAssetInfoFactory,
            networkViewModelFactory: NetworkViewModelFactory(),
            assetIconViewModelFactory: AssetIconViewModelFactory(),
            priceDifferenceModelFactory: SwapPriceDifferenceModelFactory(config: .defaultConfig),
            percentFormatter: NumberFormatter.percentSingle.localizableResource()
        )
    }

    func makeModel(amountOut: Balance, commission: AssetExchangeCommission?) throws -> SwapExecutionModel {
        let chain = CommissionTestFixtures.chain
        let chainAssetIn = try XCTUnwrap(chain.chainAsset(for: 0))
        let chainAssetOut = try XCTUnwrap(chain.chainAsset(for: 1))

        let edge = CommissionTestFixtures.createPath([.hydraSwap])[0]
        let routeItem = AssetExchangeRouteItem(edge: edge, amount: 1_000_000, quote: amountOut)
        let route = AssetExchangeRoute(items: [routeItem], amount: 1_000_000, direction: .sell)

        let metaOperation = StubMetaOperation(
            assetIn: chainAssetIn,
            assetOut: chainAssetOut,
            amountIn: 1_000_000,
            amountOut: amountOut
        )

        let quote = AssetExchangeQuote(route: route, metaOperations: [metaOperation], executionTimes: [10])

        let fee = AssetExchangeFee(
            route: route,
            operationFees: [],
            intermediateFeesInAssetIn: 0,
            slippage: BigRational(numerator: 0, denominator: 100),
            feeAssetId: CommissionTestFixtures.asset(0),
            commission: commission
        )

        return SwapExecutionModel(
            chainAssetIn: chainAssetIn,
            chainAssetOut: chainAssetOut,
            feeAsset: chainAssetIn,
            quote: quote,
            fee: fee
        )
    }

    func makePresenter(
        model: SwapExecutionModel,
        detailsViewModelFactory: SwapDetailsViewModelFactoryProtocol
    ) -> (presenter: SwapExecutionPresenter, view: RecordingSwapExecutionView) {
        let view = RecordingSwapExecutionView()

        let presenter = SwapExecutionPresenter(
            model: model,
            interactor: StubSwapExecutionInteractor(),
            wireframe: RecordingSwapExecutionWireframe(),
            executionViewModelFactory: SwapExecutionViewModelFactory(),
            detailsViewModelFactory: detailsViewModelFactory,
            priceStore: StubExchangePriceStore(prices: [:]),
            commissionPolicy: CommissionTestFixtures.createPolicy(beneficiaryFree: 10, minBalance: 1).policy,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return (presenter, view)
    }
}

private final class StubSwapExecutionInteractor: SwapExecutionInteractorInputProtocol {
    func submit(using _: AssetExchangeFee) {}
}

private final class RecordingSwapExecutionView: SwapExecutionViewProtocol {
    let isSetup = true
    let controller = UIViewController()

    private(set) var executionViewModel: SwapExecutionViewModel?
    private(set) var remainedTime: UInt?
    private(set) var assetInViewModel: SwapAssetAmountViewModel?
    private(set) var assetOutViewModel: SwapAssetAmountViewModel?
    private(set) var rateViewModel: LoadableViewModelState<String>?
    private(set) var routeViewModel: LoadableViewModelState<[SwapRouteItemView.ItemViewModel]>?
    private(set) var priceDifferenceViewModel: LoadableViewModelState<DifferenceViewModel>?
    private(set) var slippageViewModel: String?
    private(set) var totalFeeViewModel: LoadableViewModelState<NetworkFeeInfoViewModel>?
    private(set) var commissionDisclosureViewModel: String?

    func didReceiveExecution(viewModel: SwapExecutionViewModel) {
        executionViewModel = viewModel
    }

    func didUpdateExecution(remainedTime: UInt) {
        self.remainedTime = remainedTime
    }

    func didReceiveAssetIn(viewModel: SwapAssetAmountViewModel) {
        assetInViewModel = viewModel
    }

    func didReceiveAssetOut(viewModel: SwapAssetAmountViewModel) {
        assetOutViewModel = viewModel
    }

    func didReceiveRate(viewModel: LoadableViewModelState<String>) {
        rateViewModel = viewModel
    }

    func didReceiveRoute(viewModel: LoadableViewModelState<[SwapRouteItemView.ItemViewModel]>) {
        routeViewModel = viewModel
    }

    func didReceivePriceDifference(viewModel: LoadableViewModelState<DifferenceViewModel>?) {
        priceDifferenceViewModel = viewModel
    }

    func didReceiveSlippage(viewModel: String) {
        slippageViewModel = viewModel
    }

    func didReceiveTotalFee(viewModel: LoadableViewModelState<NetworkFeeInfoViewModel>) {
        totalFeeViewModel = viewModel
    }

    func didReceiveCommissionDisclosure(viewModel: String?) {
        commissionDisclosureViewModel = viewModel
    }
}

private final class RecordingSwapExecutionWireframe: SwapExecutionWireframeProtocol {
    func complete(on _: ControllerBackedProtocol?, receiveChainAsset _: ChainAsset) {}

    func showSwapSetup(
        from _: SwapExecutionViewProtocol?,
        payChainAsset _: ChainAsset,
        receiveChainAsset _: ChainAsset
    ) {}

    func showRouteDetails(
        from _: ControllerBackedProtocol?,
        quote _: AssetExchangeQuote,
        fee _: AssetExchangeFee
    ) {}

    func showFeeDetails(
        from _: ControllerBackedProtocol?,
        operations _: [AssetExchangeMetaOperationProtocol],
        fee _: AssetExchangeFee
    ) {}
}
