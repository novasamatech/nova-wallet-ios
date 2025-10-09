import Foundation
import Foundation_iOS

struct StakingMoreOptionsViewFactory {
    static func createView(
        stateObserver: Observable<StakingDashboardModel>
    ) -> StakingMoreOptionsViewProtocol? {
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
            operationQueue: OperationQueue()
        )
        let wireframe = StakingMoreOptionsWireframe()
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)

        let viewModelFactory = StakingDashboardViewModelFactory(
            assetFormatterFactory: AssetBalanceFormatterFactory(),
            priceAssetInfoFactory: priceAssetInfoFactory,
            chainAssetViewModelFactory: ChainAssetViewModelFactory(),
            estimatedEarningsFormatter: NumberFormatter.percentBase.localizableResource()
        )

        let wallet: MetaAccountModel = SelectedWalletSettings.shared.value

        let presenter = StakingMoreOptionsPresenter(
            interactor: interactor,
            viewModelFactory: viewModelFactory,
            wireframe: wireframe,
            metaId: wallet.metaId,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
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
