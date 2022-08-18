import Foundation

struct LedgerDiscoverViewFactory {
    static func createView() -> LedgerDiscoverViewProtocol? {
        let ledgerConnection = LedgerConnectionManager(logger: Logger.shared)

        let interactor = LedgerDiscoverInteractor(ledgerConnection: ledgerConnection)
        let wireframe = LedgerDiscoverWireframe()

        let presenter = LedgerDiscoverPresenter(interactor: interactor, wireframe: wireframe)

        let view = LedgerDiscoverViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
