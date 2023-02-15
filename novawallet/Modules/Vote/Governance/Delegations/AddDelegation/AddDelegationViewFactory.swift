import Foundation
import SoraFoundation
import SubstrateSdk
import SoraKeystore

struct AddDelegationViewFactory {
    static func createView(state: GovernanceSharedState) -> AddDelegationViewProtocol? {
        guard let interactor = createInteractor(for: state), let chain = state.settings.value?.chain else {
            return nil
        }

        let localizationManager = LocalizationManager.shared

        let wireframe = AddDelegationWireframe(state: state)

        let viewModelFactory = GovernanceDelegateViewModelFactory(
            votesDisplayFactory: ReferendumDisplayStringFactory(),
            addressViewModelFactory: DisplayAddressViewModelFactory(),
            quantityFormatter: NumberFormatter.quantity.localizableResource(),
            lastVotedDays: GovernanceDelegationConstants.recentVotesInDays
        )

        let presenter = AddDelegationPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chain: chain,
            lastVotedDays: GovernanceDelegationConstants.recentVotesInDays,
            viewModelFactory: viewModelFactory,
            learnDelegateMetadata: ApplicationConfig.shared.learnGovernanceDelegateMetadata,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = AddDelegationViewController(presenter: presenter, localizationManager: localizationManager)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(for state: GovernanceSharedState) -> AddDelegationInteractor? {
        guard let option = state.settings.value else {
            return nil
        }

        let chain = option.chain

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId),
            let blockTimeService = state.blockTimeService,
            let delegateListOperationFactory = state.createOffchainDelegateListFactory(for: option) else {
            return nil
        }

        let blockTimeOperationFactory = BlockTimeOperationFactory(chain: chain)

        return AddDelegationInteractor(
            chain: chain,
            lastVotedDays: GovernanceDelegationConstants.recentVotesInDays,
            fetchBlockTreshold: GovernanceDelegationConstants.delegateFetchBlockThreshold,
            connection: connection,
            runtimeService: runtimeProvider,
            generalLocalSubscriptionFactory: state.generalLocalSubscriptionFactory,
            delegateListOperationFactory: delegateListOperationFactory,
            blockTimeService: blockTimeService,
            blockTimeFactory: blockTimeOperationFactory,
            settings: SettingsManager.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
