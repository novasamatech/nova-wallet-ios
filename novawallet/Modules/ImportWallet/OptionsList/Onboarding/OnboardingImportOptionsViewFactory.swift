import Foundation
import SoraFoundation

struct OnboardingImportOptionsViewFactory {
    static func createView() -> WalletImportOptionsViewProtocol? {
        let interactor = createInteractor()
        let wireframe = OnboardingImportOptionsWireframe()

        let presenter = OnboardingImportOptionsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = WalletImportOptionsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    static func createInteractor() -> OnboardingImportOptionsInteractor {
        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let serviceFacade = CloudBackupServiceFacade(
            serviceFactory: ICloudBackupServiceFactory(operationQueue: operationQueue),
            operationQueue: operationQueue
        )

        return .init(cloudBackupServiceFacade: serviceFacade)
    }
}
