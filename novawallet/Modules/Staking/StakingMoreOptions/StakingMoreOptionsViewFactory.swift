import Foundation

struct StakingMoreOptionsViewFactory {
    static func createView() -> StakingMoreOptionsViewProtocol? {
        let dAppsUrl = ApplicationConfig.shared.dAppsListURL
        let dAppProvider: AnySingleValueProvider<DAppList> = JsonDataProviderFactory.shared.getJson(
            for: dAppsUrl
        )
        let interactor = StakingMoreOptionsInteractor(
            dAppProvider: dAppProvider,
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )
        let wireframe = StakingMoreOptionsWireframe()

        let presenter = StakingMoreOptionsPresenter(interactor: interactor, wireframe: wireframe)

        let view = StakingMoreOptionsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
