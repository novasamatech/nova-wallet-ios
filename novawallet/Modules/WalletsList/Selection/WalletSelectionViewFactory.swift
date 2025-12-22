import Foundation
import Foundation_iOS

struct WalletSelectionViewFactory {
    static func createView(
        delegatedAccountSyncService: DelegatedAccountSyncServiceProtocol
    ) -> WalletsListViewProtocol? {
        guard let interactor = createInteractor(delegatedAccountSyncService: delegatedAccountSyncService),
              let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let wireframe = WalletSelectionWireframe()

        let localizationManager = LocalizationManager.shared

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let viewModelFactory = WalletsListViewModelFactory(
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            priceAssetInfoFactory: priceAssetInfoFactory,
            currencyManager: currencyManager
        )

        let presenter = WalletSelectionPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = WalletSelectionViewController(presenter: presenter, localizationManager: localizationManager)

        presenter.baseView = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        delegatedAccountSyncService: DelegatedAccountSyncServiceProtocol
    ) -> WalletSelectionInteractor? {
        guard let balancesStore = BalancesStore.createDefault() else {
            return nil
        }

        return WalletSelectionInteractor(
            balancesStore: balancesStore,
            walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactory.shared,
            delegatedAccountSyncService: delegatedAccountSyncService,
            settings: SelectedWalletSettings.shared,
            eventCenter: EventCenter.shared
        )
    }
}
