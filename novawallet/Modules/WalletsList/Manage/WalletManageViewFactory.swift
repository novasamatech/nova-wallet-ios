import Foundation
import SoraFoundation

final class WalletManageViewFactory {
    static func createViewForAdding() -> WalletManageViewProtocol? {
        let wireframe = WalletManageWireframe()
        return createView(for: wireframe)
    }

    static func createViewForSwitching() -> WalletManageViewProtocol? {
        let wireframe = SwitchAccount.WalletManageWireframe()
        return createView(for: wireframe)
    }

    private static func createView(for wireframe: WalletManageWireframeProtocol) -> WalletManageViewProtocol? {
        guard let interactor = createInteractor(),
              let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let localizationManager = LocalizationManager.shared
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)

        let viewModelFactory = WalletsListViewModelFactory(
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            priceAssetInfoFactory: priceAssetInfoFactory,
            currencyManager: currencyManager
        )
        let presenter = WalletManagePresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = WalletManageViewController(presenter: presenter, localizationManager: localizationManager)

        presenter.baseView = view
        interactor.basePresenter = presenter

        return view
    }

    private static func createInteractor() -> WalletManageInteractor? {
        guard let balancesStore = BalancesStore.createDefault() else {
            return nil
        }

        let facade = UserDataStorageFacade.shared
        let repository = AccountRepositoryFactory(storageFacade: facade).createManagedMetaAccountRepository(
            for: nil,
            sortDescriptors: [NSSortDescriptor.accountsByOrder]
        )

        return WalletManageInteractor(
            balancesStore: balancesStore,
            walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactory.shared,
            repository: repository,
            selectedWalletSettings: SelectedWalletSettings.shared,
            eventCenter: EventCenter.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
