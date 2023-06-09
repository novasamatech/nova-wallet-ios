import Foundation
import SubstrateSdk
import SoraFoundation

struct ParitySignerAddressesViewFactory {
    static func createOnboardingView(
        with addressScan: ParitySignerAddressScan,
        type: ParitySignerType
    ) -> ParitySignerAddressesViewProtocol? {
        createView(
            with: addressScan,
            type: type,
            wireframe: ParitySignerAddressesWireframe()
        )
    }

    static func createAddAccountView(
        with addressScan: ParitySignerAddressScan,
        type: ParitySignerType
    ) -> ParitySignerAddressesViewProtocol? {
        createView(
            with: addressScan,
            type: type,
            wireframe: AddAccount.ParitySignerAddressesWireframe()
        )
    }

    static func createSwitchAccountView(
        with addressScan: ParitySignerAddressScan,
        type: ParitySignerType
    ) -> ParitySignerAddressesViewProtocol? {
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
    ) -> ParitySignerAddressesViewProtocol? {
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
            logger: Logger.shared
        )

        let view = ParitySignerAddressesViewController(
            presenter: presenter,
            type: type,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
