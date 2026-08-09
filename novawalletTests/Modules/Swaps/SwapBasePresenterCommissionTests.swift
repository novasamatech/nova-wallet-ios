import XCTest
@testable import novawallet
import BigInt
import Foundation_iOS
import UIKit

final class SwapBasePresenterCommissionTests: XCTestCase {
    func testReceiveAndRateUseNetAmount() throws {
        let payAsset = try XCTUnwrap(CommissionTestFixtures.chain.chainAsset(for: 0))
        let receiveAsset = try XCTUnwrap(CommissionTestFixtures.chain.chainAsset(for: 1))
        let locale = LocalizationManager.shared.selectedLocale

        let (sellPresenter, sellView, _, sellFactory) = makeSetupPresenter(payAsset: payAsset, receiveAsset: receiveAsset)
        sellPresenter.updatePayAmount(1)
        _ = try deliverQuote(to: sellPresenter, edgeTypes: [.hydraSwap], amountOut: 1_000_000)

        XCTAssertEqual(
            sellView.receiveAmountInputViewModel?.displayAmount,
            expectedAmountInputDisplay(991_500, chainAsset: receiveAsset, factory: sellFactory, locale: locale)
        )

        guard case let .loaded(sellRate) = sellView.rateViewModel else {
            XCTFail("expected a loaded rate view model")
            return
        }
        XCTAssertEqual(
            sellRate,
            expectedRate(
                amountIn: 1_000_000,
                amountOut: 991_500,
                payAsset: payAsset,
                receiveAsset: receiveAsset,
                factory: sellFactory,
                locale: locale
            )
        )

        // .buy: the field the user typed is never rewritten by the quote that lands
        let (buyPresenter, buyView, _, buyFactory) = makeSetupPresenter(
            payAsset: payAsset,
            receiveAsset: receiveAsset,
            amount: 1_000_000,
            direction: .buy
        )
        buyPresenter.setup()

        // `initState.amount` is already the human-readable Decimal the user typed, not a raw
        // planck `Balance` — unlike `expectedAmountInputDisplay`'s other call sites, it must not
        // be divided down by `.decimal(assetInfo:)` again here.
        let typedDisplay = buyFactory.amountInputViewModel(
            chainAsset: receiveAsset,
            amount: Decimal(1_000_000),
            locale: locale
        ).displayAmount
        XCTAssertEqual(buyView.receiveAmountInputViewModel?.displayAmount, typedDisplay)

        _ = try deliverQuote(to: buyPresenter, edgeTypes: [.hydraSwap], amountOut: 1_000_000)

        XCTAssertEqual(buyView.receiveAmountInputViewModel?.displayAmount, typedDisplay)
    }

    func testPriceImpactAndRateChangeUseGross() throws {
        let payAsset = try XCTUnwrap(CommissionTestFixtures.chain.chainAsset(for: 0))
        let receiveAsset = try XCTUnwrap(CommissionTestFixtures.chain.chainAsset(for: 1))

        let (hydraPresenter, _, _, _) = makeSetupPresenter(payAsset: payAsset, receiveAsset: receiveAsset)
        hydraPresenter.updatePayAmount(1)
        _ = try deliverQuote(to: hydraPresenter, edgeTypes: [.hydraSwap], amountOut: 1_000_000)

        let (crossPresenter, _, _, _) = makeSetupPresenter(payAsset: payAsset, receiveAsset: receiveAsset)
        crossPresenter.updatePayAmount(1)
        _ = try deliverQuote(to: crossPresenter, edgeTypes: [.crossChain], amountOut: 1_000_000)

        XCTAssertEqual(
            describeDifferenceModel(hydraPresenter.getPriceDifferenceModel()),
            describeDifferenceModel(crossPresenter.getPriceDifferenceModel())
        )

        // `SwapModel.quote` is exactly what `asyncCheckQuoteValidity` reads as its `currentQuote`
        // and compares via `route.amountOut` — asserting it directly is the same fact that method
        // would observe, without duplicating its closure plumbing here.
        let hydraModel = try XCTUnwrap(hydraPresenter.getSwapModel())
        let crossModel = try XCTUnwrap(crossPresenter.getSwapModel())

        XCTAssertEqual(hydraModel.quote?.route.amountOut, 1_000_000)
        XCTAssertEqual(crossModel.quote?.route.amountOut, 1_000_000)
        XCTAssertEqual(hydraModel.quote?.route.amountOut, crossModel.quote?.route.amountOut)
    }

    func testReceiveIsNetBeforeFeeArrives() throws {
        let payAsset = try XCTUnwrap(CommissionTestFixtures.chain.chainAsset(for: 0))
        let receiveAsset = try XCTUnwrap(CommissionTestFixtures.chain.chainAsset(for: 1))
        let locale = LocalizationManager.shared.selectedLocale

        let (presenter, view, _, factory) = makeSetupPresenter(payAsset: payAsset, receiveAsset: receiveAsset)
        presenter.updatePayAmount(1)
        let quote = try deliverQuote(to: presenter, edgeTypes: [.hydraSwap], amountOut: 1_000_000)

        XCTAssertTrue(presenter.chargesCommission)
        XCTAssertEqual(
            view.receiveAmountInputViewModel?.displayAmount,
            expectedAmountInputDisplay(991_500, chainAsset: receiveAsset, factory: factory, locale: locale)
        )
        XCTAssertNotNil(view.commissionDisclosureViewModel)

        deliverFee(to: presenter, route: quote.route, commission: nil)

        XCTAssertFalse(presenter.chargesCommission)
        XCTAssertEqual(
            view.receiveAmountInputViewModel?.displayAmount,
            expectedAmountInputDisplay(1_000_000, chainAsset: receiveAsset, factory: factory, locale: locale)
        )
        XCTAssertNil(view.commissionDisclosureViewModel)
    }

