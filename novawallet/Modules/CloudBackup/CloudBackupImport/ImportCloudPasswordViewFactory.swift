import Foundation

struct ImportCloudPasswordViewFactory {
    static func createView() -> ImportCloudPasswordViewProtocol? {
        let interactor = ImportCloudPasswordInteractor()
        let wireframe = ImportCloudPasswordWireframe()

        let presenter = ImportCloudPasswordPresenter(interactor: interactor, wireframe: wireframe)

        let view = ImportCloudPasswordViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
