import UIKit
import SubstrateSdk

struct ProxySignValidationViewFactory {
    static func createView(
        from view: ControllerBackedProtocol,
        resolvedProxy: ExtrinsicSenderResolution.ResolvedProxy,
        calls: [JSON]
    ) -> ProxySignValidationPresenterProtocol? {
        let interactor = ProxySignValidationInteractor()
        let wireframe = ProxySignValidationWireframe()

        let presenter = ProxySignValidationPresenter(
            view: view,
            interactor: interactor,
            wireframe: wireframe
        )

        interactor.presenter = presenter

        return presenter
    }
}
