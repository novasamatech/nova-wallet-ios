import Foundation

struct GiftClaimViewFactory {
    static func createView() -> GiftClaimViewProtocol? {
        let interactor = GiftClaimInteractor()
        let wireframe = GiftClaimWireframe()

        let presenter = GiftClaimPresenter(interactor: interactor, wireframe: wireframe)

        let view = GiftClaimViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}