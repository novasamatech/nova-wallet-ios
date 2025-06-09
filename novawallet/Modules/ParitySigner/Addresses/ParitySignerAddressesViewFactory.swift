import Foundation
import SubstrateSdk
import Foundation_iOS

struct ParitySignerAddressesViewFactory {
    static func createOnboardingView(
        with walletFormat: ParitySignerWalletFormat,
        type: ParitySignerType
    ) -> HardwareWalletAddressesViewProtocol? {
        createView(
            with: walletFormat,
            type: type,
            wireframe: ParitySignerAddressesWireframe()
        )
    }

    static func createAddAccountView(
        with walletFormat: ParitySignerWalletFormat,
        type: ParitySignerType
    ) -> HardwareWalletAddressesViewProtocol? {
        createView(
            with: walletFormat,
            type: type,
            wireframe: AddAccount.ParitySignerAddressesWireframe()
        )
    }

    static func createSwitchAccountView(
        with walletFormat: ParitySignerWalletFormat,
        type: ParitySignerType
    ) -> HardwareWalletAddressesViewProtocol? {
        createView(
            with: walletFormat,
            type: type,
            wireframe: SwitchAccount.ParitySignerAddressesWireframe()
        )
    }

    private static func createView(
        with walletFormat: ParitySignerWalletFormat,
        type: ParitySignerType,
        wireframe: ParitySignerAddressesWireframeProtocol
    ) -> HardwareWalletAddressesViewProtocol? {
        let interactor = ParitySignerAddressesInteractor(
            chainRegistry: ChainRegistryFacade.sharedRegistry
        )

        let viewModelFactory = ChainAccountViewModelFactory(iconGenerator: PolkadotIconGenerator())
        let presenter = ParitySignerAddressesPresenter(
            walletFormat: walletFormat,
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