    func testDisclosureShownIffPathCharges() throws {
        let payAsset = try XCTUnwrap(CommissionTestFixtures.chain.chainAsset(for: 0))
        let noChargeReceiveAsset = try XCTUnwrap(CommissionTestFixtures.chain.chainAsset(for: 2))

        let (noChargePresenter, noChargeView, _, _) = makeSetupPresenter(
            payAsset: payAsset,
            receiveAsset: noChargeReceiveAsset
        )
        noChargePresenter.updatePayAmount(1)
        let noChargeQuote = try deliverQuote(
            to: noChargePresenter,
            edgeTypes: [.crossChain, .crossChain],
            amountOut: 1_000_000
        )

        XCTAssertNil(noChargeView.commissionDisclosureViewModel)

        deliverFee(to: noChargePresenter, route: noChargeQuote.route, commission: nil)

        XCTAssertNil(noChargeView.commissionDisclosureViewModel)

        // a failed fee on a charging path is not a withdrawal
        let hydraReceiveAsset = try XCTUnwrap(CommissionTestFixtures.chain.chainAsset(for: 1))
        let (chargePresenter, chargeView, _, chargeFactory) = makeSetupPresenter(
            payAsset: payAsset,
            receiveAsset: hydraReceiveAsset
        )
        chargePresenter.updatePayAmount(1)
        _ = try deliverQuote(to: chargePresenter, edgeTypes: [.hydraSwap], amountOut: 1_000_000)

        let locale = LocalizationManager.shared.selectedLocale
        let expectedReceive = expectedAmountInputDisplay(
            991_500,
            chainAsset: hydraReceiveAsset,
            factory: chargeFactory,
            locale: locale
        )
        XCTAssertNotNil(chargeView.commissionDisclosureViewModel)
        XCTAssertEqual(chargeView.receiveAmountInputViewModel?.displayAmount, expectedReceive)

        chargePresenter.didReceive(baseError: .fetchFeeFailed(CommonError.dataCorruption, nil))

        XCTAssertNotNil(chargeView.commissionDisclosureViewModel)
        XCTAssertEqual(chargeView.receiveAmountInputViewModel?.displayAmount, expectedReceive)
    }

    func testDisclosureCarriesPercentageNotAmount() throws {
        let payAsset = try XCTUnwrap(CommissionTestFixtures.chain.chainAsset(for: 0))
        let receiveAsset = try XCTUnwrap(CommissionTestFixtures.chain.chainAsset(for: 1))
        let locale = LocalizationManager.shared.selectedLocale

        let (presenter, view, _, factory) = makeSetupPresenter(payAsset: payAsset, receiveAsset: receiveAsset)
        presenter.updatePayAmount(1)
        _ = try deliverQuote(to: presenter, edgeTypes: [.hydraSwap], amountOut: 1_000_000)

        let disclosure = try XCTUnwrap(view.commissionDisclosureViewModel)

        XCTAssertEqual(
            disclosure,
            factory.commissionDisclosureViewModel(rate: AssetExchangeCommissionConstants.rate, locale: locale)
        )

        let percentString = try XCTUnwrap(
            NumberFormatter.percentSingle.localizableResource().value(for: locale).stringFromDecimal(
                AssetExchangeCommissionConstants.rate.decimalValue ?? 0
            )
        )
        XCTAssertTrue(disclosure.contains(percentString))
        XCTAssertFalse(disclosure.contains("991500"))
        XCTAssertFalse(disclosure.contains("991,500"))
        XCTAssertFalse(disclosure.contains("8500"))
        XCTAssertFalse(disclosure.contains("8,500"))
    }

    func testStaleQuoteRejectionRefreshesCommission() throws {
        let payAsset = try XCTUnwrap(CommissionTestFixtures.chain.chainAsset(for: 0))
        let receiveAsset = try XCTUnwrap(CommissionTestFixtures.chain.chainAsset(for: 1))

        let (presenter, view, _, _) = makeSetupPresenter(payAsset: payAsset, receiveAsset: receiveAsset)
        presenter.updatePayAmount(1)

        let hydraQuote = try deliverQuote(to: presenter, edgeTypes: [.hydraSwap], amountOut: 1_000_000)
        deliverFee(to: presenter, route: hydraQuote.route, commission: CommissionTestFixtures.makeCommission())

        XCTAssertTrue(presenter.chargesCommission)
        XCTAssertNotNil(view.commissionDisclosureViewModel)

        // the shape a rate-change rejection produces: a fresh quote on a different path delivered
        // for the same quoteArgs the user's typed amount already established
        _ = try deliverQuote(to: presenter, edgeTypes: [.crossChain], amountOut: 1_000_000)

        XCTAssertFalse(presenter.chargesCommission)
        XCTAssertNil(view.commissionDisclosureViewModel)
    }

