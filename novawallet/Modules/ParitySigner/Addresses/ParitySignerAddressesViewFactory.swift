import Foundation
import SubstrateSdk
import Foundation_iOS

struct ParitySignerAddressesViewFactory {
    static func createOnboardingView(
        with walletUpdate: PolkadotVaultWalletUpdate,
        type: ParitySignerType
    ) -> HardwareWalletAddressesViewProtocol? {
        createView(
            with: walletUpdate,
            type: type,
            wireframe: ParitySignerAddressesWireframe()
        )
    }

    static func createAddAccountView(
        with walletUpdate: PolkadotVaultWalletUpdate,
        type: ParitySignerType
    ) -> HardwareWalletAddressesViewProtocol? {
        createView(
            with: walletUpdate,
            type: type,
            wireframe: AddAccount.ParitySignerAddressesWireframe()
        )
    }

    static func createSwitchAccountView(
        with walletUpdate: PolkadotVaultWalletUpdate,
        type: ParitySignerType
    ) -> HardwareWalletAddressesViewProtocol? {
        createView(
            with: walletUpdate,
            type: type,
            wireframe: SwitchAccount.ParitySignerAddressesWireframe()
        )
    }

    private static func createView(
        with walletUpdate: PolkadotVaultWalletUpdate,
        type: ParitySignerType,
        wireframe: ParitySignerAddressesWireframeProtocol
    ) -> HardwareWalletAddressesViewProtocol? {
        let interactor = ParitySignerAddressesInteractor(
            chainRegistry: ChainRegistryFacade.sharedRegistry
        )

        let viewModelFactory = ChainAccountViewModelFactory(iconGenerator: PolkadotIconGenerator())
        let presenter = ParitySignerAddressesPresenter(
            walletUpdate: walletUpdate,
            type: type,
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
