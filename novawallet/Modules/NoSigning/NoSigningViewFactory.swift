import Foundation
import SoraFoundation

struct NoSigningViewFactory {
    static func createView(with completionCallback: @escaping () -> Void) -> NoSigningViewProtocol? {
        let wireframe = NoSigningWireframe(completionCallback: completionCallback)

        let presenter = NoSigningPresenter(wireframe: wireframe)

        let view = NoSigningViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }
}
