import Foundation
import SoraFoundation

struct StakingMoreOptionsViewFactory {
    static func createView(stateObserver: Observable<StakingDashboardModel>) -> StakingMoreOptionsViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }
        let dAppsUrl = ApplicationConfig.shared.dAppsListURL
        let dAppProvider: AnySingleValueProvider<DAppList> = JsonDataProviderFactory.shared.getJson(
            for: dAppsUrl
        )
        let interactor = StakingMoreOptionsInteractor(
            dAppProvider: dAppProvider,
            stakingStateObserver: stateObserver,
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )
        let wireframe = StakingMoreOptionsWireframe()
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)

        let viewModelFactory = StakingDashboardViewModelFactory(
            assetFormatterFactory: AssetBalanceFormatterFactory(),
            priceAssetInfoFactory: priceAssetInfoFactory,
            networkViewModelFactory: NetworkViewModelFactory(),
            estimatedEarningsFormatter: NumberFormatter.percentBase.localizableResource()
        )

        let presenter = StakingMoreOptionsPresenter(
            interactor: interactor,
            viewModelFactory: viewModelFactory,
            wireframe: wireframe
        )

        let view = StakingMoreOptionsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
