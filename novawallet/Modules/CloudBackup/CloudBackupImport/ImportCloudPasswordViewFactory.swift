import Foundation
import SoraFoundation
import SoraKeystore

struct ImportCloudPasswordViewFactory {
    static func createView() -> ImportCloudPasswordViewProtocol? {
        let interactor = createInteractor()
        let wireframe = ImportCloudPasswordWireframe()

        let presenter = ImportCloudPasswordPresenter(
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: LocalizationManager.shared
        )

        let view = ImportCloudPasswordViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    static func createInteractor() -> ImportCloudPasswordInteractor {
        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let serviceFactory = ICloudBackupServiceFactory(operationQueue: operationQueue)
        let serviceFacade = CloudBackupServiceFacade(
            serviceFactory: serviceFactory,
            operationQueue: operationQueue
        )

        let walletRepository = AccountRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        ).createMetaAccountRepository(
            for: nil,
            sortDescriptors: []
        )

        let keystore = Keychain()

        return .init(
            cloudBackupFacade: serviceFacade,
            walletRepository: walletRepository,
            keystore: keystore
        )
    }
}
