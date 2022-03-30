import Foundation
import SoraFoundation

struct DAppPhishingViewFactory {
    static func createView(with delegate: DAppPhishingViewDelegate) -> DAppPhishingViewProtocol? {
        let wireframe = DAppPhishingWireframe()
        wireframe.delegate = delegate

        let presenter = DAppPhishingPresenter(wireframe: wireframe)

        let view = DAppPhishingViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }
}
