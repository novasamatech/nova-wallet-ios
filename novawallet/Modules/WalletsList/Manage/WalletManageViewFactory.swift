import Foundation
import Foundation_iOS

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

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let walletStorageCleaner = WalletStorageCleanerFactory.createWalletStorageCleaner(
            using: operationQueue
        )

        let walletUpdateMediator = WalletUpdateMediator(
            selectedWalletSettings: SelectedWalletSettings.shared,
            repository: repository,
            walletsCleaner: walletStorageCleaner,
            operationQueue: operationQueue
        )

        return WalletManageInteractor(
            cloudBackupSyncService: CloudBackupSyncMediatorFacade.sharedMediator.syncService,
            balancesStore: balancesStore,
            walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactory.shared,
            walletUpdateMediator: walletUpdateMediator,
            eventCenter: EventCenter.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )
    }
}
