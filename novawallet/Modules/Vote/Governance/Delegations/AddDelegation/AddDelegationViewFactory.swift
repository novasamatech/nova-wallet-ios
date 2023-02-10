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

        let presenter = AddDelegationPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chain: chain,
            lastVotedDays: GovernanceDelegationConstants.recentVotesInDays,
            learnDelegateMetadata: ApplicationConfig.shared.learnGovernanceDelegateMetadata,
            addressViewModelFactory: DisplayAddressViewModelFactory(),
            votesDisplayFactory: ReferendumDisplayStringFactory(),
            quantityFormatter: NumberFormatter.quantity.localizableResource(),
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = AddDelegationViewController(presenter: presenter, localizationManager: localizationManager)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(for state: GovernanceSharedState) -> AddDelegationInteractor? {
        guard
            let option = state.settings.value,
            let statsUrl = option.chain.externalApis?.governanceDelegations()?.first?.url
        else {
            return nil
        }

        let chain = option.chain

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId),
            let blockTimeService = state.blockTimeService else {
            return nil
        }

        guard let delegateListOperationFactory = state.createOffchainDelegateListFactory(for: option)

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
