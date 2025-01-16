import Foundation
import Foundation_iOS

struct WalletImportOptionsViewFactory {
    static func createViewForOnboarding() -> WalletImportOptionsViewProtocol? {
        let interactor = createInteractor()
        let wireframe = OnboardingImportOptionsWireframe(
            chainRegistry: ChainRegistryFacade.sharedRegistry
        )

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

    static func createViewForAdding() -> WalletImportOptionsViewProtocol? {
        createNoCloudBackupOptionView(
            for: AddAccount.ImportOptionsWireframe(
                chainRegistry: ChainRegistryFacade.sharedRegistry
            )
        )
    }

    static func createViewForSwitch() -> WalletImportOptionsViewProtocol? {
        createNoCloudBackupOptionView(
            for: SwitchAccount.ImportOptionsWireframe(
                chainRegistry: ChainRegistryFacade.sharedRegistry
            )
        )
    }

    private static func createNoCloudBackupOptionView(
        for wireframe: WalletImportOptionsWireframeProtocol
    ) -> WalletImportOptionsViewProtocol? {
        let presenter = AddAccount.ImportOptionsPresenter(
            wireframe: wireframe,
            localizationManager: LocalizationManager.shared
        )

        let view = WalletImportOptionsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }

    private static func createInteractor() -> OnboardingImportOptionsInteractor {
        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let serviceFacade = CloudBackupServiceFacade(
            serviceFactory: ICloudBackupServiceFactory(),
            operationQueue: operationQueue
        )

        return .init(cloudBackupServiceFacade: serviceFacade)
    }
}
