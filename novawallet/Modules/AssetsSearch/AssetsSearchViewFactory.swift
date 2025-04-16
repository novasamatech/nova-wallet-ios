import Foundation
import Foundation_iOS
import Keystore_iOS

struct AssetsSearchViewFactory {
    static func createView(
        for stateObservable: AssetListModelObservable,
        delegate: AssetsSearchDelegate
    ) -> AssetsSearchViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let interactor = AssetsSearchInteractor(
            stateObservable: stateObservable,
            filter: { $0.chain.syncMode.enabled() },
            settingsManager: SettingsManager.shared,
            logger: Logger.shared
        )

        let wireframe = AssetsSearchWireframe()

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let chainAssetViewModelFactory = ChainAssetViewModelFactory()

        let viewModelFactory = AssetListAssetViewModelFactory(
            chainAssetViewModelFactory: chainAssetViewModelFactory,
            priceAssetInfoFactory: priceAssetInfoFactory,
            assetFormatterFactory: AssetBalanceFormatterFactory(),
            percentFormatter: NumberFormatter.signedPercent.localizableResource(),
            assetIconViewModelFactory: AssetIconViewModelFactory(),
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
