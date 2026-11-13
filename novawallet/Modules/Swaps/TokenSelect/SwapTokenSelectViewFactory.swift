import Foundation
import Foundation_iOS
import Keystore_iOS

enum SwapTokenSelectViewFactory {
    static func createView(
        state: SwapTokensFlowStateProtocol,
        side: SwapTokenSelectionSide,
        context: SwapTokenSelectionContext,
        completion: @escaping (SwapTokenSelectionResult) -> Void
    ) -> SwapTokenSelectViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let interactor = SwapTokenSelectInteractor(
            state: state,
            side: side,
            counterpart: context.counterpart,
            networksStore: SwapTokenSelectNetworksStore(settingsManager: SettingsManager.shared),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)

        let viewModelFactory = SwapTokenSelectViewModelFactory(
            balanceViewModelFactoryFacade: BalanceViewModelFactoryFacade(
                priceAssetInfoFactory: priceAssetInfoFactory
            ),
            networkViewModelFactory: NetworkViewModelFactory(),
            assetIconViewModelFactory: AssetIconViewModelFactory(),
            formattingCache: AssetFormattingCache(factory: AssetBalanceFormatterFactory())
        )

        let presenter = SwapTokenSelectPresenter(
            interactor: interactor,
            wireframe: SwapTokenSelectWireframe(),
            viewModelFactory: viewModelFactory,
            side: side,
            context: context,
            completion: completion,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = SwapTokenSelectViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
