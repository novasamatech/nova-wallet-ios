import XCTest
@testable import novawallet
import Foundation_iOS
import Operation_iOS
import UIKit
import BigInt
import Cuckoo

final class SwapSetupReceiveAmountLoadingTests: XCTestCase {
    enum TestError: Error {
        case quoteFailed
    }

    func testReceiveAmountLoadsWhileCommissionUnresolved() {
        let context = SwapSetupTestContext.make()

        context.deliverSellQuote()

        XCTAssertEqual(context.view.receiveLoadingStates.last, true)
    }

    func testReceiveAmountStopsLoadingWhenUserEntersReceiveAmount() {
        let context = SwapSetupTestContext.make()

        context.deliverSellQuote()

        XCTAssertEqual(context.view.receiveLoadingStates.last, true)

        let inputViewModelsBeforeTyping = context.view.receiveInputViewModels.count

        context.presenter.updateReceiveAmount(2)

        XCTAssertEqual(context.view.receiveLoadingStates.last, false)
        XCTAssertEqual(context.view.receiveInputViewModels.count, inputViewModelsBeforeTyping)
    }

    func testReceiveAmountStopsLoadingWhenQuoteFails() {
        let context = SwapSetupTestContext.make()

        context.deliverSellQuote()

        XCTAssertEqual(context.view.receiveLoadingStates.last, true)

        guard let quoteArgs = context.interactor.lastQuoteArgs else {
            XCTFail("Quote args expected")
            return
        }

        context.presenter.didReceive(baseError: .quote(TestError.quoteFailed, quoteArgs))

        XCTAssertEqual(context.view.receiveLoadingStates.last, false)
    }

    func testReceiveAmountShowsGrossWhenFeeResolvesWithoutCommission() {
        let context = SwapSetupTestContext.make()

        context.deliverSellQuote()

        XCTAssertEqual(context.view.receiveLoadingStates.last, true)

        context.deliverFee(commission: nil)

        XCTAssertEqual(context.view.receiveLoadingStates.last, false)

        XCTAssertEqual(
            context.view.receiveInputViewModels.last?.decimalAmount,
            context.grossAmountOut.decimal(assetInfo: context.receiveChainAsset.asset.displayInfo)
        )
    }

    func testReceiveAmountShowsNetWhenFeeResolvesWithCommission() {
        let context = SwapSetupTestContext.make()

        context.deliverSellQuote()

        XCTAssertEqual(context.view.receiveLoadingStates.last, true)

        let commissionAmount = context.grossAmountOut / 100

        context.deliverFee(
            commission: CommissionTestFixtures.makeCommission(
                chargingOperationIndex: 0,
                estimatedAmount: commissionAmount
            )
        )

        XCTAssertEqual(context.view.receiveLoadingStates.last, false)

        let expectedNetAmountOut = context.grossAmountOut - commissionAmount

        XCTAssertLessThan(expectedNetAmountOut, context.grossAmountOut)

        XCTAssertEqual(
            context.view.receiveInputViewModels.last?.decimalAmount,
            expectedNetAmountOut.decimal(assetInfo: context.receiveChainAsset.asset.displayInfo)
        )
    }

