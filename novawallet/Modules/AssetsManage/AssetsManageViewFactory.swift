import Foundation

struct AssetsManageViewFactory {
    static func createView() -> AssetsManageViewProtocol? {
        let interactor = AssetsManageInteractor()
        let wireframe = AssetsManageWireframe()

        let presenter = AssetsManagePresenter(interactor: interactor, wireframe: wireframe)

        let view = AssetsManageViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}