    func testBuyGrossUpIsWithdrawnWhenFeeSkipsCommission() throws {
        let payAsset = try XCTUnwrap(CommissionTestFixtures.chain.chainAsset(for: 0))
        let receiveAsset = try XCTUnwrap(CommissionTestFixtures.chain.chainAsset(for: 1))

        let (presenter, _, interactor, _) = makeSetupPresenter(payAsset: payAsset, receiveAsset: receiveAsset)
        presenter.updateReceiveAmount(1_000_000_000)

        let grossQuote = try deliverQuote(to: presenter, edgeTypes: [.hydraSwap], amountOut: 1_008_572_870)
        deliverFee(to: presenter, route: grossQuote.route, commission: nil)

        XCTAssertTrue(presenter.suppressCommissionGrossUp)
        XCTAssertEqual(interactor.calculateQuoteCalls.count, 2)
        XCTAssertEqual(interactor.calculateQuoteCalls.last?.grossingUpForCommission, false)
    }

    func testBuyGrossUpWithdrawalDoesNotLoop() throws {
        let payAsset = try XCTUnwrap(CommissionTestFixtures.chain.chainAsset(for: 0))
        let receiveAsset = try XCTUnwrap(CommissionTestFixtures.chain.chainAsset(for: 1))

        let (presenter, _, interactor, _) = makeSetupPresenter(payAsset: payAsset, receiveAsset: receiveAsset)
        presenter.updateReceiveAmount(1_000_000_000)

        let grossQuote = try deliverQuote(to: presenter, edgeTypes: [.hydraSwap], amountOut: 1_008_572_870)
        deliverFee(to: presenter, route: grossQuote.route, commission: nil)

        XCTAssertEqual(interactor.calculateQuoteCalls.count, 2)

        let netQuote = try deliverQuote(to: presenter, edgeTypes: [.hydraSwap], amountOut: 1_000_000_000)
        deliverFee(to: presenter, route: netQuote.route, commission: nil)

        XCTAssertEqual(interactor.calculateQuoteCalls.count, 2)
    }

    func testBuyGrossUpIsRestoredWhenFeeCarriesCommission() throws {
        let payAsset = try XCTUnwrap(CommissionTestFixtures.chain.chainAsset(for: 0))
        let receiveAsset = try XCTUnwrap(CommissionTestFixtures.chain.chainAsset(for: 1))

        let (presenter, _, interactor, _) = makeSetupPresenter(payAsset: payAsset, receiveAsset: receiveAsset)
        presenter.updateReceiveAmount(1_000_000_000)

        let grossQuote = try deliverQuote(to: presenter, edgeTypes: [.hydraSwap], amountOut: 1_008_572_870)
        deliverFee(to: presenter, route: grossQuote.route, commission: nil)

        XCTAssertTrue(presenter.suppressCommissionGrossUp)

        let netQuote = try deliverQuote(to: presenter, edgeTypes: [.hydraSwap], amountOut: 1_000_000_000)
        deliverFee(to: presenter, route: netQuote.route, commission: CommissionTestFixtures.makeCommission())

        XCTAssertEqual(interactor.calculateQuoteCalls.count, 3)
        XCTAssertEqual(interactor.calculateQuoteCalls.last?.grossingUpForCommission, true)
        XCTAssertFalse(presenter.suppressCommissionGrossUp)
    }

    func testBuyGrossUpCorrectionsAreBounded() throws {
        let payAsset = try XCTUnwrap(CommissionTestFixtures.chain.chainAsset(for: 0))
        let receiveAsset = try XCTUnwrap(CommissionTestFixtures.chain.chainAsset(for: 1))

        let (presenter, _, interactor, _) = makeSetupPresenter(payAsset: payAsset, receiveAsset: receiveAsset)
        presenter.updateReceiveAmount(1_000_000_000)

        let grossQuote = try deliverQuote(to: presenter, edgeTypes: [.hydraSwap], amountOut: 1_008_572_870)
        deliverFee(to: presenter, route: grossQuote.route, commission: nil)

        let netQuote = try deliverQuote(to: presenter, edgeTypes: [.hydraSwap], amountOut: 1_000_000_000)
        deliverFee(to: presenter, route: netQuote.route, commission: CommissionTestFixtures.makeCommission())

        XCTAssertEqual(interactor.calculateQuoteCalls.count, 3)

        // a third crossing: the counter is spent at 2, so the alternation terminates here
        let grossQuoteAgain = try deliverQuote(to: presenter, edgeTypes: [.hydraSwap], amountOut: 1_008_572_870)
        deliverFee(to: presenter, route: grossQuoteAgain.route, commission: nil)

        XCTAssertEqual(interactor.calculateQuoteCalls.count, 3)
    }

    func testBuyGrossUpSuppressionClearsOnInputChange() throws {
        let payAsset = try XCTUnwrap(CommissionTestFixtures.chain.chainAsset(for: 0))
        let receiveAsset = try XCTUnwrap(CommissionTestFixtures.chain.chainAsset(for: 1))

        let (presenter, _, interactor, _) = makeSetupPresenter(payAsset: payAsset, receiveAsset: receiveAsset)
        presenter.updateReceiveAmount(1_000_000_000)

        let grossQuote = try deliverQuote(to: presenter, edgeTypes: [.hydraSwap], amountOut: 1_008_572_870)
        deliverFee(to: presenter, route: grossQuote.route, commission: nil)

        XCTAssertTrue(presenter.suppressCommissionGrossUp)

        presenter.updateReceiveAmount(2)

        XCTAssertFalse(presenter.suppressCommissionGrossUp)
        XCTAssertEqual(interactor.calculateQuoteCalls.last?.grossingUpForCommission, true)

        // the counter was reset (not merely left spent), so a fresh suppression/restoration pair
        // can still fire on this new input
        let quoteAfterReset = try deliverQuote(to: presenter, edgeTypes: [.hydraSwap], amountOut: 2)
        deliverFee(to: presenter, route: quoteAfterReset.route, commission: nil)

        XCTAssertTrue(presenter.suppressCommissionGrossUp)
    }

