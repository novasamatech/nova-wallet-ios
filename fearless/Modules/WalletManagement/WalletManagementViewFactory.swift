import Foundation
import SoraFoundation
import RobinHood
import SubstrateSdk
import IrohaCrypto
import SoraKeystore

final class WalletManagementViewFactory: WalletManagementViewFactoryProtocol {
    static func createViewForSettings() -> WalletManagementViewProtocol? {
        let wireframe = WalletManagementWireframe()
        return createView(for: wireframe)
    }

    static func createViewForSwitch() -> WalletManagementViewProtocol? {
        let wireframe = SwitchAccount.WalletManagementWireframe()
        return createView(for: wireframe)
    }

    private static func createView(
        for wireframe: WalletManagementWireframeProtocol
    ) -> WalletManagementViewProtocol? {
        let facade = UserDataStorageFacade.shared
        let mapper = ManagedMetaAccountMapper()

        let observer: CoreDataContextObservable<ManagedMetaAccountModel, CDMetaAccount> =
            CoreDataContextObservable(
                service: facade.databaseService,
                mapper: AnyCoreDataMapper(mapper),
                predicate: { _ in true }
            )

        let repository = AccountRepositoryFactory(storageFacade: facade)
            .createManagedMetaAccountRepository(
                for: nil,
                sortDescriptors: [NSSortDescriptor.accountsByOrder]
            )

        let view = WalletManagementViewController(nib: R.nib.walletManagementViewController)

        let iconGenerator = PolkadotIconGenerator()
        let viewModelFactory = ManagedWalletViewModelFactory(iconGenerator: iconGenerator)

        let presenter = WalletManagementPresenter(
            viewModelFactory: viewModelFactory
        )

        let anyObserver = AnyDataProviderRepositoryObservable(observer)
        let interactor = WalletManagementInteractor(
            repository: AnyDataProviderRepository(repository),
            repositoryObservable: anyObserver,
            settings: SelectedWalletSettings.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            eventCenter: EventCenter.shared
        )

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        view.localizationManager = LocalizationManager.shared

        return view
    }
}
