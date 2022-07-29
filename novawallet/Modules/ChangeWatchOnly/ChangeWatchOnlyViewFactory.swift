import Foundation

struct ChangeWatchOnlyViewFactory {
    static func createView() -> ChangeWatchOnlyViewProtocol? {
        let interactor = ChangeWatchOnlyInteractor()
        let wireframe = ChangeWatchOnlyWireframe()

        let presenter = ChangeWatchOnlyPresenter(interactor: interactor, wireframe: wireframe)

        let view = ChangeWatchOnlyViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}