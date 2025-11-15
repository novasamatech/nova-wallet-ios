import Foundation
import Foundation_iOS
import Keystore_iOS
import Operation_iOS

struct CrowdloanYourContributionsViewInput {
    let contributions: [CrowdloanContribution]
    let displayInfo: CrowdloanDisplayInfoDict?
    let chainAsset: ChainAssetDisplayInfo

    func replacing(newContributions: [CrowdloanContribution]) -> Self {
        .init(
            contributions: newContributions,
            displayInfo: displayInfo,
            chainAsset: chainAsset
        )
    }
}

enum CrowdloanYourContributionsViewFactory {
    static func createView(
        input: CrowdloanYourContributionsViewInput,
        sharedState: CrowdloanSharedState
    ) -> CrowdloanContributionsViewProtocol? {
        guard
            let chain = sharedState.settings.value,
            let selectedMetaAccount = SelectedWalletSettings.shared.value,
            let currencyManager = CurrencyManager.shared
        else { return nil }

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        let interactor = CrowdloanYourContributionsInteractor(
            chain: chain,
            selectedMetaAccount: selectedMetaAccount,
            crowdloanState: sharedState,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            currencyManager: currencyManager,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
        )

        let wireframe = CrowdloanYourContributionsWireframe()
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactoryFacade = BalanceViewModelFactoryFacade(priceAssetInfoFactory: priceAssetInfoFactory)
        let viewModelFactory = CrowdloanYourContributionsVMFactory(
            balanceViewModelFactoryFacade: balanceViewModelFactoryFacade
        )

        let presenter = CrowdloanYourContributionsPresenter(
            input: input,
            viewModelFactory: viewModelFactory,
            interactor: interactor,
            wireframe: wireframe,
            timeFormatter: TotalTimeFormatter(),
            localizationManager: LocalizationManager.shared,
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
