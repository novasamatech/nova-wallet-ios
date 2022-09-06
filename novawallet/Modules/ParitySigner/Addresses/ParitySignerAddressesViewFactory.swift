import Foundation
import SubstrateSdk
import SoraFoundation

struct ParitySignerAddressesViewFactory {
    static func createOnboardingView(with addressScan: ParitySignerAddressScan) -> ParitySignerAddressesViewProtocol? {
        createView(with: addressScan, wireframe: ParitySignerAddressesWireframe())
    }

    static func createAddAccountView(with addressScan: ParitySignerAddressScan) -> ParitySignerAddressesViewProtocol? {
        createView(with: addressScan, wireframe: AddAccount.ParitySignerAddressesWireframe())
    }

    static func createSwitchAccountView(
        with addressScan: ParitySignerAddressScan
    ) -> ParitySignerAddressesViewProtocol? {
        createView(with: addressScan, wireframe: SwitchAccount.ParitySignerAddressesWireframe())
    }

    private static func createView(
        with addressScan: ParitySignerAddressScan,
        wireframe: ParitySignerAddressesWireframeProtocol
    ) -> ParitySignerAddressesViewProtocol? {
        let interactor = ParitySignerAddressesInteractor(
            addressScan: addressScan,
            chainRegistry: ChainRegistryFacade.sharedRegistry
        )

        let viewModelFactory = ChainAccountViewModelFactory(iconGenerator: PolkadotIconGenerator())
        let presenter = ParitySignerAddressesPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            logger: Logger.shared
        )

        let view = ParitySignerAddressesViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
