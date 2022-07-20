import Foundation
import SoraFoundation

struct CreateWatchOnlyViewFactory {
    static func createView() -> CreateWatchOnlyViewProtocol? {
        guard let interactor = createInteractor() else {
            return nil
        }

        let wireframe = CreateWatchOnlyWireframe()

        let localizationManager = LocalizationManager.shared

        let presenter = CreateWatchOnlyPresenter(interactor: interactor, wireframe: wireframe)

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
            repository: WatchOnlyPresetRepository(),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
