import Foundation
import Foundation_iOS

struct CreateWatchOnlyViewFactory {
    static func createViewForOnboarding() -> CreateWatchOnlyViewProtocol? {
        let wireframe = CreateWatchOnlyWireframe()
        return createView(with: wireframe)
    }

    static func createViewForAdding() -> CreateWatchOnlyViewProtocol? {
        let wireframe = AddAccount.CreateWatchOnlyWireframe()
        return createView(with: wireframe)
    }

    static func createViewForSwitch() -> CreateWatchOnlyViewProtocol? {
        let wireframe = SwitchAccount.CreateWatchOnlyWireframe()
        return createView(with: wireframe)
    }

    private static func createView(with wireframe: CreateWatchOnlyWireframeProtocol) -> CreateWatchOnlyViewProtocol? {
        guard let interactor = createInteractor() else {
            return nil
        }

        let localizationManager = LocalizationManager.shared

        let presenter = CreateWatchOnlyPresenter(
            interactor: interactor,
            wireframe: wireframe,
            logger: Logger.shared
        )

        let view = CreateWatchOnlyViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor() -> CreateWatchOnlyInteractor? {
        CreateWatchOnlyInteractor(
            settings: SelectedWalletSettings.shared,
            walletOperationFactory: WatchOnlyWalletOperationFactory(),
            repository: WatchOnlyPresetRepository(),
            eventCenter: EventCenter.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
