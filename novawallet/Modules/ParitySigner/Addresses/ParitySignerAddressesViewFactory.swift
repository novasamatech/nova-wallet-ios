import Foundation
import SubstrateSdk

struct ParitySignerAddressesViewFactory {
    static func createView(with addressScan: ParitySignerAddressScan) -> ParitySignerAddressesViewProtocol? {
        let interactor = ParitySignerAddressesInteractor(
            addressScan: addressScan,
            chainRegistry: ChainRegistryFacade.sharedRegistry
        )

        let wireframe = ParitySignerAddressesWireframe()

        let viewModelFactory = ChainAccountViewModelFactory(iconGenerator: PolkadotIconGenerator())
        let presenter = ParitySignerAddressesPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            logger: Logger.shared
        )

        let view = ParitySignerAddressesViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