    func testReceiveAmountKeepsPreviousValueUntilFeeMatchesNewQuoteOnSamePath() {
        let context = SwapSetupTestContext.make()

        context.deliverSellQuote()

        let previousCommission = context.grossAmountOut / 100

        context.deliverFee(
            commission: CommissionTestFixtures.makeCommission(
                chargingOperationIndex: 0,
                estimatedAmount: previousCommission
            )
        )

        XCTAssertEqual(context.view.receiveLoadingStates.last, false)

        let settledInputViewModelCount = context.view.receiveInputViewModels.count
        let settledAmount = context.view.receiveInputViewModels.last?.decimalAmount

        XCTAssertEqual(
            settledAmount,
            (context.grossAmountOut - previousCommission).decimal(
                assetInfo: context.receiveChainAsset.asset.displayInfo
            )
        )

        let newGrossAmountOut = context.grossAmountOut * 2
        let newCommission = previousCommission * 2

        context.presenter.updatePayAmount(2)
        context.deliverQuote(amountOut: newGrossAmountOut)

        XCTAssertEqual(context.view.receiveInputViewModels.count, settledInputViewModelCount)
        XCTAssertEqual(context.view.receiveInputViewModels.last?.decimalAmount, settledAmount)
        XCTAssertEqual(context.view.receiveLoadingStates.last, true)

        context.deliverFee(
            commission: CommissionTestFixtures.makeCommission(
                chargingOperationIndex: 0,
                estimatedAmount: newCommission
            ),
            amountOut: newGrossAmountOut
        )

        XCTAssertEqual(context.view.receiveLoadingStates.last, false)
        XCTAssertEqual(context.view.receiveInputViewModels.count, settledInputViewModelCount + 1)

        XCTAssertEqual(
            context.view.receiveInputViewModels.last?.decimalAmount,
            (newGrossAmountOut - newCommission).decimal(
                assetInfo: context.receiveChainAsset.asset.displayInfo
            )
        )
    }

    func testButtonShowsEnterAmountWhenPayAmountIsZero() {
        let context = SwapSetupTestContext.make()

        let locale = LocalizationManager.shared.selectedLocale
        let enterAmountTitle = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.swapsSetupAssetActionEnterAmount()

        context.deliverPayBalance(transferable: context.payAmountInPlank(10))

        context.presenter.updatePayAmount(0)

        XCTAssertEqual(context.view.buttonStates.last?.title, enterAmountTitle)
        XCTAssertEqual(context.view.buttonStates.last?.enabled, false)
    }

    func testButtonStaysContinueStateWhileFeeResolvesForInitialQuote() {
        let context = SwapSetupTestContext.make()

        let locale = LocalizationManager.shared.selectedLocale
        let continueTitle = R.string(preferredLanguages: locale.rLanguages).localizable.commonContinue()
        let enterAmountTitle = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.swapsSetupAssetActionEnterAmount()

        context.deliverPayBalance(transferable: context.payAmountInPlank(10))

        let stateCountBeforeTyping = context.view.buttonStates.count

        context.deliverSellQuote()

        let statesWhileFeeResolves = context.view.buttonStates.suffix(from: stateCountBeforeTyping)

        XCTAssertEqual(context.view.receiveLoadingStates.last, true)
        XCTAssertFalse(statesWhileFeeResolves.isEmpty)
        XCTAssertFalse(statesWhileFeeResolves.contains { $0.title == enterAmountTitle })
        XCTAssertEqual(context.view.buttonStates.last?.title, continueTitle)
        XCTAssertEqual(context.view.buttonStates.last?.enabled, true)
    }

    func testButtonKeepsContinueStateWhileFeeResolvesForNewQuote() {
        let context = SwapSetupTestContext.make()

        let locale = LocalizationManager.shared.selectedLocale
        let continueTitle = R.string(preferredLanguages: locale.rLanguages).localizable.commonContinue()
        let enterAmountTitle = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.swapsSetupAssetActionEnterAmount()

        context.deliverPayBalance(transferable: context.payAmountInPlank(10))
        context.deliverSellQuote()

        context.deliverFee(
            commission: CommissionTestFixtures.makeCommission(
                chargingOperationIndex: 0,
                estimatedAmount: context.grossAmountOut / 100
            )
        )

        XCTAssertEqual(context.view.buttonStates.last?.title, continueTitle)
        XCTAssertEqual(context.view.buttonStates.last?.enabled, true)

        let settledStateCount = context.view.buttonStates.count

        context.presenter.updatePayAmount(2)
        context.deliverQuote(amountOut: context.grossAmountOut * 2)

        let statesWhileFeeResolves = context.view.buttonStates.suffix(from: settledStateCount)

        XCTAssertFalse(statesWhileFeeResolves.isEmpty)
        XCTAssertFalse(statesWhileFeeResolves.contains { $0.title == enterAmountTitle })
        XCTAssertTrue(statesWhileFeeResolves.allSatisfy { $0.title == continueTitle && $0.enabled })
    }
}

