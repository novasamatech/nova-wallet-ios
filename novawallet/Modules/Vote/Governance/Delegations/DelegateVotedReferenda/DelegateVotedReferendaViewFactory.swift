import Foundation
import Foundation_iOS

struct DelegateVotedReferendaViewFactory {
    static func createRecentVotesView(
        state: GovernanceSharedState,
        delegateAddress: AccountAddress,
        delegateName: String?
    ) -> DelegateVotedReferendaViewProtocol? {
        createView(
            state: state,
            delegateAddress: delegateAddress,
            delegateName: delegateName,
            option: .recent(days: GovernanceDelegationConstants.recentVotesInDays)
        )
    }

    static func createAllVotesView(
        state: GovernanceSharedState,
        delegateAddress: AccountAddress,
        delegateName: String?
    ) -> DelegateVotedReferendaViewProtocol? {
        createView(
            state: state,
            delegateAddress: delegateAddress,
            delegateName: delegateName,
            option: .allTimes
        )
    }

    private static func createView(
        state: GovernanceSharedState,
        delegateAddress: AccountAddress,
        delegateName: String?,
        option: DelegateVotedReferendaOption
    ) -> DelegateVotedReferendaViewProtocol? {
        guard let chain = state.settings.value?.chain,
              let interactor = createInteractor(
                  from: state,
                  delegateAddress: delegateAddress,
                  dataFetchOption: option
              ) else {
            return nil
        }

        let wireframe = DelegateVotedReferendaWireframe(state: state)
        let statusViewModelFactory = ReferendumStatusViewModelFactory()
        let indexFormatter = NumberFormatter.index.localizableResource()
        let referendumDisplayStringFactory = ReferendumDisplayStringFactory()
        let quantityFormatter = NumberFormatter.quantity.localizableResource()

        let referendumViewModelFactory = ReferendumsModelFactory(
            referendumMetadataViewModelFactory: ReferendumMetadataViewModelFactory(indexFormatter: indexFormatter),
            statusViewModelFactory: statusViewModelFactory,
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            stringDisplayViewModelFactory: referendumDisplayStringFactory,
            percentFormatter: NumberFormatter.referendumPercent.localizableResource(),
            indexFormatter: indexFormatter,
            quantityFormatter: quantityFormatter
        )

        let presenter = DelegateVotedReferendaPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chain: chain,
            viewModelFactory: referendumViewModelFactory,
            statusViewModelFactory: statusViewModelFactory,
            sorting: ReferendumsTimeSortingProvider(),
            name: delegateName ?? delegateAddress,
            localizationManager: LocalizationManager.shared,
            option: option,
            logger: Logger.shared
        )

        let view = DelegateVotedReferendaViewController(
            presenter: presenter,
            quantityFormatter: quantityFormatter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        from state: GovernanceSharedState,
        delegateAddress: AccountAddress,
        dataFetchOption: DelegateVotedReferendaOption
    ) -> DelegateVotedReferendaInteractor? {
        guard
            let option = state.settings.value,
            let referendumOperationFactory = state.referendumsOperationFactory,
            let timelineService = state.createChainTimelineFacade(),
            let apiUrl = option.chain.externalApis?.governanceDelegations()?.first?.url else {
            return nil
        }

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: option.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: option.chain.chainId) else {
            return nil
        }

        let offchainOperationFactory = SubqueryVotingOperationFactory(url: apiUrl)

        let fetchFactory = DelegateVotedReferendaOperationFactory(
            chain: option.chain,
            referendumOperationFactory: referendumOperationFactory,
            offchainOperationFactory: offchainOperationFactory,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        return .init(
            address: delegateAddress,
            governanceOption: option,
            connection: connection,
            runtimeService: runtimeService,
            generalLocalSubscriptionFactory: state.generalLocalSubscriptionFactory,
            govMetadataLocalSubscriptionFactory: state.govMetadataLocalSubscriptionFactory,
            fetchFactory: fetchFactory,
            timelineService: timelineService,
            dataFetchOption: dataFetchOption,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