    func testConfirmReceiveAndRateUseNetAmount() throws {
        let payAsset = try XCTUnwrap(CommissionTestFixtures.chain.chainAsset(for: 0))
        let receiveAsset = try XCTUnwrap(CommissionTestFixtures.chain.chainAsset(for: 1))
        let locale = LocalizationManager.shared.selectedLocale

        let (presenter, view, factory, quote) = try makeConfirmPresenter(edgeTypes: [.hydraSwap], amountOut: 1_000_000)
        presenter.setup()
        deliverFee(to: presenter, route: quote.route, commission: CommissionTestFixtures.makeCommission())

        let assetOut = try XCTUnwrap(view.assetOutViewModel)
        let expectedAssetOut = factory.assetViewModel(
            chainAsset: receiveAsset,
            amount: 991_500,
            priceData: nil,
            locale: locale
        ).amount
        XCTAssertEqual(assetOut.amount, expectedAssetOut)

        guard case let .loaded(rate) = view.rateViewModel else {
            XCTFail("expected a loaded rate view model")
            return
        }
        XCTAssertEqual(
            rate,
            expectedRate(
                amountIn: 1_000_000,
                amountOut: 991_500,
                payAsset: payAsset,
                receiveAsset: receiveAsset,
                factory: factory,
                locale: locale
            )
        )

        // the price difference stays on the gross route regardless of commission: compare against
        // an identical run without a commission rather than a canned value, so this holds whether
        // or not price data happens to be configured
        let priceDiffWithCommission = describePriceDifference(view.priceDifferenceViewModel)

        let (noCommissionPresenter, noCommissionView, _, noCommissionQuote) = try makeConfirmPresenter(
            edgeTypes: [.hydraSwap],
            amountOut: 1_000_000
        )
        noCommissionPresenter.setup()
        deliverFee(to: noCommissionPresenter, route: noCommissionQuote.route, commission: nil)

        XCTAssertEqual(priceDiffWithCommission, describePriceDifference(noCommissionView.priceDifferenceViewModel))
    }

    func testConfirmRevertsToGrossWhenFeeSkipsCommission() throws {
        let payAsset = try XCTUnwrap(CommissionTestFixtures.chain.chainAsset(for: 0))
        let receiveAsset = try XCTUnwrap(CommissionTestFixtures.chain.chainAsset(for: 1))
        let locale = LocalizationManager.shared.selectedLocale

        let (presenter, view, factory, quote) = try makeConfirmPresenter(edgeTypes: [.hydraSwap], amountOut: 1_000_000)
        presenter.setup()
        deliverFee(to: presenter, route: quote.route, commission: nil)

        let expectedGrossAssetOut = factory.assetViewModel(
            chainAsset: receiveAsset,
            amount: 1_000_000,
            priceData: nil,
            locale: locale
        ).amount
        XCTAssertEqual(view.assetOutViewModel?.amount, expectedGrossAssetOut)

        guard case let .loaded(rate) = view.rateViewModel else {
            XCTFail("expected a loaded rate view model")
            return
        }
        XCTAssertEqual(
            rate,
            expectedRate(
                amountIn: 1_000_000,
                amountOut: 1_000_000,
                payAsset: payAsset,
                receiveAsset: receiveAsset,
                factory: factory,
                locale: locale
            )
        )

        XCTAssertNil(view.commissionDisclosureViewModel)
    }

    func testConfirmDisclosurePersistsOnFeeFailure() throws {
        let (presenter, view, _, _) = try makeConfirmPresenter(edgeTypes: [.hydraSwap], amountOut: 1_000_000)
        presenter.setup()

        XCTAssertNotNil(view.commissionDisclosureViewModel)
        let assetOutBefore = try XCTUnwrap(view.assetOutViewModel)

        presenter.didReceive(baseError: .fetchFeeFailed(CommonError.dataCorruption, nil))

        XCTAssertNotNil(view.commissionDisclosureViewModel)
        XCTAssertEqual(view.assetOutViewModel?.amount, assetOutBefore.amount)
    }