struct SwapSetupTestContext {
    let presenter: SwapSetupPresenter
    let view: MockSwapSetupViewProtocol
    let interactor: MockSwapSetupInteractorInputProtocol
    let payChainAsset: ChainAsset
    let receiveChainAsset: ChainAsset
    let path: AssetExchangeGraphPath

    var grossAmountOut: Balance {
        Decimal(1).toSubstrateAmount(
            precision: receiveChainAsset.assetDisplayInfo.assetPrecision
        ) ?? 0
    }

    func makeRoute(amountOut: Balance) -> AssetExchangeRoute {
        let items = path.map {
            AssetExchangeRouteItem(edge: $0, amount: amountOut, quote: amountOut)
        }

        return AssetExchangeRoute(items: items, amount: amountOut, direction: .sell)
    }

    func payAmountInPlank(_ amount: Decimal) -> Balance {
        amount.toSubstrateAmount(
            precision: payChainAsset.assetDisplayInfo.assetPrecision
        ) ?? 0
    }

    func deliverPayBalance(transferable: Balance) {
        let balance = AssetBalance(
            chainAssetId: payChainAsset.chainAssetId,
            accountId: AccountId.zeroAccountId(of: 32),
            freeInPlank: transferable,
            reservedInPlank: 0,
            frozenInPlank: 0,
            edCountMode: .basedOnFree,
            transferrableMode: .regular,
            blocked: false
        )

        presenter.didReceive(balance: balance, for: payChainAsset.chainAssetId)
    }

    func deliverQuote() {
        deliverQuote(amountOut: grossAmountOut)
    }

    func deliverQuote(amountOut: Balance) {
        guard let quoteArgs = interactor.lastQuoteArgs else {
            XCTFail("Quote args expected")
            return
        }

        let quote = AssetExchangeQuote(
            route: makeRoute(amountOut: amountOut),
            metaOperations: [
                CommissionTestFixtures.metaOperation(
                    amountIn: amountOut,
                    amountOut: amountOut
                )
            ],
            executionTimes: []
        )

        presenter.didReceive(quote: quote, for: quoteArgs)
    }

    func deliverSellQuote() {
        presenter.updatePayAmount(1)

        deliverQuote()
    }

    func deliverFee(commission: AssetExchangeCommission?) {
        deliverFee(commission: commission, amountOut: grossAmountOut)
    }

    func deliverFee(commission: AssetExchangeCommission?, amountOut: Balance) {
        deliverFee(operationFees: [], commission: commission, amountOut: amountOut)
    }

    func deliverFee(submissionAmount: Balance, in asset: ChainAssetId) {
        let operationFee = AssetExchangeOperationFee(
            submissionFee: .init(
                amountWithAsset: .init(amount: submissionAmount, asset: asset),
                payer: nil,
                weight: .init(refTime: 0, proofSize: 0)
            ),
            postSubmissionFee: .init(paidByAccount: [], paidFromAmount: [])
        )

        deliverFee(operationFees: [operationFee], commission: nil, amountOut: grossAmountOut)
    }

    private func deliverFee(
        operationFees: [AssetExchangeOperationFee],
        commission: AssetExchangeCommission?,
        amountOut: Balance
    ) {
        let fee = AssetExchangeFee(
            route: makeRoute(amountOut: amountOut),
            operationFees: operationFees,
            intermediateFeesInAssetIn: 0,
            slippage: BigRational(numerator: 0, denominator: 100),
            feeAssetId: CommissionTestFixtures.asset(0),
            commission: commission
        )

        presenter.didReceive(fee: fee, feeChainAssetId: fee.feeAssetId)
    }

