import XCTest
@testable import novawallet
import Foundation_iOS
import Operation_iOS
import UIKit
import BigInt

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
    let view: SwapSetupViewSpy
    let interactor: SwapSetupInteractorStub
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

        let wireframe = SwapSetupWireframeStub()

        let dataValidatingFactory = SwapDataValidatorFactory(
            presentable: wireframe,
            balanceViewModelFactoryFacade: balanceViewModelFactoryFacade,
            percentFormatter: percentFormatter
        )

        let interactor = SwapSetupInteractorStub()
        let view = SwapSetupViewSpy()

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
            priceStore: SwapExchangePriceStoreStub(),
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

final class SwapSetupViewSpy: SwapSetupViewProtocol {
    let controller = UIViewController()
    let isSetup = true

    private(set) var receiveLoadingStates: [Bool] = []
    private(set) var receiveInputViewModels: [AmountInputViewModelProtocol] = []
    private(set) var buttonStates: [(title: String, enabled: Bool)] = []

    func didReceiveAmount(receiveLoading: Bool) {
        receiveLoadingStates.append(receiveLoading)
    }

    func didReceiveAmount(receiveInputViewModel inputViewModel: AmountInputViewModelProtocol) {
        receiveInputViewModels.append(inputViewModel)
    }

    func didReceiveButtonState(title: String, enabled: Bool) {
        buttonStates.append((title: title, enabled: enabled))
    }

    func didReceiveInputChainAsset(payViewModel _: SwapAssetInputViewModel) {}
    func didReceiveAmount(payInputViewModel _: AmountInputViewModelProtocol) {}
    func didReceiveAmountInputPrice(payViewModel _: String?) {}
    func didReceiveTitle(payViewModel _: TitleHorizontalMultiValueView.Model) {}
    func didReceiveInputChainAsset(receiveViewModel _: SwapAssetInputViewModel) {}
    func didReceiveAmountInputPrice(receiveViewModel _: SwapPriceDifferenceViewModel?) {}
    func didReceiveTitle(receiveViewModel _: TitleHorizontalMultiValueView.Model) {}
    func didReceiveRate(viewModel _: LoadableViewModelState<String>) {}
    func didReceiveRoute(viewModel _: LoadableViewModelState<[SwapRouteItemView.ItemViewModel]>) {}
    func didReceiveExecutionTime(viewModel _: LoadableViewModelState<String>) {}
    func didReceiveNetworkFee(viewModel _: LoadableViewModelState<NetworkFeeInfoViewModel>) {}
    func didReceiveCommissionDisclosure(viewModel _: String?) {}
    func didReceiveDetailsState(isAvailable _: Bool) {}
    func didReceiveSettingsState(isAvailable _: Bool) {}
    func didReceive(issues _: [SwapSetupViewIssue]) {}
    func didReceive(focus _: TextFieldFocus?) {}
    func didStartLoading() {}
    func didStopLoading() {}
}

final class SwapSetupInteractorStub: SwapSetupInteractorInputProtocol {
    private(set) var quoteRequests: [AssetConversion.QuoteArgs] = []

    var lastQuoteArgs: AssetConversion.QuoteArgs? {
        quoteRequests.last
    }

    func calculateQuote(for args: AssetConversion.QuoteArgs) {
        quoteRequests.append(args)
    }

    func setup() {}
    func calculateFee(for _: AssetExchangeRoute, slippage _: BigRational, feeAsset _: ChainAsset) {}
    func retryAssetBalanceExistenseFetch(for _: ChainAsset) {}

    func requestValidatingQuote(
        for _: AssetConversion.QuoteArgs,
        completion _: @escaping (Result<AssetExchangeQuote, Error>) -> Void
    ) {}

    func requestValidatingIntermediateED(
        for _: [AssetExchangeMetaOperationProtocol],
        commission _: AssetExchangeCommission?,
        slippage _: BigRational,
        direction _: AssetConversion.Direction,
        completion _: @escaping SwapInterEDCheckClosure
    ) {}

    func update(receiveChainAsset _: ChainAsset?) {}
    func update(payChainAsset _: ChainAsset?) {}
    func update(feeChainAsset _: ChainAsset?) {}
}

final class SwapSetupWireframeStub: SwapSetupWireframeProtocol {
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

    func showConfirmation(
        from _: ControllerBackedProtocol?,
        initState _: SwapConfirmInitState
    ) {}

    func showGetTokenOptions(
        form _: ControllerBackedProtocol?,
        purchaseHadler _: RampFlowManaging & RampDelegate,
        destinationChainAsset _: ChainAsset,
        locale _: Locale
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

    func popTopControllers(
        from _: ControllerBackedProtocol?,
        completion _: @escaping () -> Void
    ) {}
}

final class SwapExchangePriceStoreStub: AssetExchangePriceStoring {
    func getCurrencyId() -> Int? { nil }
    func fetchPrice(for _: ChainAssetId) -> PriceData? { nil }
}
