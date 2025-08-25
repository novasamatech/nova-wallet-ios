import Foundation
import Foundation_iOS

enum NotificationWalletListInitialState {
    case modified([Web3Alert.LocalWallet]?)
    case persisted
}

enum NotificationWalletListViewFactory {
    static func createView(
        initState: NotificationWalletListInitialState,
        completion: @escaping ([Web3Alert.LocalWallet]) -> Void
    ) -> NotificationWalletListViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let localizationManager = LocalizationManager.shared
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)

        let viewModelFactory = WalletsListViewModelFactory(
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            priceAssetInfoFactory: priceAssetInfoFactory,
            currencyManager: currencyManager
        )

        let interactor = NotificationWalletListInteractor(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            initialState: initState,
            settingsLocalSubscriptionFactory: SettingsLocalSubscriptionFactory.shared,
            walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactory.shared
        )
        let wireframe = NotificationWalletListWireframe(completion: completion)

        let presenter = NotificationWalletListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localPushSettingsFactory: PushNotificationSettingsFactory(),
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = NotificationWalletListViewController(
            presenter: presenter,

            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
