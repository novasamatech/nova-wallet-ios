import Foundation
import Foundation_iOS

final class MultisigNotificationsViewFactory {
    static func createView(
        with settings: MultisigNotificationsModel,
        selectedMetaIds: Set<MetaAccountModel.Id>,
        completion: @escaping (MultisigNotificationsModel) -> Void
    ) -> ControllerBackedProtocol? {
        let wireframe = MultisigNotificationsWireframe(
            applicationConfig: ApplicationConfig.shared,
            completion: completion
        )

        let walletRepository = AccountRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        ).createMetaAccountRepository(for: .metaAccountsByType(.multisig), sortDescriptors: [])

        let interactor = MultisigNotificationsInteractor(
            walletRepository: walletRepository,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )

        let presenter = MultisigNotificationsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            settings: settings,
            selectedMetaIds: selectedMetaIds,
            localizationManager: LocalizationManager.shared
        )

        let view = MultisigNotificationsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        interactor.presenter = presenter
        presenter.view = view

        return view
    }
}
