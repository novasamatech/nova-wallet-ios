import Foundation
import SoraFoundation

struct AssetsSearchViewFactory {
    static func createView(
        for stateObservable: AssetListStateObservable,
        delegate: AssetsSearchDelegate
    ) -> AssetsSearchViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let interactor = AssetsSearchInteractor(
            stateObservable: stateObservable,
            filter: nil,
            logger: Logger.shared
        )

        let wireframe = AssetsSearchWireframe()

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let viewModelFactory = AssetListAssetViewModelFactory(
            priceAssetInfoFactory: priceAssetInfoFactory,
            assetFormatterFactory: AssetBalanceFormatterFactory(),
            percentFormatter: NumberFormatter.signedPercent.localizableResource(),
            currencyManager: currencyManager
        )

        let presenter = AssetsSearchPresenter(
            delegate: delegate,
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared
        )

        let view = AssetsSearchViewController(
            presenter: presenter,
            keyboardAppearanceStrategy: EventDrivenKeyboardStrategy(events: [.viewWillAppear]),
            createViewClosure: { AssetsSearchViewLayout() },
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
