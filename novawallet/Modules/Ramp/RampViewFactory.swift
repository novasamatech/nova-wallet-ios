import Foundation
import SoraFoundation

final class RampViewFactory: RampViewFactoryProtocol {
    static func createView(
        for action: RampAction,
        delegate: RampDelegate?
    ) -> RampViewProtocol? {
        let view = RampViewController(url: action.url)

        let presenter = RampPresenter()

        let interactor = RampInteractor(
            eventCenter: EventCenter.shared,
            action: action
        )

        let wireframe = RampWireframe(delegate: delegate)

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
