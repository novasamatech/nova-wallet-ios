import Foundation

struct CurrencyViewFactory {
    static func createView() -> CurrencyViewProtocol? {
        let interactor = CurrencyInteractor(
            repository: CurrencyRepository(),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
        let wireframe = CurrencyWireframe()

        let presenter = CurrencyPresenter(interactor: interactor, wireframe: wireframe)

        let view = CurrencyViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
