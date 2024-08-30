import Foundation

struct PayCardViewFactory {
    static func createView() -> PayCardViewProtocol? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        let interactor = PayCardInteractor(chainRegistry: chainRegistry)
        let wireframe = PayCardWireframe()

        let presenter = PayCardPresenter(interactor: interactor, wireframe: wireframe)

        let view = PayCardViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
