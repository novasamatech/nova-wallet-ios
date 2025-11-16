import Foundation

struct GiftHistoryCheckViewFactory {
    static func createView() -> GiftHistoryCheckViewProtocol? {
        let interactor = GiftHistoryCheckInteractor()
        let wireframe = GiftHistoryCheckWireframe()

        let presenter = GiftHistoryCheckPresenter(interactor: interactor, wireframe: wireframe)

        let view = GiftHistoryCheckViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}