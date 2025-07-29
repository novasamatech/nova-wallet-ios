import UIKit

final class DelegatedSignConfirmationViewFactory {
    static func createPresenter(
        from delegatedAccountId: MetaAccountModel.Id,
        delegationClass: DelegationClass,
        delegateAccountResponse: ChainAccountResponse,
        completionClosure: @escaping DelegatedSignConfirmationCompletion,
        viewController: UIViewController
    ) -> DelegatedSignConfirmationPresenterProtocol {
        let repository = AccountRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        ).createDelegatedAccountSettingsRepository()

        let interactor = DelegatedSignConfirmationInteractor(
            delegatedAccountId: delegatedAccountId,
            repository: repository,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )

        let wireframe = DelegatedSignConfirmationWireframe(
            delegatedAccountId: delegatedAccountId,
            delegateAccountResponse: delegateAccountResponse,
            delegationClass: delegationClass
        )

        let view = ControllerBacked(controller: viewController)

        let presenter = DelegatedSignConfirmationPresenter(
            view: view,
            interactor: interactor,
            wireframe: wireframe,
            completionClosure: completionClosure
        )

        interactor.presenter = presenter

        return presenter
    }
}
