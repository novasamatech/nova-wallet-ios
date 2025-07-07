import Foundation
import SubstrateSdk

struct DelegatedSignValidationViewFactory {
    static func createView(
        from view: ControllerBackedProtocol,
        resolution: ExtrinsicSenderResolution.ResolvedDelegate,
        call: JSON,
        completionClosure: @escaping DelegatedSignValidationCompletion
    ) -> DelegatedSignValidationPresenterProtocol? {
        let wireframe = DelegatedSignValidationWireframe(
            completionClosure: completionClosure
        )

        let interactor = DelegatedSignValidationInteractor(
            call: call,
            resolution: resolution,
            validationSequenceFactory: DSValidationSequenceFactory(
                chainRegistry: ChainRegistryFacade.sharedRegistry
            ),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let presenter = DelegatedSignValidationPresenter(
            view: view,
            interactor: interactor,
            wireframe: wireframe,
            logger: Logger.shared
        )

        interactor.presenter = presenter

        return presenter
    }
}
