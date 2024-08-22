import Foundation

struct PayCardViewFactory {
    static func createView() -> PayCardViewProtocol? {
        let interactor = PayCardInteractor()
        let wireframe = PayCardWireframe()

        let presenter = PayCardPresenter(interactor: interactor, wireframe: wireframe)

        let view = PayCardViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