    func testStaleFeeWithCommissionIsDropped() throws {
        let route = CommissionTestFixtures.createRoute([.hydraSwap], amount: 1_000_000)
        let feeWithCommission = AssetExchangeFee(
            route: route,
            operationFees: [],
            intermediateFeesInAssetIn: 0,
            slippage: BigRational(numerator: 0, denominator: 100),
            feeAssetId: CommissionTestFixtures.asset(0),
            commission: CommissionTestFixtures.makeCommission()
        )

        let exchangeService = StubAssetsExchangeService(
            feeWrappers: [
                CommissionTestFixtures.neverFinishingFeeWrapper(),
                .createWithResult(feeWithCommission)
            ]
        )

        let interactor = CommissionTestFixtures.makeInteractor(exchangeService: exchangeService)
        let output = RecordingSwapBaseInteractorOutput()
        interactor.basePresenter = output

        let expectation = expectation(description: "fee delivered exactly once")
        expectation.expectedFulfillmentCount = 1
        expectation.assertForOverFulfill = true
        output.onReceiveFee = { expectation.fulfill() }

        let feeAsset = try XCTUnwrap(CommissionTestFixtures.chain.chainAsset(for: 0))
        let slippage = BigRational(numerator: 0, denominator: 100)

        interactor.calculateFee(for: route, slippage: slippage, feeAsset: feeAsset)
        interactor.calculateFee(for: route, slippage: slippage, feeAsset: feeAsset)

        wait(for: [expectation], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(output.receivedFees.count, 1)
        XCTAssertEqual(output.receivedFees.first, feeWithCommission)
        XCTAssertEqual(exchangeService.estimateFeeCallCount, 2)
    }
}

private extension SwapBasePresenterCommissionTests {
    func makeSetupPresenter(
        payAsset: ChainAsset,
        receiveAsset: ChainAsset,
        amount: Decimal? = nil,
        direction: AssetConversion.Direction? = nil
    ) -> (
        presenter: SwapSetupPresenter,
        view: RecordingSwapSetupView,
        interactor: RecordingSwapSetupInteractor,
        viewModelFactory: SwapsSetupViewModelFactory
    ) {
        let view = RecordingSwapSetupView()
        let interactor = RecordingSwapSetupInteractor()
        let wireframe = RecordingSwapSetupWireframe()

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())
        let balanceViewModelFactoryFacade = BalanceViewModelFactoryFacade(priceAssetInfoFactory: priceAssetInfoFactory)
        let issuesViewModelFactory = SwapIssueViewModelFactory(balanceViewModelFactoryFacade: balanceViewModelFactoryFacade)
        let priceDiffModelFactory = SwapPriceDifferenceModelFactory(config: .defaultConfig)
        let percentFormatter = NumberFormatter.percentSingle.localizableResource()

        let viewModelFactory = SwapsSetupViewModelFactory(
            balanceViewModelFactoryFacade: balanceViewModelFactoryFacade,
            priceAssetInfoFactory: priceAssetInfoFactory,
            issuesViewModelFactory: issuesViewModelFactory,
            networkViewModelFactory: NetworkViewModelFactory(),
            assetIconViewModelFactory: AssetIconViewModelFactory(),
            priceDifferenceModelFactory: priceDiffModelFactory,
            percentFormatter: percentFormatter
        )

        let dataValidatingFactory = SwapDataValidatorFactory(
            presentable: wireframe,
            balanceViewModelFactoryFacade: balanceViewModelFactoryFacade,
            percentFormatter: percentFormatter
        )

        let presenter = SwapSetupPresenter(
            initState: SwapSetupInitState(
                payChainAsset: payAsset,
                receiveChainAsset: receiveAsset,
                amount: amount,
                direction: direction
            ),
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            priceDiffModelFactory: priceDiffModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            priceStore: StubExchangePriceStore(prices: [:]),
            commissionPolicy: CommissionTestFixtures.createPolicy(beneficiaryFree: 10, minBalance: 1).policy,
            localizationManager: LocalizationManager.shared,
            selectedWallet: AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
            slippageConfig: .defaultConfig,
            logger: Logger.shared
        )

        presenter.view = view
        dataValidatingFactory.view = view

        return (presenter, view, interactor, viewModelFactory)
    }

    @discardableResult
    func deliverQuote(
        to presenter: SwapSetupPresenter,
        edgeTypes: [AssetExchangeEdgeType],
        amountOut: Balance
    ) throws -> AssetExchangeQuote {
        let quoteArgs = try XCTUnwrap(presenter.quoteArgs)
        let route = CommissionTestFixtures.createRoute(edgeTypes, amount: amountOut, direction: quoteArgs.direction)
        let metaOperations = try makeMetaOperations(edgeTypes: edgeTypes, amountOut: amountOut)
        let quote = AssetExchangeQuote(
            route: route,
            metaOperations: metaOperations,
            executionTimes: Array(repeating: 0, count: edgeTypes.count)
        )

        presenter.didReceive(quote: quote, for: quoteArgs)

        return quote
    }

    func makeMetaOperations(
        edgeTypes: [AssetExchangeEdgeType],
        amountOut: Balance
    ) throws -> [AssetExchangeMetaOperationProtocol] {
        try edgeTypes.enumerated().map { index, _ in
            StubMetaOperation(
                assetIn: try XCTUnwrap(CommissionTestFixtures.chain.chainAsset(for: AssetModel.Id(index))),
                assetOut: try XCTUnwrap(CommissionTestFixtures.chain.chainAsset(for: AssetModel.Id(index + 1))),
                amountIn: amountOut,
                amountOut: amountOut
            )
        }
    }
}

