import UIKit

final class ProxySignConfirmationViewFactory {
    static func createPresenter(
        from proxiedId: MetaAccountModel.Id,
        proxyName: String,
        completionClosure: @escaping ProxySignConfirmationCompletion,
        viewController: UIViewController
    ) -> ProxySignConfirmationPresenterProtocol {
        let repository = AccountRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        ).createProxiedSettingsRepository()

        let interactor = ProxySignConfirmationInteractor(
            proxiedId: proxiedId,
            repository: repository,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )

        let wireframe = ProxySignConfirmationWireframe(
            proxiedId: proxiedId,
            proxyName: proxyName
        )

        let view = ControllerBacked(controller: viewController)

        let presenter = ProxySignConfirmationPresenter(
            view: view,
            interactor: interactor,
            wireframe: wireframe,
            completionClosure: completionClosure
        )

        interactor.presenter = presenter

        return presenter
    }
}
