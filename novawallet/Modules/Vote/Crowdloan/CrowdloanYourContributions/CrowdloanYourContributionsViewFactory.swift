import Foundation
import Foundation_iOS
import Keystore_iOS
import Operation_iOS

struct CrowdloanYourContributionsViewInput {
    let contributions: [CrowdloanContribution]
    let displayInfo: CrowdloanDisplayInfoDict?
    let chainAsset: ChainAssetDisplayInfo
}

enum CrowdloanYourContributionsViewFactory {
    static func createView(
        input: CrowdloanYourContributionsViewInput,
        sharedState: CrowdloanSharedState
    ) -> CrowdloanYourContributionsViewProtocol? {
        guard
            let chain = sharedState.settings.value,
            let selectedMetaAccount = SelectedWalletSettings.shared.value,
            let currencyManager = CurrencyManager.shared
        else { return nil }

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return nil
        }

        let interactor = CrowdloanYourContributionsInteractor(
            chain: chain,
            selectedMetaAccount: selectedMetaAccount,
            crowdloanState: sharedState,
            runtimeService: runtimeService,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            currencyManager: currencyManager,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
        )

        let wireframe = CrowdloanYourContributionsWireframe()
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactoryFacade = BalanceViewModelFactoryFacade(priceAssetInfoFactory: priceAssetInfoFactory)
        let viewModelFactory = CrowdloanYourContributionsVMFactory(
            chainDateCalculator: ChainDateCalculator(),
            calendar: Calendar.current,
            balanceViewModelFactoryFacade: balanceViewModelFactoryFacade
        )

        let presenter = CrowdloanYourContributionsPresenter(
            input: input,
            viewModelFactory: viewModelFactory,
            interactor: interactor,
            wireframe: wireframe,
            timeFormatter: TotalTimeFormatter(),
            localizationManager: LocalizationManager.shared,
            crowdloansCalculator: CrowdloansCalculator(),
            logger: Logger.shared
        )

        let view = CrowdloanYourContributionsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
