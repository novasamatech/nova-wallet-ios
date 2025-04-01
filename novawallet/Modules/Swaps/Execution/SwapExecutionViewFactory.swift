import Foundation
import Foundation_iOS

struct SwapExecutionViewFactory {
    static func createView(
        for model: SwapExecutionModel,
        flowState: SwapTokensFlowStateProtocol,
        completionClosure: SwapCompletionClosure?
    ) -> SwapExecutionViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else { return nil }

        let interactor = SwapExecutionInteractor(
            assetsExchangeService: flowState.setupAssetExchangeService(),
            osMediator: OperatingSystemMediator(),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let wireframe = SwapExecutionWireframe(flowState: flowState, completionClosure: completionClosure)

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactoryFacade = BalanceViewModelFactoryFacade(
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let priceDiffModelFactory = SwapPriceDifferenceModelFactory(config: .defaultConfig)
        let percentFormatter = NumberFormatter.percentSingle.localizableResource()

        let detailsViewModelFactory = SwapDetailsViewModelFactory(
            balanceViewModelFactoryFacade: balanceViewModelFactoryFacade,
            priceAssetInfoFactory: priceAssetInfoFactory,
            networkViewModelFactory: NetworkViewModelFactory(),
            assetIconViewModelFactory: AssetIconViewModelFactory(),
            priceDifferenceModelFactory: priceDiffModelFactory,
            percentFormatter: percentFormatter
        )

        let presenter = SwapExecutionPresenter(
            model: model,
            interactor: interactor,
            wireframe: wireframe,
            executionViewModelFactory: SwapExecutionViewModelFactory(),
            detailsViewModelFactory: detailsViewModelFactory,
            priceStore: flowState.priceStore,
            localizationManager: LocalizationManager.shared
        )

        let view = SwapExecutionViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
