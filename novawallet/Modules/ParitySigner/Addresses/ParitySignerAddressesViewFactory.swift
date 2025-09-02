import Foundation
import SubstrateSdk
import Foundation_iOS

struct ParitySignerAddressesViewFactory {
    static func createOnboardingView(
        with addressScan: ParitySignerAddressScan,
        type: ParitySignerType
    ) -> HardwareWalletAddressesViewProtocol? {
        createView(
            with: addressScan,
            type: type,
            wireframe: ParitySignerAddressesWireframe()
        )
    }

    static func createAddAccountView(
        with addressScan: ParitySignerAddressScan,
        type: ParitySignerType
    ) -> HardwareWalletAddressesViewProtocol? {
        createView(
            with: addressScan,
            type: type,
            wireframe: AddAccount.ParitySignerAddressesWireframe()
        )
    }

    static func createSwitchAccountView(
        with addressScan: ParitySignerAddressScan,
        type: ParitySignerType
    ) -> HardwareWalletAddressesViewProtocol? {
        createView(
            with: addressScan,
            type: type,
            wireframe: SwitchAccount.ParitySignerAddressesWireframe()
        )
    }

    private static func createView(
        with addressScan: ParitySignerAddressScan,
        type: ParitySignerType,
        wireframe: ParitySignerAddressesWireframeProtocol
    ) -> HardwareWalletAddressesViewProtocol? {
        let interactor = ParitySignerAddressesInteractor(
            addressScan: addressScan,
            chainRegistry: ChainRegistryFacade.sharedRegistry
        )

        let viewModelFactory = ChainAccountViewModelFactory(iconGenerator: PolkadotIconGenerator())
        let presenter = ParitySignerAddressesPresenter(
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
