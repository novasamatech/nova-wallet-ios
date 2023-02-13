import Foundation
import SoraFoundation

struct DelegateVotedReferendaViewFactory {
    static func createView(state: GovernanceSharedState, delegateAddress: AccountAddress) -> DelegateVotedReferendaViewProtocol? {
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
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
        let wireframe = DelegateVotedReferendaWireframe()
        let statusViewModelFactory = ReferendumStatusViewModelFactory()
        let indexFormatter = NumberFormatter.index.localizableResource()
        let referendumStringFactory = ReferendumDisplayStringFactory()
        let referendumViewModelFactory = ReferendumsModelFactory(
            referendumMetadataViewModelFactory: ReferendumMetadataViewModelFactory(indexFormatter: indexFormatter),
            statusViewModelFactory: statusViewModelFactory,
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            stringDisplayViewModelFactory: referendumStringFactory,
            percentFormatter: NumberFormatter.referendumPercent.localizableResource(),
            indexFormatter: indexFormatter,
            quantityFormatter: NumberFormatter.quantity.localizableResource()
        )

        let presenter = DelegateVotedReferendaPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: referendumViewModelFactory,
            statusViewModelFactory: statusViewModelFactory,
            sorting: ReferendumsTimeSortingProvider(),
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = DelegateVotedReferendaViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
