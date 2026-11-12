import Foundation
import Foundation_iOS
import Operation_iOS
import NovaAnalytics
import Keystore_iOS

struct SwapSetupViewFactory {
    static func createView(
        state: SwapTokensFlowStateProtocol,
        payChainAsset: ChainAsset,
        source: SwapSource,
        swapCompletionClosure: SwapCompletionClosure?
    ) -> SwapSetupViewProtocol? {
        createView(
            state: state,
            initState: .init(payChainAsset: payChainAsset),
            source: source,
            swapCompletionClosure: swapCompletionClosure
        )
    }

    static func createView(
        state: SwapTokensFlowStateProtocol,
        initState: SwapSetupInitState,
        source: SwapSource,
        swapCompletionClosure: SwapCompletionClosure?
    ) -> SwapSetupViewProtocol? {
        let flowHandler = SwapExecutionPresentedFlowHandler(
            flowState: state,
            completionClosure: swapCompletionClosure
        )

        let view = createView(
            state: state,
            initState: initState,
            source: source,
            placement: .flow,
            flowHandler: flowHandler
        )

        flowHandler.formView = view

        return view
    }

    static func createView(
        state: SwapTokensFlowStateProtocol,
        initState: SwapSetupInitState,
        source: SwapSource,
        placement: SwapSetupPlacement,
        flowHandler: SwapExecutionFlowHandling
    ) -> SwapSetupViewProtocol? {
        guard
            let currencyManager = CurrencyManager.shared,
            let selectedWallet = SelectedWalletSettings.shared.value else {
            return nil
        }

        let priceInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactoryFacade = BalanceViewModelFactoryFacade(priceAssetInfoFactory: priceInfoFactory)

        guard let interactor = createInteractor(for: state) else { return nil }

        let wireframe = createWireframe(state: state, flowHandler: flowHandler)

        let priceDiffModelFactory = SwapPriceDifferenceModelFactory(config: .defaultConfig)
        let percentFormatter = NumberFormatter.percentSingle.localizableResource()

        let viewModelFactory = createViewModelFactory(
            balanceViewModelFactoryFacade: balanceViewModelFactoryFacade,
            priceInfoFactory: priceInfoFactory,
            priceDiffModelFactory: priceDiffModelFactory,
            percentFormatter: percentFormatter
        )

        let dataValidatingFactory = SwapDataValidatorFactory(
            presentable: wireframe,
            balanceViewModelFactoryFacade: balanceViewModelFactoryFacade,
            percentFormatter: percentFormatter
        )

        let presenter = SwapSetupPresenter(
            initState: initState,
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            priceDiffModelFactory: priceDiffModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            priceStore: state.priceStore,
            localizationManager: LocalizationManager.shared,
            selectedWallet: selectedWallet,
            slippageConfig: .defaultConfig,
            source: source,
            placement: placement,
            logger: Logger.shared
        )

        guard let chartView = createChartView(for: presenter) else { return nil }

        let view = SwapSetupViewController(
            presenter: presenter,
            chartViewProvider: chartView,
            placement: placement,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.basePresenter = presenter
        dataValidatingFactory.view = view

        return view
    }

    private static func createWireframe(
        state: SwapTokensFlowStateProtocol,
        flowHandler: SwapExecutionFlowHandling
    ) -> SwapSetupWireframe {
        SwapSetupWireframe(
            state: state,
            tokenSelectionFlow: SwapAssetsOperationTokenSelectionFlow(state: state),
            flowHandler: flowHandler
        )
    }

    private static func createViewModelFactory(
        balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol,
        priceInfoFactory: PriceAssetInfoFactoryProtocol,
        priceDiffModelFactory: SwapPriceDifferenceModelFactoryProtocol,
        percentFormatter: LocalizableResource<NumberFormatter>
    ) -> SwapsSetupViewModelFactory {
        let issuesViewModelFactory = SwapIssueViewModelFactory(
            balanceViewModelFactoryFacade: balanceViewModelFactoryFacade
        )

        return SwapsSetupViewModelFactory(
            balanceViewModelFactoryFacade: balanceViewModelFactoryFacade,
            priceAssetInfoFactory: priceInfoFactory,
            issuesViewModelFactory: issuesViewModelFactory,
            networkViewModelFactory: NetworkViewModelFactory(),
            assetIconViewModelFactory: AssetIconViewModelFactory(),
            priceDifferenceModelFactory: priceDiffModelFactory,
            percentFormatter: percentFormatter
        )
    }

    private static func createInteractor(for flowState: SwapTokensFlowStateProtocol) -> SwapSetupInteractor? {
        guard let currencyManager = CurrencyManager.shared,
              let selectedWallet = SelectedWalletSettings.shared.value else {
            return nil
        }

        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let assetStorageFactory = AssetStorageInfoOperationFactory(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )

        let interactor = SwapSetupInteractor(
            state: flowState,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            assetStorageFactory: assetStorageFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            storageRepository: SubstrateRepositoryFactory().createChainStorageItemRepository(),
            settingsManager: SettingsManager.shared,
            chartSession: SwapPriceChartSession.shared,
            currencyManager: currencyManager,
            selectedWallet: selectedWallet,
            operationQueue: operationQueue,
            logger: Logger.shared
        )

        return interactor
    }

    private static func createChartView(for presenter: SwapSetupPresenter) -> AssetPriceChartCompactProviderProtocol? {
        guard let currencyManager = CurrencyManager.shared else { return nil }

        let params = AssetPriceChartViewFactory.Params(
            asset: nil,
            periods: [.day, .week, .month, .year, .allTime],
            selectedPeriod: SwapPriceChartSession.shared.selectedPeriod,
            placeholder: LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.swapsSetupChartPlaceholder()
            },
            locale: LocalizationManager.shared.selectedLocale,
            currency: currencyManager.selectedCurrency
        )

        return AssetPriceChartViewFactory.createCompactView(
            output: presenter,
            inputOwner: presenter,
            params: params
        )
    }
}
