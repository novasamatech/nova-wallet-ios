import Foundation
import SoraFoundation

struct TinderGovViewFactory {
    static func createView(
        observableState: Observable<NotEqualWrapper<[ReferendumIdLocal: ReferendumLocal]>>,
        sharedState: GovernanceSharedState
    ) -> TinderGovViewProtocol? {
        guard
            let option = sharedState.settings.value,
            let summaryApi = option.chain.externalApis?.referendumSummary()?.first?.url,
            let connection = sharedState.chainRegistry.getConnection(for: option.chain.chainId),
            let runtimeProvider = sharedState.chainRegistry.getRuntimeProvider(for: option.chain.chainId),
            let assetInfo = option.chain.utilityAsset()?.displayInfo,
            let currencyManager = CurrencyManager.shared
        else {
            return nil
        }

        let wireframe = TinderGovWireframe()
        let interactor = TinderGovInteractor(
            observableState: observableState,
            sorting: ReferendumsTimeSortingProvider(),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let localizationManager = LocalizationManager.shared
        let viewModelFactory = TinderGovViewModelFactory()

        let summaryFetchOperationFactory = OpenGovSummaryOperationFactory(
            url: summaryApi,
            chain: option.chain
        )

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let cardsViewModelFactory = VoteCardViewModelFactory(
            summaryFetchOperationFactory: summaryFetchOperationFactory,
            chain: option.chain,
            currencyManager: currencyManager,
            connection: connection,
            runtimeProvider: runtimeProvider,
            balanceViewModelFactory: balanceViewModelFactory,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            actionDetailsOperationFactory: sharedState.createActionsDetailsFactory(for: option)
        )

        let presenter = TinderGovPresenter(
            wireframe: wireframe,
            interactor: interactor,
            viewModelFactory: viewModelFactory,
            cardsViewModelFactory: cardsViewModelFactory,
            localizationManager: localizationManager
        )

        let view = TinderGovViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