private extension SwapBasePresenterCommissionTests {
    func makeConfirmPresenter(
        edgeTypes: [AssetExchangeEdgeType],
        amountOut: Balance
    ) throws -> (
        presenter: SwapConfirmPresenter,
        view: RecordingSwapConfirmView,
        viewModelFactory: SwapDetailsViewModelFactory,
        quote: AssetExchangeQuote
    ) {
        let payAsset = try XCTUnwrap(CommissionTestFixtures.chain.chainAsset(for: 0))
        let receiveAsset = try XCTUnwrap(CommissionTestFixtures.chain.chainAsset(for: AssetModel.Id(edgeTypes.count)))

        let route = CommissionTestFixtures.createRoute(edgeTypes, amount: amountOut)
        let metaOperations = try makeMetaOperations(edgeTypes: edgeTypes, amountOut: amountOut)
        let quote = AssetExchangeQuote(
            route: route,
            metaOperations: metaOperations,
            executionTimes: Array(repeating: 0, count: edgeTypes.count)
        )

        let quoteArgs = AssetConversion.QuoteArgs(
            assetIn: payAsset.chainAssetId,
            assetOut: receiveAsset.chainAssetId,
            amount: amountOut,
            direction: .sell
        )

        let initState = SwapConfirmInitState(
            chainAssetIn: payAsset,
            chainAssetOut: receiveAsset,
            feeChainAsset: payAsset,
            slippage: BigRational(numerator: 0, denominator: 100),
            quote: quote,
            quoteArgs: quoteArgs
        )

        let view = RecordingSwapConfirmView()
        let wireframe = RecordingSwapConfirmWireframe()
        let interactor = RecordingSwapConfirmInteractor()

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())
        let balanceViewModelFactoryFacade = BalanceViewModelFactoryFacade(priceAssetInfoFactory: priceAssetInfoFactory)
        let priceDiffModelFactory = SwapPriceDifferenceModelFactory(config: .defaultConfig)
        let percentFormatter = NumberFormatter.percentSingle.localizableResource()

        let viewModelFactory = SwapDetailsViewModelFactory(
            balanceViewModelFactoryFacade: balanceViewModelFactoryFacade,
            priceAssetInfoFactory: priceAssetInfoFactory,
            networkViewModelFactory: NetworkViewModelFactory(),
            assetIconViewModelFactory: AssetIconViewModelFactory(),
            priceDifferenceModelFactory: priceDiffModelFactory,
            percentFormatter: percentFormatter
        )

        let dataValidatingFactory = SwapDataValidatorFactory(
            presentable: wireframe,
            balanceViewModelFactoryFacade: balanceViewModelFactoryFacade,
            percentFormatter: percentFormatter
        )

        let presenter = SwapConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            initState: initState,
            selectedWallet: AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
            viewModelFactory: viewModelFactory,
            priceDifferenceFactory: priceDiffModelFactory,
            priceStore: StubExchangePriceStore(prices: [:]),
            commissionPolicy: CommissionTestFixtures.createPolicy(beneficiaryFree: 10, minBalance: 1).policy,
            slippageBounds: .init(config: SlippageConfig.defaultConfig),
            dataValidatingFactory: dataValidatingFactory,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        presenter.view = view
        dataValidatingFactory.view = view

        return (presenter, view, viewModelFactory, quote)
    }
}

private extension SwapBasePresenterCommissionTests {
    @discardableResult
    func deliverFee(
        to presenter: SwapBasePresenter,
        route: AssetExchangeRoute,
        commission: AssetExchangeCommission?
    ) -> AssetExchangeFee {
        let fee = AssetExchangeFee(
            route: route,
            operationFees: [],
            intermediateFeesInAssetIn: 0,
            slippage: BigRational(numerator: 0, denominator: 100),
            feeAssetId: CommissionTestFixtures.asset(0),
            commission: commission
        )

        presenter.didReceive(fee: fee, feeChainAssetId: nil)

        return fee
    }

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

    func describeDifferenceModel(_ model: SwapDifferenceModel?) -> String {
        guard let model else {
            return "nil"
        }

        return "\(model.diff):\(model.attention)"
    }

    func expectedAmountInputDisplay(
        _ amount: Balance,
        chainAsset: ChainAsset,
        factory: SwapsSetupViewModelFactoryProtocol,
        locale: Locale
    ) -> String {
        let decimal = amount.decimal(assetInfo: chainAsset.assetDisplayInfo)

        return factory.amountInputViewModel(chainAsset: chainAsset, amount: decimal, locale: locale).displayAmount
    }

    func expectedRate(
        amountIn: Balance,
        amountOut: Balance,
        payAsset: ChainAsset,
        receiveAsset: ChainAsset,
        factory: SwapBaseViewModelFactoryProtocol,
        locale: Locale
    ) -> String {
        factory.rateViewModel(
            from: RateParams(
                assetDisplayInfoIn: payAsset.assetDisplayInfo,
                assetDisplayInfoOut: receiveAsset.assetDisplayInfo,
                amountIn: amountIn,
                amountOut: amountOut
            ),
            locale: locale
        )
    }
}

private final class RecordingSwapSetupView: SwapSetupViewProtocol {
    let isSetup = true
    let controller = UIViewController()