    static func make() -> SwapSetupTestContext {
        let chain = CommissionTestFixtures.chain
        let assets = chain.assets.sorted { $0.assetId < $1.assetId }

        let payChainAsset = ChainAsset(chain: chain, asset: assets[0])
        let receiveChainAsset = ChainAsset(chain: chain, asset: assets[1])

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())
        let balanceViewModelFactoryFacade = BalanceViewModelFactoryFacade(
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let priceDiffModelFactory = SwapPriceDifferenceModelFactory(config: .defaultConfig)
        let percentFormatter = NumberFormatter.percentSingle.localizableResource()

        let viewModelFactory = SwapsSetupViewModelFactory(
            balanceViewModelFactoryFacade: balanceViewModelFactoryFacade,
            priceAssetInfoFactory: priceAssetInfoFactory,
            issuesViewModelFactory: SwapIssueViewModelFactory(
                balanceViewModelFactoryFacade: balanceViewModelFactoryFacade
            ),
            networkViewModelFactory: NetworkViewModelFactory(),
            assetIconViewModelFactory: AssetIconViewModelFactory(),
            priceDifferenceModelFactory: priceDiffModelFactory,
            percentFormatter: percentFormatter
        )

        let wireframe = makeWireframe()

        let dataValidatingFactory = SwapDataValidatorFactory(
            presentable: wireframe,
            balanceViewModelFactoryFacade: balanceViewModelFactoryFacade,
            percentFormatter: percentFormatter
        )

        let interactor = makeInteractor()
        let view = makeView()

        let presenter = SwapSetupPresenter(
            initState: .init(
                payChainAsset: payChainAsset,
                receiveChainAsset: receiveChainAsset,
                feeChainAsset: payChainAsset
            ),
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            priceDiffModelFactory: priceDiffModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            priceStore: makePriceStore(),
            localizationManager: LocalizationManager.shared,
            selectedWallet: AccountGenerator.generateMetaAccount(),
            slippageConfig: .defaultConfig,
            logger: Logger.shared
        )

        presenter.view = view
        presenter.setup()

        return SwapSetupTestContext(
            presenter: presenter,
            view: view,
            interactor: interactor,
            payChainAsset: payChainAsset,
            receiveChainAsset: receiveChainAsset,
            path: CommissionTestFixtures.createPath([.hydraSwap])
        )
    }
}

extension SwapSetupTestContext {
    static func makeView() -> MockSwapSetupViewProtocol {
        let view = MockSwapSetupViewProtocol()

        stub(view) { stub in
            stub.isSetup.get.thenReturn(true)
            stub.controller.get.thenReturn(UIViewController())
            stub.didReceiveButtonState(title: any(), enabled: any()).thenDoNothing()
            stub.didReceiveInputChainAsset(payViewModel: any()).thenDoNothing()
            stub.didReceiveAmount(payInputViewModel: any()).thenDoNothing()
            stub.didReceiveAmountInputPrice(payViewModel: any()).thenDoNothing()
            stub.didReceiveTitle(payViewModel: any()).thenDoNothing()
            stub.didReceiveInputChainAsset(receiveViewModel: any()).thenDoNothing()
            stub.didReceiveAmount(receiveInputViewModel: any()).thenDoNothing()
            stub.didReceiveAmount(receiveLoading: any()).thenDoNothing()
            stub.didReceiveAmountInputPrice(receiveViewModel: any()).thenDoNothing()
            stub.didReceiveTitle(receiveViewModel: any()).thenDoNothing()
            stub.didReceiveRate(viewModel: any()).thenDoNothing()
            stub.didReceiveRoute(viewModel: any()).thenDoNothing()
            stub.didReceiveExecutionTime(viewModel: any()).thenDoNothing()
            stub.didReceiveNetworkFee(viewModel: any()).thenDoNothing()
            stub.didReceiveCommissionDisclosure(viewModel: any()).thenDoNothing()
            stub.didReceiveDetailsState(isAvailable: any()).thenDoNothing()
            stub.didReceiveSettingsState(isAvailable: any()).thenDoNothing()
            stub.didReceive(issues: any()).thenDoNothing()
            stub.didReceive(focus: any()).thenDoNothing()
            stub.didStartLoading().thenDoNothing()
            stub.didStopLoading().thenDoNothing()
        }

        return view
    }

