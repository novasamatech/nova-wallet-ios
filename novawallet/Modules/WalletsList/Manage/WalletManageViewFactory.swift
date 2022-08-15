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
        guard let interactor = createInteractor() else {
            return nil
        }

        let localizationManager = LocalizationManager.shared

        let priceFormatter = AssetBalanceFormatterFactory().createTokenFormatter(for: AssetBalanceDisplayInfo.usd())

        let viewModelFactory = WalletsListViewModelFactory(priceFormatter: priceFormatter)
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
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }
        let facade = UserDataStorageFacade.shared
        let repository = AccountRepositoryFactory(storageFacade: facade).createManagedMetaAccountRepository(
            for: nil,
            sortDescriptors: [NSSortDescriptor.accountsByOrder]
        )

        return WalletManageInteractor(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactory.shared,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            repository: repository,
            currencyManager: currencyManager,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
