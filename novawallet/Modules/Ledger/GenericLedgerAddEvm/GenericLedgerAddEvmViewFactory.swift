import Foundation

struct GenericLedgerAddEvmViewFactory {
    static func createView() -> GenericLedgerAccountSelectionViewProtocol? {
        let interactor = GenericLedgerAddEvmInteractor()
        let wireframe = GenericLedgerAddEvmWireframe()

        let presenter = GenericLedgerAddEvmPresenter(interactor: interactor, wireframe: wireframe)

        let view = GenericLedgerAccountSelectionController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
