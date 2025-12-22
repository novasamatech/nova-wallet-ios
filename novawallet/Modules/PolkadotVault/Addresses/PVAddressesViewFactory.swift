import Foundation
import SubstrateSdk
import Foundation_iOS

struct PVAddressesViewFactory {
    static func createOnboardingView(
        with accountScan: PolkadotVaultAccount,
        type: ParitySignerType
    ) -> HardwareWalletAddressesViewProtocol? {
        createView(
            with: accountScan,
            type: type,
            wireframe: PVAddressesWireframe()
        )
    }

    static func createAddAccountView(
        with accountScan: PolkadotVaultAccount,
        type: ParitySignerType
    ) -> HardwareWalletAddressesViewProtocol? {
        createView(
            with: accountScan,
            type: type,
            wireframe: AddAccount.PVAddressesWireframe()
        )
    }

    static func createSwitchAccountView(
        with accountScan: PolkadotVaultAccount,
        type: ParitySignerType
    ) -> HardwareWalletAddressesViewProtocol? {
        createView(
            with: accountScan,
            type: type,
            wireframe: SwitchAccount.PVAddressesWireframe()
        )
    }

    private static func createView(
        with account: PolkadotVaultAccount,
        type: ParitySignerType,
        wireframe: PVAddressesWireframeProtocol
    ) -> HardwareWalletAddressesViewProtocol? {
        let interactor = PVAddressesInteractor(
            account: account,
            chainRegistry: ChainRegistryFacade.sharedRegistry
        )

        let viewModelFactory = ChainAccountViewModelFactory(iconGenerator: PolkadotIconGenerator())
        let presenter = PVAddressesPresenter(
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
