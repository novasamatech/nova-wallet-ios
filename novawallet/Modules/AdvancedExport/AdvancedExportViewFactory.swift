import Foundation

struct AdvancedExportViewFactory {
    static func createView() -> AdvancedExportViewProtocol? {
        let interactor = AdvancedExportInteractor()
        let wireframe = AdvancedExportWireframe()

        let presenter = AdvancedExportPresenter(interactor: interactor, wireframe: wireframe)

        let view = AdvancedExportViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}