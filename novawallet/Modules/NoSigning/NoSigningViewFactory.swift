import Foundation

struct NoSigningViewFactory {
    static func createView() -> NoSigningViewProtocol? {
        let wireframe = NoSigningWireframe()

        let presenter = NoSigningPresenter(wireframe: wireframe)

        let view = NoSigningViewController(presenter: presenter)

        presenter.view = view

        return view
    }
}
