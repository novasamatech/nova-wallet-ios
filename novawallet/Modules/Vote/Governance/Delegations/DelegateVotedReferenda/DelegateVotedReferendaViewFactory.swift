import Foundation
import SoraFoundation

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
            option: .recent(
                days: GovernanceDelegationConstants.recentVotesInDays,
                fetchBlockTreshold: GovernanceDelegationConstants.delegateFetchBlockThreshold
            )
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
              let delegationApi = chain.externalApis?.governanceDelegations()?.first else {
            return nil
        }

        let chainRegisty = ChainRegistryFacade.sharedRegistry
        let serviceFactory = GovernanceServiceFactory(
            chainRegisty: chainRegisty,
            storageFacade: SubstrateDataStorageFacade.shared,
            eventCenter: EventCenter.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )

        let interactor = DelegateVotedReferendaInteractor(
            governanceState: state,
            chainRegistry: chainRegisty,
            serviceFactory: serviceFactory,
            address: delegateAddress,
            governanceOffchainVotingFactory: SubqueryVotingOperationFactory(url: delegationApi.url),
            delegateVotedReferenda: option,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
        let wireframe = DelegateVotedReferendaWireframe()
        let statusViewModelFactory = ReferendumStatusViewModelFactory()
        let indexFormatter = NumberFormatter.index.localizableResource()
        let referendumStringFactory = ReferendumDisplayStringFactory()
        let quantityFormatter = NumberFormatter.quantity.localizableResource()

        let referendumViewModelFactory = ReferendumsModelFactory(
            referendumMetadataViewModelFactory: ReferendumMetadataViewModelFactory(indexFormatter: indexFormatter),
            statusViewModelFactory: statusViewModelFactory,
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            stringDisplayViewModelFactory: referendumStringFactory,
            percentFormatter: NumberFormatter.referendumPercent.localizableResource(),
            indexFormatter: indexFormatter,
            quantityFormatter: quantityFormatter
        )

        let presenter = DelegateVotedReferendaPresenter(
            interactor: interactor,
            wireframe: wireframe,
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
}
