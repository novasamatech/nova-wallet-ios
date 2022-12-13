import Foundation

struct TransactionHistoryViewFactory {
    static func createView() -> TransactionHistoryViewProtocol? {
        let interactor = TransactionHistoryInteractor()
        let wireframe = TransactionHistoryWireframe()

        let presenter = TransactionHistoryPresenter(interactor: interactor, wireframe: wireframe)

        let view = TransactionHistoryViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
