import Foundation
import SoraFoundation

struct SwapExecutionViewFactory {
    static func createView(
        for model: SwapExecutionModel,
        flowState: SwapTokensFlowStateProtocol,
        completionClosure: SwapCompletionClosure?
    ) -> SwapExecutionViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else { return nil }

        let interactor = SwapExecutionInteractor(
            assetsExchangeService: flowState.setupAssetExchangeService(),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let wireframe = SwapExecutionWireframe(flowState: flowState, completionClosure: completionClosure)

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactoryFacade = BalanceViewModelFactoryFacade(
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let detailsViewModelFactory = SwapDetailsViewModelFactory(
            balanceViewModelFactoryFacade: balanceViewModelFactoryFacade,
            priceAssetInfoFactory: priceAssetInfoFactory,
            networkViewModelFactory: NetworkViewModelFactory(),
            assetIconViewModelFactory: AssetIconViewModelFactory(),
            percentForamatter: NumberFormatter.percentSingle.localizableResource(),
            priceDifferenceConfig: .defaultConfig
        )

        let presenter = SwapExecutionPresenter(
            model: model,
            interactor: interactor,
            wireframe: wireframe,
            executionViewModelFactory: SwapExecutionViewModelFactory(),
            detailsViewModelFactory: detailsViewModelFactory,
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
