import Foundation
import SoraFoundation

struct OnboardingWalletReadyViewFactory {
    static func createView(walletName: String) -> OnboardingWalletReadyViewProtocol? {
        let interactor = createInteractor()
        let wireframe = OnboardingWalletReadyWireframe()

        let presenter = OnboardingWalletReadyPresenter(
            interactor: interactor,
            wireframe: wireframe,
            walletName: walletName,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = OnboardingWalletReadyViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    static func createInteractor() -> OnboardingWalletReadyInteractor {
        let factory = ICloudBackupServiceFactory(operationQueue: OperationManagerFacade.sharedDefaultQueue)
        return .init(
            factory: factory,
            serviceFacade: CloudBackupServiceFacade(
                serviceFactory: factory,
                operationQueue: OperationManagerFacade.sharedDefaultQueue
            )
        )
    }
}