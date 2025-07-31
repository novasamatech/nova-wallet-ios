import Foundation
import Foundation_iOS
import Operation_iOS

final class MultisigCallDataImportViewFactory {
    static func createView(
        pendingOperation: Multisig.PendingOperation
    ) -> MultisigCallDataImportViewProtocol {
        let localizationManager = LocalizationManager.shared
        let logger = Logger.shared

        let storageFacade = SubstrateDataStorageFacade.shared

        let coreDataRepository: CoreDataRepository<Multisig.PendingOperation, CDMultisigPendingOperation>
        coreDataRepository = storageFacade.createRepository(
            mapper: AnyCoreDataMapper(MultisigPendingOperationMapper())
        )

        let interactor = MultisigCallDataImportInteractor(
            pendingOperation: pendingOperation,
            pendingOperationsRepository: AnyDataProviderRepository(coreDataRepository),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let wireframe = MultisigCallDataImportWireframe()

        let presenter = MultisigCallDataImportPresenter(
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: localizationManager,
            logger: logger
        )

        let view = MultisigCallDataImportViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
