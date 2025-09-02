import Foundation
import Foundation_iOS

struct DAppWalletAuthViewFactory {
    static func createWalletConnectView(
        for request: DAppAuthRequest,
        delegate: DAppAuthDelegate
    ) -> DAppWalletAuthViewProtocol? {
        let title = LocalizableResource { locale in
            R.string.localizable.commonWalletConnect(preferredLanguages: locale.rLanguages)
        }

        return createView(for: request, delegate: delegate, title: title)
    }

    static func createView(
        for request: DAppAuthRequest,
        delegate: DAppAuthDelegate,
        title: LocalizableResource<String>
    ) -> DAppWalletAuthViewProtocol? {
        guard
            let currencyManager = CurrencyManager.shared,
            let interactor = createInteractor() else {
            return nil
        }

        let wireframe = DAppWalletAuthWireframe()

        let localizationManager = LocalizationManager.shared

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)

        let fiatViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: priceAssetInfoFactory.createAssetBalanceDisplayInfo(from: nil),
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let viewModelFactory = DAppWalletAuthViewModelFactory(fiatBalanceInfoFactory: fiatViewModelFactory)

        let presenter = DAppWalletAuthPresenter(
            request: request,
            delegate: delegate,
            viewModelFactory: viewModelFactory,
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = DAppWalletAuthViewController(
            title: title,
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor() -> DAppWalletAuthInteractor? {
        guard let balancesStore = BalancesStore.createDefault() else {
            return nil
        }

        return .init(balancesStore: balancesStore)
    }
}