    private(set) var buttonTitle: String?
    private(set) var buttonEnabled: Bool?
    private(set) var payChainAssetViewModel: SwapAssetInputViewModel?
    private(set) var payAmountInputViewModel: AmountInputViewModelProtocol?
    private(set) var payInputPriceViewModel: String?
    private(set) var payTitleViewModel: TitleHorizontalMultiValueView.Model?
    private(set) var receiveChainAssetViewModel: SwapAssetInputViewModel?
    private(set) var receiveAmountInputViewModel: AmountInputViewModelProtocol?
    private(set) var receiveInputPriceViewModel: SwapPriceDifferenceViewModel?
    private(set) var receiveTitleViewModel: TitleHorizontalMultiValueView.Model?
    private(set) var rateViewModel: LoadableViewModelState<String>?
    private(set) var routeViewModel: LoadableViewModelState<[SwapRouteItemView.ItemViewModel]>?
    private(set) var executionTimeViewModel: LoadableViewModelState<String>?
    private(set) var networkFeeViewModel: LoadableViewModelState<NetworkFeeInfoViewModel>?
    private(set) var commissionDisclosureViewModel: String?
    private(set) var detailsStateAvailable: Bool?
    private(set) var settingsStateAvailable: Bool?
    private(set) var issues: [SwapSetupViewIssue]?
    private(set) var focus: TextFieldFocus?
    private(set) var isLoading = false

    func didReceiveButtonState(title: String, enabled: Bool) {
        buttonTitle = title
        buttonEnabled = enabled
    }

    func didReceiveInputChainAsset(payViewModel viewModel: SwapAssetInputViewModel) {
        payChainAssetViewModel = viewModel
    }

    func didReceiveAmount(payInputViewModel inputViewModel: AmountInputViewModelProtocol) {
        payAmountInputViewModel = inputViewModel
    }

    func didReceiveAmountInputPrice(payViewModel: String?) {
        payInputPriceViewModel = payViewModel
    }

    func didReceiveTitle(payViewModel viewModel: TitleHorizontalMultiValueView.Model) {
        payTitleViewModel = viewModel
    }

    func didReceiveInputChainAsset(receiveViewModel viewModel: SwapAssetInputViewModel) {
        receiveChainAssetViewModel = viewModel
    }

    func didReceiveAmount(receiveInputViewModel inputViewModel: AmountInputViewModelProtocol) {
        receiveAmountInputViewModel = inputViewModel
    }

    func didReceiveAmountInputPrice(receiveViewModel: SwapPriceDifferenceViewModel?) {
        receiveInputPriceViewModel = receiveViewModel
    }

    func didReceiveTitle(receiveViewModel viewModel: TitleHorizontalMultiValueView.Model) {
        receiveTitleViewModel = viewModel
    }

    func didReceiveRate(viewModel: LoadableViewModelState<String>) {
        rateViewModel = viewModel
    }

    func didReceiveRoute(viewModel: LoadableViewModelState<[SwapRouteItemView.ItemViewModel]>) {
        routeViewModel = viewModel
    }

    func didReceiveExecutionTime(viewModel: LoadableViewModelState<String>) {
        executionTimeViewModel = viewModel
    }

    func didReceiveNetworkFee(viewModel: LoadableViewModelState<NetworkFeeInfoViewModel>) {
        networkFeeViewModel = viewModel
    }

    func didReceiveCommissionDisclosure(viewModel: String?) {
        commissionDisclosureViewModel = viewModel
    }

    func didReceiveDetailsState(isAvailable: Bool) {
        detailsStateAvailable = isAvailable
    }

    func didReceiveSettingsState(isAvailable: Bool) {
        settingsStateAvailable = isAvailable
    }

    func didReceive(issues: [SwapSetupViewIssue]) {
        self.issues = issues
    }

    func didReceive(focus: TextFieldFocus?) {
        self.focus = focus
    }

    func didStartLoading() {
        isLoading = true
    }

    func didStopLoading() {
        isLoading = false
    }
}

private final class RecordingSwapSetupWireframe: SwapSetupWireframeProtocol {
    func showPayTokenSelection(
        from _: ControllerBackedProtocol?,
        chainAsset _: ChainAsset?,
        completionHandler _: @escaping (ChainAsset) -> Void
    ) {}

    func showReceiveTokenSelection(
        from _: ControllerBackedProtocol?,
        chainAsset _: ChainAsset?,
        completionHandler _: @escaping (ChainAsset) -> Void
    ) {}

    func showSettings(
        from _: ControllerBackedProtocol?,
        percent _: BigRational?,
        chainAsset _: ChainAsset,
        completionHandler _: @escaping (BigRational) -> Void
    ) {}

    func showConfirmation(from _: ControllerBackedProtocol?, initState _: SwapConfirmInitState) {}

    func showGetTokenOptions(
        form _: ControllerBackedProtocol?,
        purchaseHadler _: RampFlowManaging & RampDelegate,
        destinationChainAsset _: ChainAsset,
        locale _: Locale
    ) {}

    func showRouteDetails(from _: ControllerBackedProtocol?, quote _: AssetExchangeQuote, fee _: AssetExchangeFee) {}

    func showFeeDetails(
        from _: ControllerBackedProtocol?,
        operations _: [AssetExchangeMetaOperationProtocol],
        fee _: AssetExchangeFee
    ) {}

    func popTopControllers(from _: ControllerBackedProtocol?, completion _: @escaping () -> Void) {}
}

private final class RecordingSwapSetupInteractor: SwapSetupInteractorInputProtocol {
    private(set) var calculateQuoteCalls: [(args: AssetConversion.QuoteArgs, grossingUpForCommission: Bool)] = []
    private(set) var calculateFeeArgs: [(route: AssetExchangeRoute, slippage: BigRational, feeAsset: ChainAsset)] = []

    func setup() {}

