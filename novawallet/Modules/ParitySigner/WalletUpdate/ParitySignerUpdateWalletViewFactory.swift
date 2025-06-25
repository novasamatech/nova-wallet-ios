import Foundation
import Foundation_iOS
import SubstrateSdk

struct ParitySignerUpdateWalletViewFactory {
    static func createView(
        for wallet: MetaAccountModel,
        update: PolkadotVaultWalletUpdate
    ) -> HardwareWalletAddressesViewProtocol? {
        let interactor = createInteractor(for: wallet, update: update)
        let wireframe = ParitySignerUpdateWalletWireframe()

        let viewModelFactory = ChainAccountViewModelFactory(iconGenerator: PolkadotIconGenerator())

        let presenter = ParitySignerAddressesPresenter(
            walletUpdate: update,
            type: .vault,
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = HardwareWalletAddressesViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}

private extension ParitySignerUpdateWalletViewFactory {
    static func createInteractor(
        for wallet: MetaAccountModel,
        update: PolkadotVaultWalletUpdate
    ) -> ParitySignerUpdateWalletInteractor {
        let walletRepository = AccountRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        ).createMetaAccountRepository(for: nil, sortDescriptors: [])

        return ParitySignerUpdateWalletInteractor(
            wallet: wallet,
            walletUpdate: update,
            walletSettings: SelectedWalletSettings.shared,
            walletOperationFactory: ParitySignerWalletOperationFactory(),
            walletRepository: walletRepository,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            eventCenter: EventCenter.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