    static func makeInteractor() -> MockSwapSetupInteractorInputProtocol {
        let interactor = MockSwapSetupInteractorInputProtocol()

        stub(interactor) { stub in
            stub.setup().thenDoNothing()
            stub.calculateQuote(for: any()).thenDoNothing()
            stub.calculateFee(for: any(), slippage: any(), feeAsset: any()).thenDoNothing()
            stub.retryAssetBalanceExistenseFetch(for: any()).thenDoNothing()
            stub.requestValidatingQuote(for: any(), completion: any()).thenDoNothing()
            stub.requestValidatingIntermediateED(
                for: any(),
                commission: any(),
                slippage: any(),
                direction: any(),
                completion: any()
            ).thenDoNothing()
            stub.update(receiveChainAsset: any()).thenDoNothing()
            stub.update(payChainAsset: any()).thenDoNothing()
            stub.update(feeChainAsset: any()).thenDoNothing()
        }

        return interactor
    }

    static func makeWireframe() -> MockSwapSetupWireframeProtocol {
        let wireframe = MockSwapSetupWireframeProtocol()

        stub(wireframe) { stub in
            stub.showPayTokenSelection(from: any(), chainAsset: any(), completionHandler: any()).thenDoNothing()
            stub.showReceiveTokenSelection(from: any(), chainAsset: any(), completionHandler: any()).thenDoNothing()
            stub.showSettings(
                from: any(),
                percent: any(),
                chainAsset: any(),
                completionHandler: any()
            ).thenDoNothing()
            stub.showInfo(from: any(), title: any(), details: any()).thenDoNothing()
            stub.showConfirmation(from: any(), initState: any()).thenDoNothing()
            stub.showGetTokenOptions(
                form: any(),
                purchaseHadler: any(),
                destinationChainAsset: any(),
                locale: any()
            ).thenDoNothing()
            stub.showRouteDetails(from: any(), quote: any(), fee: any()).thenDoNothing()
            stub.showFeeDetails(from: any(), operations: any(), fee: any()).thenDoNothing()
            stub.popTopControllers(from: any(), completion: any()).thenDoNothing()
            stub.present(message: any(), title: any(), closeAction: any(), from: any()).thenDoNothing()
            stub.present(viewModel: any(), style: any(), from: any()).thenDoNothing()
        }

        return wireframe
    }

    static func makePriceStore() -> MockAssetExchangePriceStoring {
        let priceStore = MockAssetExchangePriceStoring()

        stub(priceStore) { stub in
            stub.getCurrencyId().thenReturn(nil)
            stub.fetchPrice(for: any()).thenReturn(nil)
        }

        return priceStore
    }
}

extension MockSwapSetupViewProtocol {
    var receiveLoadingStates: [Bool] {
        let captor = ArgumentCaptor<Bool>()

        verify(self, atLeast(0)).didReceiveAmount(receiveLoading: captor.capture())

        return captor.allValues
    }

    var receiveInputViewModels: [AmountInputViewModelProtocol] {
        let captor = ArgumentCaptor<AmountInputViewModelProtocol>()

        verify(self, atLeast(0)).didReceiveAmount(receiveInputViewModel: captor.capture())

        return captor.allValues
    }

    var buttonStates: [(title: String, enabled: Bool)] {
        let titleCaptor = ArgumentCaptor<String>()
        let enabledCaptor = ArgumentCaptor<Bool>()

        verify(self, atLeast(0)).didReceiveButtonState(
            title: titleCaptor.capture(),
            enabled: enabledCaptor.capture()
        )

        return zip(titleCaptor.allValues, enabledCaptor.allValues).map { title, enabled in
            (title: title, enabled: enabled)
        }
    }
}

extension MockSwapSetupInteractorInputProtocol {
    var quoteRequests: [AssetConversion.QuoteArgs] {
        let captor = ArgumentCaptor<AssetConversion.QuoteArgs>()

        verify(self, atLeast(0)).calculateQuote(for: captor.capture())

        return captor.allValues
    }

    var lastQuoteArgs: AssetConversion.QuoteArgs? {
        quoteRequests.last
    }
}