    func calculateQuote(for args: AssetConversion.QuoteArgs, grossingUpForCommission: Bool) {
        calculateQuoteCalls.append((args, grossingUpForCommission))
    }

    func calculateFee(for route: AssetExchangeRoute, slippage: BigRational, feeAsset: ChainAsset) {
        calculateFeeArgs.append((route, slippage, feeAsset))
    }

    func retryAssetBalanceExistenseFetch(for _: ChainAsset) {}

    func requestValidatingQuote(
        for _: AssetConversion.QuoteArgs,
        grossingUpForCommission _: Bool,
        completion _: @escaping (Result<AssetExchangeQuote, Error>) -> Void
    ) {}

    func requestValidatingIntermediateED(
        for _: [AssetExchangeMetaOperationProtocol],
        commission _: AssetExchangeCommission?,
        completion _: @escaping SwapInterEDCheckClosure
    ) {}

    func update(receiveChainAsset _: ChainAsset?) {}
    func update(payChainAsset _: ChainAsset?) {}
    func update(feeChainAsset _: ChainAsset?) {}
}

private final class RecordingSwapConfirmView: SwapConfirmViewProtocol {
    let isSetup = true
    let controller = UIViewController()

    private(set) var assetInViewModel: SwapAssetAmountViewModel?
    private(set) var assetOutViewModel: SwapAssetAmountViewModel?
    private(set) var rateViewModel: LoadableViewModelState<String>?
    private(set) var routeViewModel: LoadableViewModelState<[SwapRouteItemView.ItemViewModel]>?
    private(set) var executionTimeViewModel: LoadableViewModelState<String>?
    private(set) var priceDifferenceViewModel: LoadableViewModelState<DifferenceViewModel>?
    private(set) var slippageViewModel: String?
    private(set) var networkFeeViewModel: LoadableViewModelState<NetworkFeeInfoViewModel>?
    private(set) var commissionDisclosureViewModel: String?
    private(set) var walletViewModel: WalletAccountViewModel?
    private(set) var warningViewModel: String?
    private(set) var isLoading = false

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

    func didReceiveExecutionTime(viewModel: LoadableViewModelState<String>) {
        executionTimeViewModel = viewModel
    }

    func didReceivePriceDifference(viewModel: LoadableViewModelState<DifferenceViewModel>?) {
        priceDifferenceViewModel = viewModel
    }

    func didReceiveSlippage(viewModel: String) {
        slippageViewModel = viewModel
    }

    func didReceiveNetworkFee(viewModel: LoadableViewModelState<NetworkFeeInfoViewModel>) {
        networkFeeViewModel = viewModel
    }

    func didReceiveCommissionDisclosure(viewModel: String?) {
        commissionDisclosureViewModel = viewModel
    }

    func didReceiveWallet(viewModel: WalletAccountViewModel?) {
        walletViewModel = viewModel
    }

    func didReceiveWarning(viewModel: String?) {
        warningViewModel = viewModel
    }

    func didReceiveStartLoading() {
        isLoading = true
    }

    func didReceiveStopLoading() {
        isLoading = false
    }
}

private final class RecordingSwapConfirmWireframe: SwapConfirmWireframeProtocol {
    func showSwapExecution(from _: SwapConfirmViewProtocol?, model _: SwapExecutionModel) {}

    func showRouteDetails(from _: ControllerBackedProtocol?, quote _: AssetExchangeQuote, fee _: AssetExchangeFee) {}

    func showFeeDetails(
        from _: ControllerBackedProtocol?,
        operations _: [AssetExchangeMetaOperationProtocol],
        fee _: AssetExchangeFee
    ) {}
}

private final class RecordingSwapConfirmInteractor: SwapConfirmInteractorInputProtocol {
    func setup() {}
    func calculateQuote(for _: AssetConversion.QuoteArgs, grossingUpForCommission _: Bool) {}
    func calculateFee(for _: AssetExchangeRoute, slippage _: BigRational, feeAsset _: ChainAsset) {}
    func retryAssetBalanceExistenseFetch(for _: ChainAsset) {}

    func requestValidatingQuote(
        for _: AssetConversion.QuoteArgs,
        grossingUpForCommission _: Bool,
        completion _: @escaping (Result<AssetExchangeQuote, Error>) -> Void
    ) {}

    func requestValidatingIntermediateED(
        for _: [AssetExchangeMetaOperationProtocol],
        commission _: AssetExchangeCommission?,
        completion _: @escaping SwapInterEDCheckClosure
    ) {}

    func initiateSwapSubmission(of _: SwapExecutionModel) {}
}

private final class RecordingSwapBaseInteractorOutput: SwapBaseInteractorOutputProtocol {
    private(set) var receivedFees: [AssetExchangeFee] = []
    var onReceiveFee: (() -> Void)?

    func didReceive(quote _: AssetExchangeQuote, for _: AssetConversion.QuoteArgs) {}

    func didReceive(fee: AssetExchangeFee, feeChainAssetId _: ChainAssetId?) {
        receivedFees.append(fee)
        onReceiveFee?()
    }

    func didReceive(baseError _: SwapBaseError) {}
    func didReceive(balance _: AssetBalance?, for _: ChainAssetId) {}
    func didReceiveAssetBalance(existense _: AssetBalanceExistence, chainAssetId _: ChainAssetId) {}
    func didReceive(accountInfo _: AccountInfo?, chainId _: ChainModel.Id) {}
}
