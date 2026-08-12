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
        let context = Self.createContext()

        context.deliverSellQuote()

        XCTAssertEqual(context.view.receiveLoadingStates.last, true)
    }

    func testReceiveAmountStopsLoadingWhenUserEntersReceiveAmount() {
        let context = Self.createContext()

        context.deliverSellQuote()

        XCTAssertEqual(context.view.receiveLoadingStates.last, true)

        let inputViewModelsBeforeTyping = context.view.receiveInputViewModels.count

        context.presenter.updateReceiveAmount(2)

        XCTAssertEqual(context.view.receiveLoadingStates.last, false)
        XCTAssertEqual(context.view.receiveInputViewModels.count, inputViewModelsBeforeTyping)
    }

    func testReceiveAmountStopsLoadingWhenQuoteFails() {
        let context = Self.createContext()

        context.deliverSellQuote()

        XCTAssertEqual(context.view.receiveLoadingStates.last, true)

        guard let quoteArgs = context.interactor.lastQuoteArgs else {
            XCTFail("Quote args expected")
            return
        }

        context.presenter.didReceive(baseError: .quote(TestError.quoteFailed, quoteArgs))

        XCTAssertEqual(context.view.receiveLoadingStates.last, false)
    }
}

extension SwapSetupReceiveAmountLoadingTests {
    struct Context {
        let presenter: SwapSetupPresenter
        let view: SwapSetupViewSpy
        let interactor: SwapSetupInteractorStub

        func deliverSellQuote() {
            presenter.updatePayAmount(1)

            guard let quoteArgs = interactor.lastQuoteArgs else {
                XCTFail("Quote args expected")
                return
            }

            let route = CommissionTestFixtures.createRoute([.hydraSwap], amount: 1_000_000_000)

            let quote = AssetExchangeQuote(
                route: route,
                metaOperations: [],
                executionTimes: []
            )

            presenter.didReceive(quote: quote, for: quoteArgs)
        }
    }

    static func createContext() -> Context {
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
            commissionPolicy: SwapCommissionPolicyStub(),
            localizationManager: LocalizationManager.shared,
            selectedWallet: AccountGenerator.generateMetaAccount(),
            slippageConfig: .defaultConfig,
            logger: Logger.shared
        )

        presenter.view = view
        presenter.setup()

        return Context(presenter: presenter, view: view, interactor: interactor)
    }
}

final class SwapSetupViewSpy: SwapSetupViewProtocol {
    let controller = UIViewController()
    let isSetup = true

    private(set) var receiveLoadingStates: [Bool] = []
    private(set) var receiveInputViewModels: [AmountInputViewModelProtocol] = []

    func didReceiveAmount(receiveLoading: Bool) {
        receiveLoadingStates.append(receiveLoading)
    }

    func didReceiveAmount(receiveInputViewModel inputViewModel: AmountInputViewModelProtocol) {
        receiveInputViewModels.append(inputViewModel)
    }

    func didReceiveButtonState(title _: String, enabled _: Bool) {}
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
    private(set) var lastQuoteArgs: AssetConversion.QuoteArgs?

    func calculateQuote(for args: AssetConversion.QuoteArgs) {
        lastQuoteArgs = args
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

final class SwapCommissionPolicyStub: AssetExchangeCommissionPolicyProtocol {
    func netAmount(from grossAmount: Balance, willCharge _: Bool) -> Balance {
        grossAmount
    }

    func hasChargingSite(in _: AssetExchangeGraphPath) -> Bool {
        false
    }

    func resolveCommissionWrapper(
        for _: AssetExchangeRoute
    ) -> CompoundOperationWrapper<AssetExchangeCommission?> {
        .createWithResult(nil)
    }

    func grossingUpAmountOutWrapper(
        _ netAmountOut: Balance,
        for _: AssetExchangeGraphPath
    ) -> CompoundOperationWrapper<Balance> {
        .createWithResult(netAmountOut)
    }
}
